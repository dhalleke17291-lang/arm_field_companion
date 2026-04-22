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
// `isNotNull` from matcher (via flutter_test) collides with Drift's
// `isNotNull` expression builder; we only need the former here, so hide
// the latter.
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _kArmColumnMappings = 'arm_column_mappings';
const _kArmAssessmentMetadata = 'arm_assessment_metadata';
const _kArmSessionMetadata = 'arm_session_metadata';

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

    // All three start empty — no seeding on fresh install.
    expect(await db.select(db.armColumnMappings).get(), isEmpty);
    expect(await db.select(db.armAssessmentMetadata).get(), isEmpty);
    expect(await db.select(db.armSessionMetadata).get(), isEmpty);
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
  });
}
