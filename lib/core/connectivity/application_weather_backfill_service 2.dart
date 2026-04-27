import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/application_repository.dart';
import 'connectivity_service.dart';
import 'weather_api_service.dart';

const Duration _kWindow = Duration(days: 7);
const int _kMaxRetries = 3;

class _AppWeatherTask {
  const _AppWeatherTask({
    required this.tag,
    required this.applicationId,
    required this.trialId,
    required this.latitude,
    required this.longitude,
    required this.appliedAt,
    this.retryCount = 0,
    this.createdAt,
  });

  final String tag;
  final String applicationId;
  final int trialId;
  final double latitude;
  final double longitude;
  final DateTime appliedAt;
  final int retryCount;
  final DateTime? createdAt;

  bool get isExpired => DateTime.now().difference(appliedAt) > _kWindow;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'applicationId': applicationId,
        'trialId': trialId,
        'latitude': latitude,
        'longitude': longitude,
        'appliedAt': appliedAt.toIso8601String(),
        'retryCount': retryCount,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory _AppWeatherTask.fromJson(Map<String, dynamic> json) =>
      _AppWeatherTask(
        tag: json['tag'] as String,
        applicationId: json['applicationId'] as String,
        trialId: json['trialId'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        appliedAt: DateTime.parse(json['appliedAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  _AppWeatherTask withRetry() => _AppWeatherTask(
        tag: tag,
        applicationId: applicationId,
        trialId: trialId,
        latitude: latitude,
        longitude: longitude,
        appliedAt: appliedAt,
        retryCount: retryCount + 1,
        createdAt: createdAt,
      );
}

/// Queues archive-API weather backfill for confirmed application events.
/// Separate from [WeatherBackfillService] because applications use TEXT UUID
/// PKs, incompatible with the session-centric queueBackfill (INT FK).
class ApplicationWeatherBackfillService {
  ApplicationWeatherBackfillService({
    required this.connectivityService,
    required this.applicationRepository,
  });

  final ConnectivityService connectivityService;
  final ApplicationRepository applicationRepository;

  static const String _kKey = 'app_weather_backfill_pending';

  Future<void> queueApplicationWeatherBackfill({
    required String applicationId,
    required int trialId,
    required double latitude,
    required double longitude,
    required DateTime appliedAt,
  }) async {
    final tag = 'app_weather_backfill_$applicationId';
    final task = _AppWeatherTask(
      tag: tag,
      applicationId: applicationId,
      trialId: trialId,
      latitude: latitude,
      longitude: longitude,
      appliedAt: appliedAt,
      createdAt: DateTime.now(),
    );
    await _persist(task);
    connectivityService.executeWhenOnline(
      tag: tag,
      task: () => _execute(task),
    );
  }

  /// Re-register persisted tasks at app startup.
  Future<void> loadPendingTasks() async {
    final tasks = await _load();
    for (final task in tasks) {
      if (task.isExpired) {
        await _remove(task.tag);
        continue;
      }
      connectivityService.executeWhenOnline(
        tag: task.tag,
        task: () => _execute(task),
      );
    }
  }

  Future<void> _execute(_AppWeatherTask task) async {
    if (task.isExpired) {
      await _remove(task.tag);
      return;
    }

    final result = await _fetchHistorical(
      latitude: task.latitude,
      longitude: task.longitude,
      date: task.appliedAt,
    );

    if (result == null) {
      final updated = task.withRetry();
      if (updated.retryCount >= _kMaxRetries) {
        await _remove(task.tag);
        return;
      }
      await _persist(updated);
      throw Exception('Application weather backfill failed, will retry');
    }

    await applicationRepository.updateApplicationWeather(
      applicationId: task.applicationId,
      temperatureC: result.temperatureC,
      humidityPct: result.humidityPct,
      windSpeedKmh: result.windSpeedKmh,
      windDirection: result.windDirection,
      cloudCoverPct: result.cloudCoverPct,
      precipitation: result.precipitation,
      precipitationMm: null,
    );

    await _remove(task.tag);
    debugPrint('ApplicationWeatherBackfill: completed ${task.tag}');
  }

  Future<WeatherApiResult?> _fetchHistorical({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hour = date.toUtc().hour;

      final url = Uri.parse(
        'https://archive-api.open-meteo.com/v1/archive'
        '?latitude=$latitude&longitude=$longitude'
        '&start_date=$dateStr&end_date=$dateStr'
        '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,'
        'wind_direction_10m,cloud_cover,precipitation'
        '&wind_speed_unit=kmh&temperature_unit=celsius',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return null;

      final temps = hourly['temperature_2m'] as List?;
      final humids = hourly['relative_humidity_2m'] as List?;
      final winds = hourly['wind_speed_10m'] as List?;
      final windDirs = hourly['wind_direction_10m'] as List?;
      final clouds = hourly['cloud_cover'] as List?;
      final precips = hourly['precipitation'] as List?;

      final idx = hour.clamp(0, (temps?.length ?? 24) - 1);

      return WeatherApiResult(
        temperatureC: (temps?[idx] as num?)?.toDouble() ?? 0,
        humidityPct: (humids?[idx] as num?)?.toDouble() ?? 0,
        windSpeedKmh: (winds?[idx] as num?)?.toDouble() ?? 0,
        windDirection: windDirs != null && idx < windDirs.length
            ? _degreesToCompass((windDirs[idx] as num).toDouble())
            : null,
        cloudCoverPct: (clouds?[idx] as num?)?.toDouble(),
        precipitation: precips != null && idx < precips.length
            ? _describePrecipitation((precips[idx] as num?)?.toDouble())
            : null,
        providerName: 'Open-Meteo',
      );
    } catch (_) {
      return null;
    }
  }

  // --- Persistence ---

  Future<List<_AppWeatherTask>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _AppWeatherTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(_AppWeatherTask task) async {
    final tasks = await _load();
    tasks.removeWhere((t) => t.tag == task.tag);
    tasks.add(task);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _remove(String tag) async {
    final tasks = await _load();
    tasks.removeWhere((t) => t.tag == tag);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }
}

String _degreesToCompass(double degrees) {
  const directions = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];
  final index = ((degrees + 11.25) / 22.5).floor() % 16;
  return directions[index];
}

String? _describePrecipitation(double? mm) {
  if (mm == null || mm <= 0) return null;
  if (mm < 0.5) return 'Trace';
  if (mm < 2.5) return 'Light rain';
  if (mm < 7.5) return 'Moderate rain';
  return 'Heavy rain';
}
