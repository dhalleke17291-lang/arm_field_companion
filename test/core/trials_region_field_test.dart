import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void _setUserVersion(String path, int version) {
  final raw = sqlite.sqlite3.open(path);
  try {
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.dispose();
  }
}

void main() {
  group('Trials.region field', () {
    test('new trial without region defaults to eppo_eu', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final id = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'Default Region'));

      final row =
          await (db.select(db.trials)..where((t) => t.id.equals(id))).getSingle();
      expect(row.region, 'eppo_eu');
    });

    test('explicit region value is stored correctly', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final id = await db.into(db.trials).insert(TrialsCompanion.insert(
            name: 'Canada Trial',
            region: const Value('pmra_canada'),
          ));

      final row =
          await (db.select(db.trials)..where((t) => t.id.equals(id))).getSingle();
      expect(row.region, 'pmra_canada');
    });

    test('region is open text — arbitrary value accepted without error',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final id = await db.into(db.trials).insert(TrialsCompanion.insert(
            name: 'Future Region',
            region: const Value('zz_custom_2030'),
          ));

      final row =
          await (db.select(db.trials)..where((t) => t.id.equals(id))).getSingle();
      expect(row.region, 'zz_custom_2030');
    });
  });

  group('Trials.region migration (72 → 73)', () {
    late Directory root;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      root = await Directory.systemTemp.createTemp('trials_region_migration_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
        '72 → 73: existing trial without region column gets eppo_eu after upgrade',
        () async {
      final dbFile = File(p.join(root.path, 'upgrade_72_to_73.db'));

      // Bring DB to current schema, insert a trial, then simulate v72 by
      // dropping the region column and resetting user_version.
      var db =
          AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'Pre-migration Trial'));
      // Touch the DB to ensure the file is flushed.
      await (db.select(db.trials)..where((t) => t.id.equals(trialId))).getSingle();
      await db.close();

      // Remove region column and reset version to 72.
      final raw = sqlite.sqlite3.open(dbFile.path);
      try {
        raw.execute('ALTER TABLE trials DROP COLUMN region');
        raw.execute('PRAGMA user_version = 72');
      } finally {
        raw.dispose();
      }

      // Reopen — Drift runs onUpgrade(72 → 73) and adds region = 'eppo_eu'.
      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      final row = await (db.select(db.trials)
            ..where((t) => t.id.equals(trialId)))
          .getSingle();
      expect(row.region, 'eppo_eu',
          reason: 'migration must backfill existing rows to eppo_eu');

      // Column must be present (idempotency: re-running would skip addColumn).
      final cols = await db
          .customSelect("SELECT name FROM pragma_table_info('trials')")
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
      expect(cols, contains('region'));
    });

    test('72 → 73 idempotent when region column already present', () async {
      final dbFile = File(p.join(root.path, 'upgrade_idempotent.db'));

      var db =
          AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      // Touch DB.
      await db.select(db.trials).get();
      await db.close();

      // Reset version without dropping the column.
      _setUserVersion(dbFile.path, 72);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      // Should open without error and region column must still exist.
      final cols = await db
          .customSelect("SELECT name FROM pragma_table_info('trials')")
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
      expect(cols, contains('region'));
    });
  });
}
