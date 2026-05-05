import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/database/app_database.dart';

class TrialEnvironmentalRepository {
  TrialEnvironmentalRepository(this._db);

  final AppDatabase _db;

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
    final result = await _fetchDailyRecord(lat, lng, DateTime.now());

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

  static String _isoDate(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  Future<_DailyWeatherResult?> _fetchDailyRecord(
    double lat,
    double lng,
    DateTime date,
  ) async {
    try {
      final dateStr = _isoDate(date);
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&daily=temperature_2m_min,temperature_2m_max,precipitation_sum'
        '&timezone=UTC'
        '&start_date=$dateStr&end_date=$dateStr',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final mins = daily['temperature_2m_min'] as List?;
      final maxs = daily['temperature_2m_max'] as List?;
      final precips = daily['precipitation_sum'] as List?;

      return _DailyWeatherResult(
        minTempC: (mins?.isNotEmpty == true)
            ? (mins![0] as num?)?.toDouble()
            : null,
        maxTempC: (maxs?.isNotEmpty == true)
            ? (maxs![0] as num?)?.toDouble()
            : null,
        precipMm: (precips?.isNotEmpty == true)
            ? (precips![0] as num?)?.toDouble()
            : null,
      );
    } catch (e) {
      debugPrint('TrialEnvironmentalRepository: fetch failed — $e');
      return null;
    }
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

class _DailyWeatherResult {
  const _DailyWeatherResult({
    this.minTempC,
    this.maxTempC,
    this.precipMm,
  });

  final double? minTempC;
  final double? maxTempC;
  final double? precipMm;
}
