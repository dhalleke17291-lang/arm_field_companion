import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'weather_daily_fetch_service.dart';
import 'weather_daily_summary.dart';

class OpenMeteoWeatherFetchService implements WeatherDailyFetchService {
  OpenMeteoWeatherFetchService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<WeatherDailySummary?> fetchDailySummary(
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
        '&temperature_unit=celsius'
        '&wind_speed_unit=kmh'
        '&precipitation_unit=mm'
        '&timezone=auto'
        '&start_date=$dateStr&end_date=$dateStr',
      );

      final response =
          await _client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final mins = daily['temperature_2m_min'] as List?;
      final maxs = daily['temperature_2m_max'] as List?;
      final precips = daily['precipitation_sum'] as List?;

      return WeatherDailySummary(
        minTempC:
            (mins?.isNotEmpty == true) ? (mins![0] as num?)?.toDouble() : null,
        maxTempC:
            (maxs?.isNotEmpty == true) ? (maxs![0] as num?)?.toDouble() : null,
        precipMm: (precips?.isNotEmpty == true)
            ? (precips![0] as num?)?.toDouble()
            : null,
      );
    } catch (e) {
      debugPrint('OpenMeteoWeatherFetchService: fetch failed — $e');
      return null;
    }
  }

  @override
  Future<List<WeatherDailyRecord>> fetchDailyRange(
    double lat,
    double lng,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final start = _isoDate(startDate);
      final end = _isoDate(endDate);
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&daily=temperature_2m_min,temperature_2m_max,precipitation_sum'
        '&temperature_unit=celsius'
        '&wind_speed_unit=kmh'
        '&precipitation_unit=mm'
        '&timezone=auto'
        '&start_date=$start&end_date=$end',
      );

      final response =
          await _client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return const [];

      final dates = (daily['time'] as List?)?.cast<String>() ?? const [];
      final mins = daily['temperature_2m_min'] as List?;
      final maxs = daily['temperature_2m_max'] as List?;
      final precips = daily['precipitation_sum'] as List?;

      final results = <WeatherDailyRecord>[];
      for (var i = 0; i < dates.length; i++) {
        results.add(
          WeatherDailyRecord(
            date: DateTime.parse(dates[i]),
            minTempC: _numAt(mins, i),
            maxTempC: _numAt(maxs, i),
            precipMm: _numAt(precips, i),
          ),
        );
      }
      return results;
    } catch (e) {
      debugPrint('OpenMeteoWeatherFetchService: range fetch failed — $e');
      return const [];
    }
  }

  /// UTC calendar date as `yyyy-MM-dd` for [date].
  static String _isoDate(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static double? _numAt(List? values, int index) {
    if (values == null || index >= values.length) return null;
    return (values[index] as num?)?.toDouble();
  }
}
