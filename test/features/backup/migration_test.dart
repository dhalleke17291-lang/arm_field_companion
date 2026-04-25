// Defensive v49 migration tests. Temp dir + file-backed NativeDatabase matches
// `backup_service_test.dart` (disk DB under a temp `docs` folder).
//
// A brand-new SQLite file with only `PRAGMA user_version = 36` cannot run 36→49
// because intermediate migrations expect tables from earlier versions. The
// "missing application_* tables" scenario is exercised at user_version 48
// (only `if (from < 49)` runs) after dropping those three tables.

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

  test('onCreate: all legacy application tables exist on fresh install', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 68);

    final names = await _tableNames(db);
    expect(names, contains(_kApplicationSlots));
    expect(names, contains(_kApplicationEvents));
    expect(names, contains(_kApplicationPlotRecords));
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
}
