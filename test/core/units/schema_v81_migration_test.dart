import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables: [Variable.withString(table)],
  ).get();
  return rows.isNotEmpty;
}

void main() {
  group('Schema v81 migration — trial_environmental_records', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('trial_environmental_records table exists', () async {
      expect(await _tableExists(db, 'trial_environmental_records'), isTrue);
    });

    test('trial_environmental_records has all required columns', () async {
      final cols = await _columnNames(db, 'trial_environmental_records');
      expect(
          cols,
          containsAll([
            'id',
            'trial_id',
            'record_date',
            'site_latitude',
            'site_longitude',
            'daily_min_temp_c',
            'daily_max_temp_c',
            'daily_precipitation_mm',
            'weather_flags',
            'data_source',
            'fetched_at',
            'confidence',
            'created_at',
          ]));
    });

    test('temperature and precipitation columns are nullable', () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert without optional weather fields — should succeed.
      await db.into(db.trialEnvironmentalRecords).insert(
            TrialEnvironmentalRecordsCompanion.insert(
              trialId: trialId,
              recordDate: now,
              siteLatitude: 51.5,
              siteLongitude: -0.1,
              dataSource: 'open_meteo',
              fetchedAt: now,
            ),
          );
      final rows = await db.select(db.trialEnvironmentalRecords).get();
      expect(rows.length, 1);
      expect(rows[0].dailyMinTempC, isNull);
      expect(rows[0].dailyMaxTempC, isNull);
      expect(rows[0].dailyPrecipitationMm, isNull);
      expect(rows[0].weatherFlags, isNull);
    });

    test('confidence defaults to measured', () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.trialEnvironmentalRecords).insert(
            TrialEnvironmentalRecordsCompanion.insert(
              trialId: trialId,
              recordDate: now,
              siteLatitude: 51.5,
              siteLongitude: -0.1,
              dataSource: 'open_meteo',
              fetchedAt: now,
            ),
          );
      final rows = await db.select(db.trialEnvironmentalRecords).get();
      expect(rows[0].confidence, 'measured');
    });

    test('UNIQUE(trial_id, record_date) prevents duplicate daily records',
        () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.trialEnvironmentalRecords).insert(
            TrialEnvironmentalRecordsCompanion.insert(
              trialId: trialId,
              recordDate: now,
              siteLatitude: 51.5,
              siteLongitude: -0.1,
              dataSource: 'open_meteo',
              fetchedAt: now,
            ),
          );

      // Second insert for same trial + date must throw.
      await expectLater(
        () => db.into(db.trialEnvironmentalRecords).insert(
              TrialEnvironmentalRecordsCompanion.insert(
                trialId: trialId,
                recordDate: now,
                siteLatitude: 51.5,
                siteLongitude: -0.1,
                dataSource: 'open_meteo',
                fetchedAt: now,
              ),
            ),
        throwsA(anything),
      );
    });

    test('different trials may share the same record_date', () async {
      final t1 =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T1'));
      final t2 =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T2'));
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.into(db.trialEnvironmentalRecords).insert(
            TrialEnvironmentalRecordsCompanion.insert(
              trialId: t1,
              recordDate: now,
              siteLatitude: 51.5,
              siteLongitude: -0.1,
              dataSource: 'open_meteo',
              fetchedAt: now,
            ),
          );
      await db.into(db.trialEnvironmentalRecords).insert(
            TrialEnvironmentalRecordsCompanion.insert(
              trialId: t2,
              recordDate: now,
              siteLatitude: 48.8,
              siteLongitude: 2.3,
              dataSource: 'open_meteo',
              fetchedAt: now,
            ),
          );

      final rows = await db.select(db.trialEnvironmentalRecords).get();
      expect(rows.length, 2);
    });
  });

  group('precipitation_mm migration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schema v83 adds precipitationMm column to weather_snapshots',
        () async {
      final cols = await _columnNames(db, 'weather_snapshots');

      expect(cols, contains('precipitation_mm'));
    });
  });
}
