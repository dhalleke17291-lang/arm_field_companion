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

    expect(db.schemaVersion, 74);

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
    // 3 null-region (EPPO/GLP) + 5 pmra_canada profiles.
    expect(causal.length, 8);
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
}
