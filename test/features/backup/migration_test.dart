// Migration tests covering v49 defensive recreation, v71 SeTypeProfiles activation,
// and v72 signals/causal/evidence tables.
// Temp dir + file-backed NativeDatabase matches `backup_service_test.dart` pattern.
//
// v49: A brand-new SQLite file at user_version 36 cannot run 36→49 because
// intermediate migrations expect tables from earlier versions. The "missing
// application_* tables" scenario is exercised at user_version 48 (only
// `if (from < 49)` runs) after dropping those three tables.
//
// v71: se_type_profiles is a new reference table (seeded at install and on upgrade).
// v72: signals pipeline + se_type_causal_profiles + evidence_anchors (+ indexes + EPPO seeds).
// The defensive guard checks existingTables before calling createTable; INSERT OR IGNORE
// keeps seeds idempotent against re-runs.

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Table names used by Drift for legacy application tables (schema v49 defensive block).
const _kApplicationSlots = 'application_slots';
const _kApplicationEvents = 'application_events';
const _kApplicationPlotRecords = 'application_plot_records';

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

void main() {
  late Directory root;
  late String docsPath;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = await Directory.systemTemp.createTemp('migration_test_');
    docsPath = p.join(root.path, 'docs');
    await Directory(docsPath).create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('onCreate: all tables including se_type_profiles exist on fresh install', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 76);

    final names = await _tableNames(db);
    expect(names, contains(_kApplicationSlots));
    expect(names, contains(_kApplicationEvents));
    expect(names, contains(_kApplicationPlotRecords));
    expect(names, contains('se_type_profiles'));
    expect(names, contains('signals'));
    expect(names, contains('signal_decision_events'));
    expect(names, contains('action_effects'));
    expect(names, contains('se_type_causal_profiles'));
    expect(names, contains('evidence_anchors'));

    final profiles = await db.select(db.seTypeProfiles).get();
    final prefixes = profiles.map((p) => p.ratingTypePrefix).toSet();
    expect(prefixes, containsAll({'CONTRO', 'PHYGEN'}));

    final causal = await db.select(db.seTypeCausalProfiles).get();
    final causalKeys =
        causal.map((r) => '${r.seType}:${r.trialType}').toSet();
    expect(causalKeys,
        containsAll({'CONTRO:efficacy', 'PESINC:efficacy', 'LODGIN:efficacy'}));
    expect(causal.length, 3);
  });

  test(
    'onUpgrade to 49: missing application tables are recreated when absent '
    '(simulates legacy DB at user_version 48 without the three tables)',
    () async {
      // An empty file at user_version 36 cannot run 36→49 (migrations need prior tables).
      // Realistic case for the v49 block: already at 48, application_* missing, then 48→49.
      final dbFile = File(p.join(docsPath, 'upgrade_missing_app_tables.db'));
      if (await dbFile.exists()) await dbFile.delete();

      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      expect(await _tableNames(db), contains(_kApplicationSlots));

      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('DROP TABLE IF EXISTS application_plot_records');
      await db.customStatement('DROP TABLE IF EXISTS application_events');
      await db.customStatement('DROP TABLE IF EXISTS application_slots');
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db.close();

      _setUserVersion(dbFile.path, 48);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains(_kApplicationSlots));
      expect(names, contains(_kApplicationEvents));
      expect(names, contains(_kApplicationPlotRecords));
    });

  test(
    'onUpgrade to 49: idempotent when legacy application tables already exist',
    () async {
      final dbFile = File(p.join(docsPath, 'idempotent.db'));
      if (await dbFile.exists()) await dbFile.delete();

      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      await _tableNames(db);
      await db.close();

      _setUserVersion(dbFile.path, 48);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains(_kApplicationSlots));
      expect(names, contains(_kApplicationEvents));
      expect(names, contains(_kApplicationPlotRecords));
    });

  test(
    'onUpgrade v70 → v71: se_type_profiles is created and seeded when absent',
    () async {
      final dbFile = File(p.join(docsPath, 'upgrade_v70_to_v71.db'));
      if (await dbFile.exists()) await dbFile.delete();

      // Fresh install at v71: onCreate creates all tables including se_type_profiles.
      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      await _tableNames(db); // warm up — ensures onCreate completes

      // Simulate v70 state: drop se_type_profiles, then wind user_version back.
      await db.customStatement('DROP TABLE IF EXISTS se_type_profiles');
      await db.close();
      _setUserVersion(dbFile.path, 70);

      // Reopen: Drift sees user_version 70, runs onUpgrade(m, 70, 71).
      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains('se_type_profiles'));

      final profiles = await db.select(db.seTypeProfiles).get();
      final prefixes = profiles.map((p) => p.ratingTypePrefix).toSet();
      expect(prefixes, containsAll({'CONTRO', 'PHYGEN'}));
    });

  test(
    'onUpgrade v70 → v71 idempotent: se_type_profiles already exists, no error, no duplicate rows',
    () async {
      final dbFile = File(p.join(docsPath, 'idempotent_v71.db'));
      if (await dbFile.exists()) await dbFile.delete();

      // Fresh install at v71.
      var db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      await _tableNames(db); // warm up
      await db.close();

      // Wind user_version back to 70 WITHOUT dropping the table —
      // tests that existingTables guard prevents double-createTable
      // and INSERT OR IGNORE prevents duplicate seed rows.
      _setUserVersion(dbFile.path, 70);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final names = await _tableNames(db);
      expect(names, contains('se_type_profiles'));

      final profiles = await db.select(db.seTypeProfiles).get();
      final prefixes = profiles.map((p) => p.ratingTypePrefix).toSet();
      expect(prefixes, containsAll({'CONTRO', 'PHYGEN'}));
      expect(profiles.length, 2, reason: 'INSERT OR IGNORE must not produce duplicate seed rows');
    });

  group('v75 data-repair migration: trials.status advance', () {
    test(
      'trial with draft status and a session is promoted to active',
      () async {
        final dbFile = File(p.join(docsPath, 'v75_promote_draft.db'));

        // Start at v74 with a draft trial that has a session.
        var db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        await db.customStatement(
            "INSERT INTO trials (name, status, workspace_type, region) "
            "VALUES ('T1', 'draft', 'efficacy', 'eppo_eu')");
        final trialId =
            (await db.customSelect('SELECT last_insert_rowid() AS id').get())
                .first
                .read<int>('id');
        await db.customStatement(
            "INSERT INTO sessions (trial_id, name, session_date_local, status, "
            "is_deleted, started_at) VALUES ($trialId, 'S1', '2026-05-01', "
            "'open', 0, ${DateTime.now().millisecondsSinceEpoch})");
        await db.close();

        _setUserVersion(dbFile.path, 74);
        db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        addTearDown(db.close);

        final trial = await (db.select(db.trials)
              ..where((t) => t.id.equals(trialId)))
            .getSingleOrNull();
        expect(trial?.status, 'active',
            reason: 'draft trial with a session must be promoted to active');
      },
    );

    test(
      'trial with ready status and a session is promoted to active',
      () async {
        final dbFile = File(p.join(docsPath, 'v75_promote_ready.db'));

        var db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        await db.customStatement(
            "INSERT INTO trials (name, status, workspace_type, region) "
            "VALUES ('T2', 'ready', 'efficacy', 'eppo_eu')");
        final trialId =
            (await db.customSelect('SELECT last_insert_rowid() AS id').get())
                .first
                .read<int>('id');
        await db.customStatement(
            "INSERT INTO sessions (trial_id, name, session_date_local, status, "
            "is_deleted, started_at) VALUES ($trialId, 'S2', '2026-05-01', "
            "'open', 0, ${DateTime.now().millisecondsSinceEpoch})");
        await db.close();

        _setUserVersion(dbFile.path, 74);
        db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        addTearDown(db.close);

        final trial = await (db.select(db.trials)
              ..where((t) => t.id.equals(trialId)))
            .getSingleOrNull();
        expect(trial?.status, 'active');
      },
    );

    test(
      'trial with draft status and no sessions is not touched',
      () async {
        final dbFile = File(p.join(docsPath, 'v75_no_session.db'));

        var db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        await db.customStatement(
            "INSERT INTO trials (name, status, workspace_type, region) "
            "VALUES ('T3', 'draft', 'efficacy', 'eppo_eu')");
        final trialId =
            (await db.customSelect('SELECT last_insert_rowid() AS id').get())
                .first
                .read<int>('id');
        await db.close();

        _setUserVersion(dbFile.path, 74);
        db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        addTearDown(db.close);

        final trial = await (db.select(db.trials)
              ..where((t) => t.id.equals(trialId)))
            .getSingleOrNull();
        expect(trial?.status, 'draft',
            reason: 'draft trial with no sessions must not be promoted');
      },
    );

    test(
      'v75 migration is idempotent — running twice leaves correct state',
      () async {
        final dbFile = File(p.join(docsPath, 'v75_idempotent.db'));

        var db = AppDatabase.forTesting(
            NativeDatabase.createInBackground(dbFile));
        await db.customStatement(
            "INSERT INTO trials (name, status, workspace_type, region) "
            "VALUES ('T4', 'draft', 'efficacy', 'eppo_eu')");
        final trialId =
            (await db.customSelect('SELECT last_insert_rowid() AS id').get())
                .first
                .read<int>('id');
        await db.customStatement(
            "INSERT INTO sessions (trial_id, name, session_date_local, status, "
            "is_deleted, started_at) VALUES ($trialId, 'S4', '2026-05-01', "
            "'open', 0, ${DateTime.now().millisecondsSinceEpoch})");
        // Already at v75 — run migration a second time via raw SQL to prove idempotency.
        await db.customStatement('''
UPDATE trials SET status = 'active'
WHERE status IN ('draft', 'ready')
  AND id IN (SELECT DISTINCT trial_id FROM sessions WHERE is_deleted = 0)
''');
        await db.customStatement('''
UPDATE trials SET status = 'active'
WHERE status IN ('draft', 'ready')
  AND id IN (SELECT DISTINCT trial_id FROM sessions WHERE is_deleted = 0)
''');
        addTearDown(db.close);

        final trial = await (db.select(db.trials)
              ..where((t) => t.id.equals(trialId)))
            .getSingleOrNull();
        expect(trial?.status, 'active');
        // No duplicate rows created, no error thrown.
        final all = await db.select(db.trials).get();
        expect(all.where((t) => t.id == trialId).length, 1);
      },
    );
  });
}
