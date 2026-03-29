import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_report_builder.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_snapshot_service.dart';
import 'package:arm_field_companion/features/arm_import/data/compatibility_profile_builder.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/usecases/arm_import_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:csv/csv.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ArmImportUseCase _makeUseCase(
  AppDatabase db, {
  ArmImportPersistenceRepository? persistence,
}) {
  return ArmImportUseCase(
    db,
    TrialRepository(db),
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

    final table = const CsvToListConverter(eol: '\n').convert(content);
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
    expect(r.warnings, expectedReport.warnings);
    expect(r.unknownPatterns, parsed.unknownPatterns);

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

  test('transaction rolls back when persistence fails mid-flight', () async {
    final trialsBefore = await db.select(db.trials).get();

    final uc = ArmImportUseCase(
      db,
      TrialRepository(db),
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
