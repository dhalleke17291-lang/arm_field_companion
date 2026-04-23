// Phase 1a — schema foundation for ARM/standalone separation.
//
// Verifies that the three ARM extension tables introduced at schema v57
//   - arm_column_mappings
//   - arm_assessment_metadata
//   - arm_session_metadata
// exist on fresh installs, are created defensively during 56→57 upgrade,
// accept valid inserts referencing existing core rows, and reject inserts
// that would violate the foreign-key constraints to core tables.
//
// Standalone-correctness assertion: a trial that never touches ARM code
// must still have zero rows in any of these tables. That is exercised
// indirectly here (the tables are created empty and nothing in core
// populates them) and enforced at the code level by
// test/core/arm_separation_boundary_test.dart.

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
// `isNull`/`isNotNull` from matcher (via flutter_test) collide with
// Drift's expression builders of the same name; hide the Drift ones
// so the test expectations read naturally.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _kArmColumnMappings = 'arm_column_mappings';
const _kArmAssessmentMetadata = 'arm_assessment_metadata';
const _kArmSessionMetadata = 'arm_session_metadata';
const _kArmTreatmentMetadata = 'arm_treatment_metadata';

Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void _setUserVersion(String path, int version) {
  final raw = sqlite.sqlite3.open(path);
  try {
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.dispose();
  }
}

/// Creates the minimum set of core rows needed to exercise foreign-key
/// constraints on the ARM extension tables: one trial, one session on it,
/// one assessment definition, and one trial_assessment bound to both.
Future<({int trialId, int sessionId, int trialAssessmentId})>
    _seedCoreRowsForArm(AppDatabase db) async {
  final trialId = await db.into(db.trials).insert(
        TrialsCompanion.insert(name: 'ARM Test Trial'),
      );
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'Planned — 2026-04-02',
          sessionDateLocal: '2026-04-02',
        ),
      );
  // Use a pre-seeded assessment definition (onCreate seeds them); any row
  // works, we just need a valid FK target.
  final defs =
      await (db.select(db.assessmentDefinitions)..limit(1)).get();
  expect(defs, isNotEmpty,
      reason: 'AppDatabase.onCreate should seed assessment definitions');
  final trialAssessmentId = await db.into(db.trialAssessments).insert(
        TrialAssessmentsCompanion.insert(
          trialId: trialId,
          assessmentDefinitionId: defs.first.id,
        ),
      );
  return (
    trialId: trialId,
    sessionId: sessionId,
    trialAssessmentId: trialAssessmentId,
  );
}

void main() {
  late Directory root;
  late String docsPath;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = await Directory.systemTemp.createTemp('arm_ext_migration_');
    docsPath = p.join(root.path, 'docs');
    await Directory(docsPath).create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('fresh install: ARM extension tables exist and are empty', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final names = await _tableNames(db);
    expect(names, contains(_kArmColumnMappings));
    expect(names, contains(_kArmAssessmentMetadata));
    expect(names, contains(_kArmSessionMetadata));
    expect(names, contains(_kArmTreatmentMetadata));

    // All four start empty — no seeding on fresh install.
    expect(await db.select(db.armColumnMappings).get(), isEmpty);
    expect(await db.select(db.armAssessmentMetadata).get(), isEmpty);
    expect(await db.select(db.armSessionMetadata).get(), isEmpty);
    expect(await db.select(db.armTreatmentMetadata).get(), isEmpty);
  });

  test(
    '56 → 57 upgrade: defensive createTable adds ARM extension tables when absent',
    () async {
      final dbFile = File(p.join(docsPath, 'upgrade_56_to_57.db'));
      if (await dbFile.exists()) await dbFile.delete();

      // Bring a DB up at the current schema, then simulate a pre-57 DB by
      // dropping the three ARM tables and resetting user_version to 56.
      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      await _tableNames(db);

      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('DROP TABLE IF EXISTS arm_column_mappings');
      await db.customStatement('DROP TABLE IF EXISTS arm_assessment_metadata');
      await db.customStatement('DROP TABLE IF EXISTS arm_session_metadata');
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db.close();

      _setUserVersion(dbFile.path, 56);

      // Reopen; Drift runs onUpgrade(56, 57) and recreates the tables.
      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains(_kArmColumnMappings));
      expect(names, contains(_kArmAssessmentMetadata));
      expect(names, contains(_kArmSessionMetadata));
    },
  );

  test('56 → 57 upgrade: idempotent when tables already exist', () async {
    final dbFile = File(p.join(docsPath, 'upgrade_idempotent.db'));
    if (await dbFile.exists()) await dbFile.delete();

    var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    await _tableNames(db);
    await db.close();

    // Reset version to 56 without dropping the tables — the v57 migration
    // should no-op on its defensive table creations.
    _setUserVersion(dbFile.path, 56);

    db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    addTearDown(db.close);

    final names = await _tableNames(db);
    expect(names, contains(_kArmColumnMappings));
    expect(names, contains(_kArmAssessmentMetadata));
    expect(names, contains(_kArmSessionMetadata));
  });

  test('ARM extension rows reference valid core trial/session/assessment',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final ids = await _seedCoreRowsForArm(db);

    final mappingId = await db.into(db.armColumnMappings).insert(
          ArmColumnMappingsCompanion.insert(
            trialId: ids.trialId,
            armColumnId: '3',
            armColumnIndex: 0,
            armColumnIdInteger: const Value(3),
            trialAssessmentId: Value(ids.trialAssessmentId),
            sessionId: Value(ids.sessionId),
          ),
        );
    expect(mappingId, greaterThan(0));

    final assessmentMetaId =
        await db.into(db.armAssessmentMetadata).insert(
              ArmAssessmentMetadataCompanion.insert(
                trialAssessmentId: ids.trialAssessmentId,
                seName: const Value('W003'),
                seDescription: const Value('Weed Control'),
                partRated: const Value('PLANT'),
                ratingType: const Value('CONTRO'),
                ratingUnit: const Value('%'),
                ratingMin: const Value(0),
                ratingMax: const Value(100),
                collectBasis: const Value('P'),
              ),
            );
    expect(assessmentMetaId, greaterThan(0));

    final sessionMetaId = await db.into(db.armSessionMetadata).insert(
          ArmSessionMetadataCompanion.insert(
            sessionId: ids.sessionId,
            armRatingDate: '2026-04-02',
            timingCode: const Value('A1'),
            cropStageMaj: const Value('V5'),
            cropStageScale: const Value('BBCH'),
            trtEvalInterval: const Value('0 DA-A'),
          ),
        );
    expect(sessionMetaId, greaterThan(0));

    // Orphan column: trial_assessment_id and session_id null is allowed.
    final orphanId = await db.into(db.armColumnMappings).insert(
          ArmColumnMappingsCompanion.insert(
            trialId: ids.trialId,
            armColumnId: '9',
            armColumnIndex: 3,
          ),
        );
    expect(orphanId, greaterThan(0));

    final mappings = await db.select(db.armColumnMappings).get();
    expect(mappings, hasLength(2));
  });

  test('ARM extension inserts are rejected when FKs point at missing rows',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // Drift enables foreign keys by default; assert explicitly so any
    // future change is caught here.
    await db.customStatement('PRAGMA foreign_keys = ON');

    // Bogus trial_id → FK violation.
    expect(
      () => db.into(db.armColumnMappings).insert(
            ArmColumnMappingsCompanion.insert(
              trialId: 99999,
              armColumnId: '3',
              armColumnIndex: 0,
            ),
          ),
      throwsA(anything),
    );

    // Bogus trial_assessment_id on assessment metadata → FK violation.
    expect(
      () => db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: 99999,
              seName: const Value('BOGUS'),
            ),
          ),
      throwsA(anything),
    );

    // Bogus session_id on session metadata → FK violation.
    expect(
      () => db.into(db.armSessionMetadata).insert(
            ArmSessionMetadataCompanion.insert(
              sessionId: 99999,
              armRatingDate: '2026-04-02',
            ),
          ),
      throwsA(anything),
    );

    // Bogus treatment_id on treatment metadata → FK violation.
    expect(
      () => db.into(db.armTreatmentMetadata).insert(
            ArmTreatmentMetadataCompanion.insert(
              treatmentId: 99999,
              armTypeCode: const Value('H'),
            ),
          ),
      throwsA(anything),
    );
  });

  // ── Phase 0b-treatments (v62) ──
  test(
    '61 → 62 upgrade: defensive createTable adds arm_treatment_metadata when absent',
    () async {
      final dbFile = File(p.join(docsPath, 'upgrade_61_to_62.db'));
      if (await dbFile.exists()) await dbFile.delete();

      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      await _tableNames(db);

      // Simulate a v61 DB: drop only the new v62 table.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('DROP TABLE IF EXISTS arm_treatment_metadata');
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db.close();

      _setUserVersion(dbFile.path, 61);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains(_kArmTreatmentMetadata));
      expect(await db.select(db.armTreatmentMetadata).get(), isEmpty,
          reason: 'Phase 0b-treatments does not backfill; no writer yet');
    },
  );

  test('61 → 62 upgrade: idempotent when arm_treatment_metadata already exists',
      () async {
    final dbFile = File(p.join(docsPath, 'upgrade_62_idempotent.db'));
    if (await dbFile.exists()) await dbFile.delete();

    var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    await _tableNames(db);
    await db.close();

    _setUserVersion(dbFile.path, 61);

    db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    addTearDown(db.close);

    final names = await _tableNames(db);
    expect(names, contains(_kArmTreatmentMetadata));
  });

  test('arm_treatment_metadata row references a valid core treatment',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = ON');

    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Treatment Test'),
        );
    final treatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: 'T1',
            name: 'Test Herbicide',
          ),
        );

    final metaId = await db.into(db.armTreatmentMetadata).insert(
          ArmTreatmentMetadataCompanion.insert(
            treatmentId: treatmentId,
            armTypeCode: const Value('H'),
            formConc: const Value(480),
            formConcUnit: const Value('%W/V'),
            formType: const Value('SC'),
            armRowSortOrder: const Value(0),
          ),
        );
    expect(metaId, greaterThan(0));

    final rows = await db.select(db.armTreatmentMetadata).get();
    expect(rows, hasLength(1));
    expect(rows.single.formConcUnit, '%W/V');
  });

  // ── Phase 2b (v63) ──
  //
  // v63 is an additive backfill: for every ARM-linked trial's treatment
  // that has a non-blank core `treatment_type` but no `arm_treatment_metadata`
  // row yet, synthesize an AAM row with `arm_type_code = treatment_type`.
  // Standalone trials (no arm_trial_metadata row, or isArmLinked=0) must
  // remain untouched, and existing AAM rows must not be overwritten.
  test('62 → 63 upgrade: backfills arm_type_code for ARM-linked trials only',
      () async {
    final dbFile = File(p.join(docsPath, 'upgrade_62_to_63_backfill.db'));
    if (await dbFile.exists()) await dbFile.delete();

    // Boot at current schema so tables exist, then seed the state v63
    // should see and wind user_version back to 62.
    var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));

    // Trial A: ARM-linked, one treatment with type 'HERB' and no AAM row
    //          → expect backfill.
    final trialAId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Linked'),
        );
    final trialATreatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialAId,
            code: 'T1',
            name: 'Herbicide A',
            treatmentType: const Value('HERB'),
          ),
        );
    await db.into(db.armTrialMetadata).insert(
          ArmTrialMetadataCompanion(
            trialId: Value(trialAId),
            isArmLinked: const Value(true),
          ),
        );

    // Trial B: ARM-linked, treatment already has an AAM row with a
    //          pre-existing armTypeCode ('CHK') → expect untouched.
    final trialBId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Linked With AAM'),
        );
    final trialBTreatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialBId,
            code: 'T1',
            name: 'Check',
            treatmentType: const Value('HERB'),
          ),
        );
    await db.into(db.armTrialMetadata).insert(
          ArmTrialMetadataCompanion(
            trialId: Value(trialBId),
            isArmLinked: const Value(true),
          ),
        );
    await db.into(db.armTreatmentMetadata).insert(
          ArmTreatmentMetadataCompanion.insert(
            treatmentId: trialBTreatmentId,
            armTypeCode: const Value('CHK'),
          ),
        );

    // Trial C: standalone (no arm_trial_metadata row) → expect untouched.
    final trialCId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'Standalone'),
        );
    final trialCTreatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialCId,
            code: 'T1',
            name: 'Private',
            treatmentType: const Value('FUNG'),
          ),
        );

    // Trial D: ARM-linked but isArmLinked = false → expect untouched.
    final trialDId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Metadata Only'),
        );
    final trialDTreatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialDId,
            code: 'T1',
            name: 'Orphan',
            treatmentType: const Value('HERB'),
          ),
        );
    await db.into(db.armTrialMetadata).insert(
          ArmTrialMetadataCompanion(
            trialId: Value(trialDId),
            isArmLinked: const Value(false),
          ),
        );

    // Trial E: ARM-linked, treatment has blank/null treatment_type
    //          → expect untouched (nothing to backfill).
    final trialEId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Linked Blank Type'),
        );
    final trialETreatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialEId,
            code: 'T1',
            name: 'Unknown',
          ),
        );
    await db.into(db.armTrialMetadata).insert(
          ArmTrialMetadataCompanion(
            trialId: Value(trialEId),
            isArmLinked: const Value(true),
          ),
        );

    await db.close();
    _setUserVersion(dbFile.path, 62);

    db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    addTearDown(db.close);

    // Force schema migration by reading.
    await _tableNames(db);

    final all = await db.select(db.armTreatmentMetadata).get();
    final byTreatment = {for (final r in all) r.treatmentId: r};

    // Trial A: backfilled.
    expect(byTreatment[trialATreatmentId]?.armTypeCode, 'HERB',
        reason: 'ARM-linked + type=HERB + no AAM row → should backfill');

    // Trial B: pre-existing row untouched.
    expect(byTreatment[trialBTreatmentId]?.armTypeCode, 'CHK',
        reason: 'Existing AAM row must not be overwritten by backfill');
    expect(
        all.where((r) => r.treatmentId == trialBTreatmentId).length, 1,
        reason: 'Backfill must not create a duplicate AAM row');

    // Trial C: standalone untouched.
    expect(byTreatment[trialCTreatmentId], isNull,
        reason: 'Standalone trials must never gain an AAM row');

    // Trial D: isArmLinked=false untouched.
    expect(byTreatment[trialDTreatmentId], isNull,
        reason: 'isArmLinked=false trials must be treated as standalone');

    // Trial E: blank treatment_type untouched.
    expect(byTreatment[trialETreatmentId], isNull,
        reason: 'Blank treatment_type provides nothing to backfill');
  });

  test('62 → 63 upgrade: rerunning schema migration is idempotent',
      () async {
    final dbFile = File(p.join(docsPath, 'upgrade_62_to_63_idempotent.db'));
    if (await dbFile.exists()) await dbFile.delete();

    var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(name: 'ARM Linked'),
        );
    final treatmentId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: 'T1',
            name: 'Herbicide A',
            treatmentType: const Value('HERB'),
          ),
        );
    await db.into(db.armTrialMetadata).insert(
          ArmTrialMetadataCompanion(
            trialId: Value(trialId),
            isArmLinked: const Value(true),
          ),
        );

    await db.close();
    _setUserVersion(dbFile.path, 62);

    db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    await _tableNames(db);
    final firstCount =
        (await db.select(db.armTreatmentMetadata).get()).length;
    expect(firstCount, 1);
    await db.close();

    // Winding back to 62 and reopening re-runs the backfill.
    _setUserVersion(dbFile.path, 62);
    db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    addTearDown(db.close);
    await _tableNames(db);

    final secondQuery = db.select(db.armTreatmentMetadata)
      ..where((r) => r.treatmentId.equals(treatmentId));
    final secondRows = await secondQuery.get();
    expect(secondRows, hasLength(1),
        reason: 'Re-running v63 must not create a duplicate AAM row');
  });

  test('v64: arm_assessment_metadata includes Phase 1 shell_* columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pragma = await db.customSelect(
      "SELECT name FROM pragma_table_info('arm_assessment_metadata')",
    ).get();
    final colNames = pragma.map((r) => r.read<String>('name')).toSet();
    expect(colNames, contains('shell_pest_type'));
    expect(colNames, contains('shell_size_unit'));
    expect(colNames, contains('shell_assessed_by'));
    expect(colNames, contains('shell_arm_actions'));
  });

  test('v65: arm_assessment_metadata includes timing / interval shell columns',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final pragma = await db.customSelect(
      "SELECT name FROM pragma_table_info('arm_assessment_metadata')",
    ).get();
    final colNames = pragma.map((r) => r.read<String>('name')).toSet();
    expect(colNames, contains('shell_app_timing_code'));
    expect(colNames, contains('shell_trt_eval_interval'));
    expect(colNames, contains('shell_plant_eval_interval'));
  });
}
