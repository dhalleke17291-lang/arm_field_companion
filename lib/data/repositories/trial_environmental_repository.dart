import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../services/weather_daily_fetch_service.dart';

class TrialEnvironmentalRepository {
  TrialEnvironmentalRepository(this._db, this._weatherFetch);

  final AppDatabase _db;
  final WeatherDailyFetchService _weatherFetch;

  Future<void> upsertDailyRecord(TrialEnvironmentalRecord record) async {
    final companion = TrialEnvironmentalRecordsCompanion(
      trialId: Value(record.trialId),
      recordDate: Value(record.recordDate),
      siteLatitude: Value(record.siteLatitude),
      siteLongitude: Value(record.siteLongitude),
      dailyMinTempC: Value(record.dailyMinTempC),
      dailyMaxTempC: Value(record.dailyMaxTempC),
      dailyPrecipitationMm: Value(record.dailyPrecipitationMm),
      weatherFlags: Value(record.weatherFlags),
      dataSource: Value(record.dataSource),
      fetchedAt: Value(record.fetchedAt),
      confidence: Value(record.confidence),
    );
    await _db.into(_db.trialEnvironmentalRecords).insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [
              _db.trialEnvironmentalRecords.trialId,
              _db.trialEnvironmentalRecords.recordDate,
            ],
          ),
        );
  }

  Future<List<TrialEnvironmentalRecord>> getRecordsForTrial(
      int trialId) {
    return (_db.select(_db.trialEnvironmentalRecords)
          ..where((r) => r.trialId.equals(trialId))
          ..orderBy([(r) => OrderingTerm.asc(r.recordDate)]))
        .get();
  }

  Future<TrialEnvironmentalRecord?> getRecordForDate(
      int trialId, DateTime date) {
    final dayMs = _dayStartMs(date);
    return (_db.select(_db.trialEnvironmentalRecords)
          ..where((r) =>
              r.trialId.equals(trialId) & r.recordDate.equals(dayMs)))
        .getSingleOrNull();
  }

  /// Checks whether today's record exists for [trialId].
  /// If not, fetches from Open-Meteo daily API and inserts.
  /// On fetch failure, inserts a record with confidence='unavailable'
  /// and all weather fields null — the gap is itself information.
  Future<void> ensureTodayRecordExists(
    int trialId,
    double lat,
    double lng,
  ) async {
    final todayMs = _dayStartMs(DateTime.now());
    final existing = await (_db.select(_db.trialEnvironmentalRecords)
          ..where((r) =>
              r.trialId.equals(trialId) & r.recordDate.equals(todayMs)))
        .getSingleOrNull();

    if (existing != null) return;

    final fetchedMs = DateTime.now().millisecondsSinceEpoch;
    final result =
        await _weatherFetch.fetchDailySummary(lat, lng, DateTime.now());

    final flags = _computeFlags(
      minTempC: result?.minTempC,
      maxTempC: result?.maxTempC,
      precipMm: result?.precipMm,
    );

    await _db.into(_db.trialEnvironmentalRecords).insert(
          TrialEnvironmentalRecordsCompanion.insert(
            trialId: trialId,
            recordDate: todayMs,
            siteLatitude: lat,
            siteLongitude: lng,
            dailyMinTempC: Value(result?.minTempC),
            dailyMaxTempC: Value(result?.maxTempC),
            dailyPrecipitationMm: Value(result?.precipMm),
            weatherFlags: Value(flags.isEmpty ? null : jsonEncode(flags)),
            dataSource: result != null ? 'open_meteo' : 'unavailable',
            fetchedAt: fetchedMs,
            confidence: Value(result != null ? 'measured' : 'unavailable'),
          ),
        );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// UTC midnight milliseconds for the calendar day containing [date].
  static int _dayStartMs(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day)
        .millisecondsSinceEpoch;
  }

  /// Returns a list of flag strings for notable weather events.
  static List<String> _computeFlags({
    double? minTempC,
    double? maxTempC,
    double? precipMm,
  }) {
    final flags = <String>[];
    if (minTempC != null && minTempC < 0) flags.add('frost');
    if (maxTempC != null && maxTempC > 35) flags.add('heat');
    if (precipMm != null && precipMm >= 10) flags.add('excessive_rainfall');
    return flags;
  }
}
