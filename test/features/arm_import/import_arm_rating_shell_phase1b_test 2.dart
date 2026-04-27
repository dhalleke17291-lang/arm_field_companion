// Phase 1b — importer rewrite + exporter bridge.
//
// Exercises the new semantics introduced by Phase 1b:
//   * ARM columns are deduplicated into one trial_assessment per unique
//     (SE Name, Part Rated, Rating Type, Rating Unit).
//   * One `'planned'` session is created per unique ARM Rating Date.
//   * arm_column_mappings has one row per shell column (including orphans
//     with null FKs when the shell column has blank identity fields).
//   * arm_assessment_metadata has one row per deduplicated trial_assessment.
//   * arm_session_metadata has one row per planned session.
//
// Round-trip: import → open one planned session → save a rating → export
// the same shell; the rating must land in the ARM column that corresponds
// to that (assessment, session) pair via arm_column_mappings.

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/session_state.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/arm/arm_treatment_metadata_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart'
    show ResultStatusDb;
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/export/domain/export_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

String _cellText(Sheet sheet, int row, int col) {
  final v = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  return v.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late PathProviderPlatform savedProvider;

  setUp(() async {
    savedProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('phase1b_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ImportArmRatingShellUseCase makeImporter() {
    final assignmentRepo = AssignmentRepository(db);
    return ImportArmRatingShellUseCase(
      db: db,
      trialRepository: TrialRepository(db),
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db, assignmentRepo),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      assignmentRepository: assignmentRepo,
      armColumnMappingRepository: ArmColumnMappingRepository(db),
      armApplicationsRepository: ArmApplicationsRepository(db),
    );
  }

  test(
      'dedup: three columns with same SE name and different dates → '
      '1 assessment + 3 planned sessions + 3 mappings', () async {
    // Shell: three "W003 / PLANT / CONTRO" columns, different dates.
    final shellPath = await writeArmShellFixture(
      tempDir.path,
      plotNumbers: const [101, 102],
      armColumnIds: const ['3', '6', '7'],
      seNames: const ['W003', 'W003', 'W003'],
      seDescriptions: const ['Weed Control', 'Weed Control', 'Weed Control'],
      ratingDates: const ['2-Apr-26', '23-Apr-26', '14-May-26'],
      ratingTypes: const ['CONTRO', 'CONTRO', 'CONTRO'],
      ratingUnits: const ['%', '%', '%'],
    );

    final result = await makeImporter().execute(shellPath);
    expect(result.success, isTrue, reason: result.errorMessage);
    final trialId = result.trialId!;

    expect(result.armColumnCount, 3);
    expect(result.assessmentCount, 1,
        reason: 'three ARM columns with identical identity → one assessment');
    expect(result.plannedSessionCount, 3,
        reason: 'three distinct rating dates → three planned sessions');

    // Assessments: exactly one trial_assessment for this dedup group.
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId)))
        .get();
    expect(tas, hasLength(1));
    final ta = tas.single;

    // arm_assessment_metadata: one row, identity fields match. The SE
    // name / rating type live solely on AAM since v61 (Unit 5d).
    final metas = await (db.select(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(ta.id)))
        .get();
    expect(metas, hasLength(1));
    expect(metas.single.seName, 'W003');
    expect(metas.single.ratingType, 'CONTRO');
    expect(metas.single.ratingUnit, '%');

    // Sessions: three planned, one per unique rating date, endedAt null,
    // status exactly [kSessionStatusPlanned].
    final sessions = await (db.select(db.sessions)
          ..where((s) => s.trialId.equals(trialId))
          ..orderBy([(s) => OrderingTerm.asc(s.sessionDateLocal)]))
        .get();
    expect(sessions, hasLength(3));
    for (final s in sessions) {
      expect(s.status, kSessionStatusPlanned);
      expect(s.endedAt, isNull);
    }

    // Planned sessions must NOT surface as "open for field work".
    final open = await SessionRepository(db).getOpenSession(trialId);
    expect(open, isNull,
        reason: 'planned sessions are not open field-work sessions');

    // arm_session_metadata: one row per session with the raw ARM date.
    final sessionMetas = await db.select(db.armSessionMetadata).get();
    expect(sessionMetas, hasLength(3));
    final dates = sessionMetas.map((m) => m.armRatingDate).toSet();
    expect(dates, {'2026-04-02', '2026-04-23', '2026-05-14'},
        reason: 'shell d-Mmm-yy dates normalize to yyyy-MM-dd on sessions '
            'and arm_session_metadata');

    // arm_column_mappings: one row per shell column, all pointing at the
    // same trial_assessment and at distinct sessions.
    final mappings = await ArmColumnMappingRepository(db).getForTrial(trialId);
    expect(mappings, hasLength(3));
    expect(mappings.map((m) => m.trialAssessmentId).toSet(), {ta.id});
    expect(
      mappings.map((m) => m.sessionId).whereType<int>().toSet().length,
      3,
      reason: 'three columns must map to three distinct sessions',
    );
    expect(
      mappings.map((m) => m.armColumnId).toList(),
      orderedEquals(['3', '6', '7']),
    );
  });

  test(
      'orphan columns: shell column with blank identity fields → mapping '
      'row with null FKs and no trial_assessment', () async {
    // Two real columns plus one column with all identity fields blank.
    // The importer's writeArmShellFixture helper always seeds a non-empty
    // ratingType/ratingUnit when not overridden; pass empty strings to make
    // the middle column fully orphan-like.
    final shellPath = await writeArmShellFixture(
      tempDir.path,
      plotNumbers: const [101],
      armColumnIds: const ['3', '9', '6'],
      seNames: const ['W003', '', 'W003'],
      seDescriptions: const ['Weed Control', '', 'Weed Control'],
      ratingDates: const ['2-Apr-26', '', '23-Apr-26'],
      ratingTypes: const ['CONTRO', '', 'CONTRO'],
      ratingUnits: const ['%', '', '%'],
      ratingTimings: const ['A1', '', 'A3'],
    );

    final result = await makeImporter().execute(shellPath);
    expect(result.success, isTrue, reason: result.errorMessage);
    final trialId = result.trialId!;

    // armColumnCount reflects *all* shell columns including the orphan,
    // but the orphan does not create an assessment or a session.
    expect(result.armColumnCount, 3);
    expect(result.assessmentCount, 1);
    expect(result.plannedSessionCount, 2,
        reason: 'orphan column has no date → no session');

    final mappings = await ArmColumnMappingRepository(db).getForTrial(trialId);
    expect(mappings, hasLength(3));
    final orphan =
        mappings.firstWhere((m) => m.armColumnId == '9');
    expect(orphan.trialAssessmentId, isNull);
    expect(orphan.sessionId, isNull);

    final nonOrphan = mappings.where((m) => m.armColumnId != '9').toList();
    expect(nonOrphan.every((m) => m.trialAssessmentId != null), isTrue);
    expect(nonOrphan.every((m) => m.sessionId != null), isTrue);
  });

  test(
      'round-trip: rating saved in one planned session exports to that '
      "column's cell and leaves the other sibling column empty", () async {
    // Two columns for the same measurement on two different dates.
    final shellPath = await writeArmShellFixture(
      tempDir.path,
      plotNumbers: const [101],
      armColumnIds: const ['3', '6'],
      seNames: const ['W003', 'W003'],
      seDescriptions: const ['Weed Control', 'Weed Control'],
      ratingDates: const ['2-Apr-26', '23-Apr-26'],
      ratingTypes: const ['CONTRO', 'CONTRO'],
      ratingUnits: const ['%', '%'],
    );

    final trialId = (await makeImporter().execute(shellPath)).trialId!;

    // Pick the earlier session to rate into. Move it from planned → open
    // so saveRating is permitted and the exporter's session-id fetch finds
    // ratings there. (Normal session-start flow performs this transition.)
    final sessions = await (db.select(db.sessions)
          ..where((s) => s.trialId.equals(trialId))
          ..orderBy([(s) => OrderingTerm.asc(s.sessionDateLocal)]))
        .get();
    final earlySession = sessions.first; // canonical 2026-04-02
    await (db.update(db.sessions)..where((s) => s.id.equals(earlySession.id)))
        .write(const SessionsCompanion(
      status: Value(kSessionStatusOpen),
    ));

    // Create the legacy Assessments row the rating_records table points at.
    final tas = await (db.select(db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId)))
        .get();
    final ta = tas.single;
    final legacyIds = await TrialAssessmentRepository(db)
        .getOrCreateLegacyAssessmentIdsForTrialAssessments(trialId, [ta.id]);
    expect(legacyIds, hasLength(1));

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    final plot = plots.firstWhere((p) => p.plotId == '101');

    await RatingRepository(db).saveRating(
      trialId: trialId,
      plotPk: plot.id,
      assessmentId: legacyIds.single,
      sessionId: earlySession.id,
      resultStatus: ResultStatusDb.recorded,
      numericValue: 42.5,
      isSessionClosed: false,
    );

    // Export back into a fresh copy of the same shell.
    final exporter = ExportArmRatingShellUseCase(
      db: db,
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      ratingRepository: RatingRepository(db),
      sessionRepository: SessionRepository(db),
      persistence: ArmImportPersistenceRepository(db),
      armColumnMappingRepository: ArmColumnMappingRepository(db),
      armApplicationsRepository: ArmApplicationsRepository(db),
      armTreatmentMetadataRepository: ArmTreatmentMetadataRepository(db),
      shareOverride: (_) async {},
      pickShellPathOverride: () async => shellPath,
    );

    final trialRow = await (db.select(db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingle();
    final out = await exporter.execute(trial: trialRow);
    expect(out.success, isTrue, reason: out.errorMessage);
    final outPath = out.filePath;
    expect(outPath, isNotNull);

    final bytes = await File(outPath!).readAsBytes();
    final sheet = Excel.decodeBytes(bytes).sheets['Plot Data']!;

    // Shell layout: first plot row is at index 48 (row 48 0-based). Data
    // columns start at column 2. We wrote a rating for session on date
    // '2-Apr-26' — that is ARM column id '3' at shell column index 2.
    expect(_cellText(sheet, 48, 2), '42.5',
        reason: 'rating must appear in the column whose arm_column_mapping '
            'points at the rated session');
    expect(_cellText(sheet, 48, 3), '',
        reason: 'sibling column for the other date must stay empty');
  });

  test(
      'Phase 1 Plot Data: persists descriptor rows on AAM and session rater',
      () async {
    final shellPath = await writeArmShellFixture(
      tempDir.path,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      pestCodesFromSheet: const ['PCODE99'],
      ratingDates: const ['1-Jul-26'],
      ratingTypes: const ['CONTRO'],
      ratingTimings: const ['A9'],
      plotDataSizeUnit: 'SU',
      plotDataCollectBasis: 'CB',
      plotDataAssessedBy: 'J.S.',
    );

    final result = await makeImporter().execute(shellPath);
    expect(result.success, isTrue, reason: result.errorMessage);

    final aam = await db.select(db.armAssessmentMetadata).getSingle();
    expect(aam.pestCode, 'PCODE99',
        reason: '003EPT row wins over SE Name for AAM.pestCode');
    expect(aam.collectBasis, 'CB');
    expect(aam.shellSizeUnit, 'SU');
    expect(aam.shellAssessedBy, 'J.S.');
    expect(aam.shellAppTimingCode, 'A9');

    final session = await db.select(db.sessions).getSingle();
    expect(session.sessionDateLocal, '2026-07-01');
    expect(session.raterName, 'J.S.');
    expect(session.startedAt.toUtc(),
        DateTime.utc(2026, 7, 1),
        reason: 'parsed shell dates set startedAt to UTC midnight');

    final asm = await db.select(db.armSessionMetadata).getSingle();
    expect(asm.armRatingDate, '2026-07-01');
    expect(asm.raterInitials, 'J.S.');
  });
}
