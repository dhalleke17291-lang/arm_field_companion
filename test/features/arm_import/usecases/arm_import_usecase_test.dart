import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_assessment_definition_resolver.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_report_builder.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_snapshot_service.dart';
import 'package:arm_field_companion/features/arm_import/data/compatibility_profile_builder.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/assessment_token.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/resolved_arm_assessment_definitions.dart';
import 'package:arm_field_companion/features/arm_import/domain/results/arm_import_result.dart';
import 'package:arm_field_companion/features/arm_import/usecases/arm_import_usecase.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ArmImportUseCase _makeUseCase(
  AppDatabase db, {
  ArmImportPersistenceRepository? persistence,
}) {
  return ArmImportUseCase(
    db,
    TrialRepository(db),
    TreatmentRepository(db),
    PlotRepository(db),
    AssignmentRepository(db),
    ArmAssessmentDefinitionResolver(AssessmentDefinitionRepository(db)),
    TrialAssessmentRepository(db),
    SessionRepository(db),
    SaveRatingUseCase(RatingRepository(db)),
    ArmCsvParser(),
    ArmImportSnapshotService(),
    CompatibilityProfileBuilder(),
    persistence ?? ArmImportPersistenceRepository(db),
    ArmImportReportBuilder(),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('empty CSV fails', () async {
    final uc = _makeUseCase(db);
    final r = await uc.execute('', sourceFileName: 'empty.csv');
    expect(r.success, false);
    expect(r.errorMessage, 'Import file is empty or invalid.');
  });

  test('header only CSV succeeds for skeleton', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'header_only_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    expect(r.trialId, isNotNull);
    final tid = r.trialId!;

    final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
        .getSingle();
    expect(trial.isArmLinked, true);

    final snaps = await (db.select(db.importSnapshots)
          ..where((s) => s.trialId.equals(tid)))
        .get();
    expect(snaps, hasLength(1));

    final profiles = await (db.select(db.compatibilityProfiles)
          ..where((c) => c.trialId.equals(tid)))
        .get();
    expect(profiles, hasLength(1));
  });

  test('normal minimal CSV succeeds', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'minimal_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final table = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    final headers = table.first.map((c) => c.toString()).toList();
    final dataRows = table.skip(1).toList();
    final parsed = ArmCsvParser().parse(
      headers: headers,
      rows: dataRows,
      sourceFileName: fileName,
    );
    final expectedReport = ArmImportReportBuilder().build(parsed);

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    expect(r.trialId, isNotNull);
    expect(r.confidence, parsed.importConfidence);
    expect(r.warnings.length, greaterThanOrEqualTo(expectedReport.warnings.length));
    for (var i = 0; i < expectedReport.warnings.length; i++) {
      expect(r.warnings[i], expectedReport.warnings[i]);
    }
    expect(r.unknownPatterns.length,
        greaterThanOrEqualTo(parsed.unknownPatterns.length));
    for (var i = 0; i < parsed.unknownPatterns.length; i++) {
      expect(r.unknownPatterns[i], parsed.unknownPatterns[i]);
    }

    final tid = r.trialId!;
    final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
        .getSingle();
    expect(trial.isArmLinked, true);

    final snaps = await (db.select(db.importSnapshots)
          ..where((s) => s.trialId.equals(tid)))
        .get();
    expect(snaps, hasLength(1));
    final profiles = await (db.select(db.compatibilityProfiles)
          ..where((c) => c.trialId.equals(tid)))
        .get();
    expect(profiles, hasLength(1));

    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(tas, isNotEmpty);
    for (final ta in tas) {
      expect(ta.legacyAssessmentId, isNotNull,
          reason: 'legacy id should be stored on TrialAssessment after import');
    }
  });

  test('ERA column sets trial location', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'era_loc_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,ERA,AVEFA 1-Jul-26 CONTRO %\n101,1,1,Elm Creek,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
        .getSingle();
    expect(trial.location, 'Elm Creek');
  });

  test('minimal treatment insertion', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'minimal_trt_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trts = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(trts, hasLength(1));
    expect(trts.single.code, '1');
    expect(trts.single.name, 'Treatment 1');
  });

  test('multiple treatments deduplicated', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'dedup_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n102,2,1\n103,1,2\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trts = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
    expect(trts, hasLength(2));
    expect(trts.map((t) => t.code).toList(), ['1', '2']);
  });

  test('treatment name used when present', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'names_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,Treatment Name\n101,1,1,Check\n102,2,1,Product X\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trts = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
    expect(trts, hasLength(2));
    expect(trts.firstWhere((t) => t.code == '1').name, 'Check');
    expect(trts.firstWhere((t) => t.code == '2').name, 'Product X');
  });

  test('optional treatment type persists when present', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'ttype_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps, Type\n101,1,1,Herbicide\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trt = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid)))
        .getSingle();
    expect(trt.treatmentType, 'Herbicide');
  });

  test('no component rows inserted when rate headers present', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'no_comp_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,Treatment Name, Rate,Rate Unit,Appl Code\n101,1,1,Check,1.0,L/ha,A\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final trts = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(trts, hasLength(1));
    expect(trts.single.name, 'Check');

    final comps = await (db.select(db.treatmentComponents)
          ..where((c) => c.trialId.equals(tid)))
        .get();
    expect(comps, isEmpty);
  });

  test('plots inserted with correct plotId and rep', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'plots_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n102,2,1\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    expect(plots, hasLength(2));
    expect(plots.map((p) => p.plotId).toList(), ['101', '102']);
    expect(plots.map((p) => p.rep).toList(), [1, 1]);
  });

  test('sixteen plots with CRLF line endings all inserted', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'sixteen_crlf_$unique.csv';
    final uc = _makeUseCase(db);
    final buf = StringBuffer()..write('Plot No.,trt,reps');
    for (var i = 0; i < 16; i++) {
      buf.write('\r\n${101 + i},1,1');
    }
    final r = await uc.execute(buf.toString(), sourceFileName: fileName);
    expect(r.success, true);
    final tid = r.trialId!;
    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
        .get();
    expect(plots.length, 16);
  });

  test('plot 104 with unquoted decimal assessment cell inserts plot', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'decimal_rate_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Trial ID,trt,reps,Plot No.,AVEFA 1-Jul-26 CONTRO %\n'
        'AgQuest,4,1,104,.5\n';
    final r = await uc.execute(content, sourceFileName: fileName);
    expect(r.success, true);
    final tid = r.trialId!;
    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
        .get();
    expect(plots.single.plotId, '104');
  });

  test('assignments map plot PK to treatment id', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'assign_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n102,2,1\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    final t1 = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid) & t.code.equals('1')))
        .getSingle();
    final t2 = await (db.select(db.treatments)
          ..where((t) => t.trialId.equals(tid) & t.code.equals('2')))
        .getSingle();

    final assigns =
        await (db.select(db.assignments)..where((a) => a.trialId.equals(tid)))
            .get();
    expect(assigns, hasLength(2));
    expect(
      assigns.firstWhere((a) => a.plotId == plots[0].id).treatmentId,
      t1.id,
    );
    expect(
      assigns.firstWhere((a) => a.plotId == plots[1].id).treatmentId,
      t2.id,
    );
  });

  test('assignment skipped when trt empty (no treatment id mapping)', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'skip_trt_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n102,,1\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final assigns =
        await (db.select(db.assignments)..where((a) => a.trialId.equals(tid)))
            .get();
    expect(assigns, hasLength(1));
  });

  test('duplicate plot business ids both inserted with two assignments', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'dup_plot_$unique.csv';
    final uc = _makeUseCase(db);
    const content = 'Plot No.,trt,reps\n101,1,1\n101,1,1\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    expect(plots, hasLength(2));
    expect(plots.every((p) => p.plotId == '101'), isTrue);

    final assigns =
        await (db.select(db.assignments)..where((a) => a.trialId.equals(tid)))
            .get();
    expect(assigns, hasLength(2));
  });

  test('assessment columns create trial assessments', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'ta_one_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(tas, hasLength(1));
    expect(tas.single.selectedFromProtocol, true);
    expect(tas.single.selectedManually, false);
  });

  test('multiple assessment columns preserve sort order', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'ta_order_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %,AVEFA 7-Jul-26 PHYGEN %\n101,1,1,5,9\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(tas, hasLength(2));
    expect(tas[0].sortOrder, 0);
    expect(tas[1].sortOrder, 1);
  });

  test('duplicate assessment key does not create duplicate trial assessments',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'ta_dupkey_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5,6\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(tas, hasLength(1));
  });

  test('import creates session and session_assessments for legacy assessments',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'sess_import_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %,AVEFA 7-Jul-26 PHYGEN %\n101,1,1,5,9\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    expect(r.importSessionId, isNotNull);
    final sid = r.importSessionId!;

    final trialTas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(trialTas, hasLength(2));

    final sess = await (db.select(db.sessions)
          ..where((s) => s.id.equals(sid)))
        .getSingle();
    expect(sess.name, 'ARM Import Session');
    expect(sess.trialId, tid);

    final sas = await (db.select(db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sid)))
        .get();
    expect(sas, hasLength(2));
  });

  test(
      'open session prevents second createSession; getOpenSession matches import',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'sess_reuse_$unique.csv';
    final uc = _makeUseCase(db);
    final sessionRepo = SessionRepository(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    expect(r.importSessionId, isNotNull);

    final open = await sessionRepo.getOpenSession(tid);
    expect(open, isNotNull);
    expect(open!.id, r.importSessionId);

    final sas = await (db.select(db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(r.importSessionId!)))
        .get();
    final assessmentIds = sas.map((e) => e.assessmentId).toList();

    expect(
      () => sessionRepo.createSession(
        trialId: tid,
        name: 'Another Session',
        sessionDateLocal: '2026-06-15',
        assessmentIds: assessmentIds,
      ),
      throwsA(isA<OpenSessionExistsException>()),
    );

    expect((await sessionRepo.getOpenSession(tid))!.id, r.importSessionId);
  });

  test(
      'unresolved assessment definition yields warning but import succeeds',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'ta_unresolved_$unique.csv';
    final uc = ArmImportUseCase(
      db,
      TrialRepository(db),
      TreatmentRepository(db),
      PlotRepository(db),
      AssignmentRepository(db),
      _OmitFirstKeyResolver(AssessmentDefinitionRepository(db)),
      TrialAssessmentRepository(db),
      SessionRepository(db),
      SaveRatingUseCase(RatingRepository(db)),
      ArmCsvParser(),
      ArmImportSnapshotService(),
      CompatibilityProfileBuilder(),
      ArmImportPersistenceRepository(db),
      ArmImportReportBuilder(),
    );
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    expect(
      r.warnings.any((w) => w.startsWith('Assessment could not be linked:')),
      isTrue,
    );
    final tid = r.trialId!;
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(tid)))
        .get();
    expect(tas, isEmpty);
  });

  test('resolver failure causes transaction rollback', () async {
    final trialsBefore = await db.select(db.trials).get();

    final uc = ArmImportUseCase(
      db,
      TrialRepository(db),
      TreatmentRepository(db),
      PlotRepository(db),
      AssignmentRepository(db),
      _ThrowingResolver(AssessmentDefinitionRepository(db)),
      TrialAssessmentRepository(db),
      SessionRepository(db),
      SaveRatingUseCase(RatingRepository(db)),
      ArmCsvParser(),
      ArmImportSnapshotService(),
      CompatibilityProfileBuilder(),
      ArmImportPersistenceRepository(db),
      ArmImportReportBuilder(),
    );

    final unique = DateTime.now().microsecondsSinceEpoch;
    final r = await uc.execute(
      'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n',
      sourceFileName: 'resolver_throw_$unique.csv',
    );

    expect(r.success, false);
    expect(r.errorMessage, contains('ARM import failed:'));
    expect(r.errorMessage, contains('resolver boom'));

    final trialsAfter = await db.select(db.trials).get();
    expect(trialsAfter.length, trialsBefore.length);
  });

  test('transaction rolls back when persistence fails mid-flight', () async {
    final trialsBefore = await db.select(db.trials).get();

    final uc = ArmImportUseCase(
      db,
      TrialRepository(db),
      TreatmentRepository(db),
      PlotRepository(db),
      AssignmentRepository(db),
      ArmAssessmentDefinitionResolver(AssessmentDefinitionRepository(db)),
      TrialAssessmentRepository(db),
      SessionRepository(db),
      SaveRatingUseCase(RatingRepository(db)),
      ArmCsvParser(),
      ArmImportSnapshotService(),
      CompatibilityProfileBuilder(),
      _ThrowOnProfileInsert(db),
      ArmImportReportBuilder(),
    );

    final unique = DateTime.now().microsecondsSinceEpoch;
    final r = await uc.execute(
      'Plot No.,trt,reps\n',
      sourceFileName: 'rollback_$unique.csv',
    );

    expect(r.success, false);
    expect(r.errorMessage, contains('ARM import failed:'));
    expect(r.errorMessage, contains('simulated failure'));

    final trialsAfter = await db.select(db.trials).get();
    expect(trialsAfter.length, trialsBefore.length);

    final linked = await (db.select(db.trials)
          ..where((t) => t.isArmLinked.equals(true)))
        .get();
    expect(linked, isEmpty);
  });

  const kDuplicateChecksumWarning =
      'This file appears to have been imported before. Proceed with caution.';

  test('duplicate checksum adds warning on second import with same content',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r1 = await uc.execute(content, sourceFileName: 'first_$unique.csv');
    expect(r1.success, true);
    expect(r1.duplicateDetected, false);
    expect(r1.priorTrialIds, isEmpty);
    expect(r1.warnings, isNot(contains(kDuplicateChecksumWarning)));

    final r2 = await uc.execute(content, sourceFileName: 'second_$unique.csv');
    expect(r2.success, true);
    expect(r2.duplicateDetected, true);
    expect(r2.priorTrialIds, contains(r1.trialId));
    expect(r2.warnings, contains(kDuplicateChecksumWarning));
  });

  test('different file content does not add duplicate checksum warning',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final uc = _makeUseCase(db);
    const content1 =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';
    const content2 =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,6\n';

    final r1 = await uc.execute(content1, sourceFileName: 'a_$unique.csv');
    expect(r1.success, true);
    expect(r1.duplicateDetected, false);
    expect(r1.priorTrialIds, isEmpty);
    expect(r1.warnings, isNot(contains(kDuplicateChecksumWarning)));

    final r2 = await uc.execute(content2, sourceFileName: 'b_$unique.csv');
    expect(r2.success, true);
    expect(r2.duplicateDetected, false);
    expect(r2.priorTrialIds, isEmpty);
    expect(r2.warnings, isNot(contains(kDuplicateChecksumWarning)));
  });

  test('ArmImportResult.failure exposes default duplicate metadata', () {
    final r = ArmImportResult.failure('x');
    expect(r.duplicateDetected, false);
    expect(r.priorTrialIds, isEmpty);
  });

  test('import persists numeric rating via SaveRatingUseCase', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'rating_num_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    expect(r.importSessionId, isNotNull);
    final sid = r.importSessionId!;

    final ratings = await (db.select(db.ratingRecords)
          ..where((rr) => rr.trialId.equals(tid) & rr.sessionId.equals(sid)))
        .get();
    expect(ratings, hasLength(1));
    expect(ratings.single.numericValue, 5.0);
    expect(ratings.single.textValue, isNull);
    expect(ratings.single.isCurrent, isTrue);
  });

  test('import persists text rating when cell is non-numeric', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'rating_txt_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,low\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final sid = r.importSessionId!;

    final ratings = await (db.select(db.ratingRecords)
          ..where((rr) => rr.trialId.equals(tid) & rr.sessionId.equals(sid)))
        .get();
    expect(ratings, hasLength(1));
    expect(ratings.single.numericValue, isNull);
    expect(ratings.single.textValue, 'low');
    expect(ratings.single.isCurrent, isTrue);
  });

  test('blank assessment cell is skipped (no rating row)', () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'rating_blank_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %,AVEFA 7-Jul-26 PHYGEN %\n101,1,1,5,\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final sid = r.importSessionId!;

    final ratings = await (db.select(db.ratingRecords)
          ..where((rr) => rr.trialId.equals(tid) & rr.sessionId.equals(sid)))
        .get();
    expect(ratings, hasLength(1));
    expect(ratings.single.numericValue, 5.0);
  });

  test('multiple plots and assessment columns produce expected rating count',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'rating_multi_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %,AVEFA 7-Jul-26 PHYGEN %\n101,1,1,1,2\n102,1,1,3,4\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final sid = r.importSessionId!;

    final ratings = await (db.select(db.ratingRecords)
          ..where((rr) => rr.trialId.equals(tid) & rr.sessionId.equals(sid)))
        .get();
    expect(ratings, hasLength(4));
    expect(ratings.where((rr) => rr.isCurrent).length, 4);
  });

  test('second save for same plot/assessment/session updates isCurrent chain',
      () async {
    final unique = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'rating_version_$unique.csv';
    final uc = _makeUseCase(db);
    const content =
        'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';

    final r = await uc.execute(content, sourceFileName: fileName);

    expect(r.success, true);
    final tid = r.trialId!;
    final sid = r.importSessionId!;

    final plots = await (db.select(db.plots)
          ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    final plotPk = plots.single.id;

    final first = await (db.select(db.ratingRecords)
          ..where((rr) =>
              rr.trialId.equals(tid) &
              rr.sessionId.equals(sid) &
              rr.plotPk.equals(plotPk)))
        .get();
    expect(first, hasLength(1));
    final assessmentId = first.single.assessmentId;

    final save = SaveRatingUseCase(RatingRepository(db));
    final second = await save.execute(
      SaveRatingInput(
        trialId: tid,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sid,
        resultStatus: 'RECORDED',
        numericValue: 7.0,
        textValue: null,
        isSessionClosed: false,
      ),
    );
    expect(second.isSuccess, isTrue);

    final chain = await (db.select(db.ratingRecords)
          ..where((rr) =>
              rr.trialId.equals(tid) &
              rr.sessionId.equals(sid) &
              rr.plotPk.equals(plotPk) &
              rr.assessmentId.equals(assessmentId)))
        .get();
    expect(chain, hasLength(2));
    expect(chain.where((rr) => rr.isCurrent).length, 1);
    expect(chain.where((rr) => rr.isCurrent).single.numericValue, 7.0);
    expect(chain.where((rr) => !rr.isCurrent).single.numericValue, 5.0);
  });
}

class _OmitFirstKeyResolver extends ArmAssessmentDefinitionResolver {
  _OmitFirstKeyResolver(super._definitions);

  @override
  Future<ResolvedArmAssessmentDefinitions> resolveAll({
    required int trialId,
    required List<AssessmentToken> assessments,
  }) async {
    final base = await super.resolveAll(
      trialId: trialId,
      assessments: assessments,
    );
    if (base.assessmentKeyToDefinitionId.isEmpty) return base;
    final firstKey = base.assessmentKeyToDefinitionId.keys.first;
    final m = Map<String, int>.from(base.assessmentKeyToDefinitionId)
      ..remove(firstKey);
    return ResolvedArmAssessmentDefinitions(
      assessmentKeyToDefinitionId: m,
      warnings: base.warnings,
      unknownPatterns: base.unknownPatterns,
    );
  }
}

class _ThrowingResolver extends ArmAssessmentDefinitionResolver {
  _ThrowingResolver(super._definitions);

  @override
  Future<ResolvedArmAssessmentDefinitions> resolveAll({
    required int trialId,
    required List<AssessmentToken> assessments,
  }) async {
    throw StateError('resolver boom');
  }
}

class _ThrowOnProfileInsert extends ArmImportPersistenceRepository {
  _ThrowOnProfileInsert(super.db);

  @override
  Future<int> insertCompatibilityProfile(
    CompatibilityProfilePayload payload, {
    required int trialId,
    required int snapshotId,
  }) async {
    throw StateError('simulated failure');
  }
}
