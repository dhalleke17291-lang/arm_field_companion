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
  group('SeTypeCausalProfiles.region / windowType fields', () {
    test('seeded profiles have NULL region and bbch windowType', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final rows = await db.select(db.seTypeCausalProfiles).get();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row.region, isNull,
            reason: 'seed rows must have NULL region (applies to any region)');
        expect(row.windowType, 'bbch',
            reason: 'seed rows must default to bbch window type');
      }
    });

    test('new profile with NULL region and explicit windowType is stored', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.into(db.seTypeCausalProfiles).insert(
            SeTypeCausalProfilesCompanion.insert(
              seType: 'TESTSE',
              trialType: 'efficacy',
              causalWindowDaysMin: 5,
              causalWindowDaysMax: 14,
              expectedResponseDirection: 'increase',
              source: 'test',
              windowType: const Value('gdd'),
              createdAt: now,
            ),
          );

      final row = await (db.select(db.seTypeCausalProfiles)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.region, isNull);
      expect(row.windowType, 'gdd');
    });

    test('region accepts arbitrary text', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.into(db.seTypeCausalProfiles).insert(
            SeTypeCausalProfilesCompanion.insert(
              seType: 'TESTSE',
              trialType: 'efficacy',
              causalWindowDaysMin: 5,
              causalWindowDaysMax: 14,
              expectedResponseDirection: 'increase',
              source: 'test',
              region: const Value('pmra_canada'),
              createdAt: now,
            ),
          );

      final row = await (db.select(db.seTypeCausalProfiles)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.region, 'pmra_canada');
    });

    test('windowType accepts arbitrary text', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await db.into(db.seTypeCausalProfiles).insert(
            SeTypeCausalProfilesCompanion.insert(
              seType: 'TESTSE',
              trialType: 'efficacy',
              causalWindowDaysMin: 5,
              causalWindowDaysMax: 14,
              expectedResponseDirection: 'increase',
              source: 'test',
              windowType: const Value('cdd_custom_2030'),
              createdAt: now,
            ),
          );

      final row = await (db.select(db.seTypeCausalProfiles)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.windowType, 'cdd_custom_2030');
    });

    test(
        'unique key allows same {seType, trialType} with different regions '
        '(NULL vs pmra_canada)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      // NULL region row (region-agnostic profile).
      await db.into(db.seTypeCausalProfiles).insert(
            SeTypeCausalProfilesCompanion.insert(
              seType: 'CONTRO',
              trialType: 'variety',
              causalWindowDaysMin: 7,
              causalWindowDaysMax: 21,
              expectedResponseDirection: 'increase',
              source: 'test',
              createdAt: now,
            ),
          );
      // Canada-specific profile — same seType × trialType, different region.
      await expectLater(
        db.into(db.seTypeCausalProfiles).insert(
              SeTypeCausalProfilesCompanion.insert(
                seType: 'CONTRO',
                trialType: 'variety',
                causalWindowDaysMin: 250,
                causalWindowDaysMax: 600,
                expectedResponseDirection: 'increase',
                source: 'PMRA',
                region: const Value('pmra_canada'),
                windowType: const Value('gdd'),
                createdAt: now,
              ),
            ),
        completes,
        reason: 'distinct region must not conflict with NULL-region row',
      );

      final rows = await (db.select(db.seTypeCausalProfiles)
            ..where((t) => t.seType.equals('CONTRO'))
            ..where((t) => t.trialType.equals('variety')))
          .get();
      expect(rows.length, 2);
    });

    test('unique key prevents duplicate {seType, trialType, region}', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.seTypeCausalProfiles).insert(
            SeTypeCausalProfilesCompanion.insert(
              seType: 'CONTRO',
              trialType: 'variety',
              causalWindowDaysMin: 250,
              causalWindowDaysMax: 600,
              expectedResponseDirection: 'increase',
              source: 'PMRA',
              region: const Value('pmra_canada'),
              windowType: const Value('gdd'),
              createdAt: now,
            ),
          );

      await expectLater(
        db.into(db.seTypeCausalProfiles).insert(
              SeTypeCausalProfilesCompanion.insert(
                seType: 'CONTRO',
                trialType: 'variety',
                causalWindowDaysMin: 260,
                causalWindowDaysMax: 620,
                expectedResponseDirection: 'increase',
                source: 'PMRA',
                region: const Value('pmra_canada'),
                windowType: const Value('gdd'),
                createdAt: now,
              ),
            ),
        throwsA(anything),
        reason: 'same {seType, trialType, region} must be rejected',
      );
    });
  });

  group('SeTypeCausalProfiles migration (73 → 74)', () {
    late Directory root;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      root = await Directory.systemTemp.createTemp('causal_profiles_region_migration_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('73 → 74 idempotent when columns already present', () async {
      final dbFile = File(p.join(root.path, 'upgrade_idempotent.db'));

      var db =
          AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      // Touch the DB so the file is flushed at v74.
      await db.select(db.seTypeCausalProfiles).get();
      await db.close();

      // Reset version without dropping the new columns.
      _setUserVersion(dbFile.path, 73);

      db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
      addTearDown(db.close);

      // Should open without error; columns must still be present.
      final cols = await db
          .customSelect(
              "SELECT name FROM pragma_table_info('se_type_causal_profiles')")
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
      expect(cols, containsAll({'region', 'window_type'}));

      // Seed data must still be intact.
      final causal = await db.select(db.seTypeCausalProfiles).get();
      expect(causal.length, 3);
    });
  });
}
