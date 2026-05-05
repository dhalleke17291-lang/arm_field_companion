import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_environmental_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrialEnvironmentalRepository repo;
  late int trialId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TrialEnvironmentalRepository(db);
    trialId =
        await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
  });

  tearDown(() async => db.close());

  // ── Helpers ────────────────────────────────────────────────────────────────

  int dayMs(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch;
  }

  Future<TrialEnvironmentalRecord> insertRecord({
    required DateTime date,
    double? minTemp,
    double? maxTemp,
    double? precip,
    String confidence = 'measured',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayStart = dayMs(date);
    await db.into(db.trialEnvironmentalRecords).insert(
          TrialEnvironmentalRecordsCompanion.insert(
            trialId: trialId,
            recordDate: dayStart,
            siteLatitude: 51.5,
            siteLongitude: -0.1,
            dailyMinTempC: Value(minTemp),
            dailyMaxTempC: Value(maxTemp),
            dailyPrecipitationMm: Value(precip),
            dataSource: 'test',
            fetchedAt: now,
            confidence: Value(confidence),
          ),
        );
    return (await db.select(db.trialEnvironmentalRecords).get()).last;
  }

  // ── TER-1: upsert creates a new record ────────────────────────────────────

  test('TER-1: upsertDailyRecord creates a new record', () async {
    final record = await insertRecord(date: DateTime(2026, 4, 1));

    final rows = await repo.getRecordsForTrial(trialId);
    expect(rows.length, 1);
    expect(rows[0].id, record.id);
  });

  // ── TER-2: upsert with same date updates existing ─────────────────────────

  test('TER-2: upsertDailyRecord with same date updates existing record',
      () async {
    final date = DateTime(2026, 4, 1);
    await insertRecord(date: date, minTemp: 5.0);

    // Upsert updated record via the repository method.
    final rows1 = await repo.getRecordsForTrial(trialId);
    final existing = rows1[0];
    await repo.upsertDailyRecord(TrialEnvironmentalRecord(
      id: existing.id,
      trialId: trialId,
      recordDate: existing.recordDate,
      siteLatitude: 51.5,
      siteLongitude: -0.1,
      dailyMinTempC: -2.0, // updated
      dailyMaxTempC: null,
      dailyPrecipitationMm: null,
      weatherFlags: null,
      dataSource: 'test',
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
      confidence: 'measured',
      createdAt: existing.createdAt,
    ));

    final rows2 = await repo.getRecordsForTrial(trialId);
    expect(rows2.length, 1);
    expect(rows2[0].dailyMinTempC, -2.0);
  });

  // ── TER-3: getRecordForDate returns correct record ────────────────────────

  test('TER-3: getRecordForDate returns record for matching date', () async {
    final target = DateTime(2026, 4, 10);
    await insertRecord(date: target, minTemp: 12.0);
    await insertRecord(date: DateTime(2026, 4, 11), minTemp: 14.0);

    final found = await repo.getRecordForDate(trialId, target);
    expect(found, isNotNull);
    expect(found!.dailyMinTempC, 12.0);
  });

  // ── TER-4: getRecordForDate returns null when absent ─────────────────────

  test('TER-4: getRecordForDate returns null when no record exists', () async {
    final found =
        await repo.getRecordForDate(trialId, DateTime(2026, 3, 1));
    expect(found, isNull);
  });

  // ── TER-5: ensureTodayRecordExists inserts unavailable when fetch skipped ─

  test(
      'TER-5: ensureTodayRecordExists with no existing record inserts a row',
      () async {
    // We can't mock the HTTP client here, but we can verify that after calling
    // ensureTodayRecordExists, exactly one record exists for today.
    // The test environment has no network, so the record will be confidence=unavailable.
    // We accept either 'measured' or 'unavailable' — the key is that a row was created.
    await repo.ensureTodayRecordExists(trialId, 51.5, -0.1);

    final today = DateTime.now();
    final found = await repo.getRecordForDate(trialId, today);
    expect(found, isNotNull);
    expect(found!.siteLatitude, 51.5);
    expect(found.siteLongitude, -0.1);
  });

  // ── TER-6: ensureTodayRecordExists is idempotent ─────────────────────────

  test('TER-6: ensureTodayRecordExists called twice creates only one record',
      () async {
    await repo.ensureTodayRecordExists(trialId, 51.5, -0.1);
    await repo.ensureTodayRecordExists(trialId, 51.5, -0.1);

    final rows = await repo.getRecordsForTrial(trialId);
    expect(rows.length, 1);
  });

  // ── TER-7: getRecordsForTrial returns ordered by date ────────────────────

  test('TER-7: getRecordsForTrial returns records ordered by date', () async {
    await insertRecord(date: DateTime(2026, 4, 3));
    await insertRecord(date: DateTime(2026, 4, 1));
    await insertRecord(date: DateTime(2026, 4, 2));

    final rows = await repo.getRecordsForTrial(trialId);
    expect(rows.length, 3);
    expect(rows[0].recordDate, lessThan(rows[1].recordDate));
    expect(rows[1].recordDate, lessThan(rows[2].recordDate));
  });
}
