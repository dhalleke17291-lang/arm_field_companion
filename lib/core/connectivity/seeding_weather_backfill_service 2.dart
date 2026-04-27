import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/seeding_repository.dart';
import 'connectivity_service.dart';
import 'weather_api_service.dart';

const Duration _kSeedingWindow = Duration(days: 7);
const int _kSeedingMaxRetries = 3;

class _SeedingWeatherTask {
  const _SeedingWeatherTask({
    required this.tag,
    required this.seedingEventId,
    required this.trialId,
    required this.latitude,
    required this.longitude,
    required this.completedAt,
    this.retryCount = 0,
    this.createdAt,
  });

  final String tag;
  final String seedingEventId;
  final int trialId;
  final double latitude;
  final double longitude;
  final DateTime completedAt;
  final int retryCount;
  final DateTime? createdAt;

  bool get isExpired =>
      DateTime.now().difference(completedAt) > _kSeedingWindow;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'seedingEventId': seedingEventId,
        'trialId': trialId,
        'latitude': latitude,
        'longitude': longitude,
        'completedAt': completedAt.toIso8601String(),
        'retryCount': retryCount,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory _SeedingWeatherTask.fromJson(Map<String, dynamic> json) =>
      _SeedingWeatherTask(
        tag: json['tag'] as String,
        seedingEventId: json['seedingEventId'] as String,
        trialId: json['trialId'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        completedAt: DateTime.parse(json['completedAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  _SeedingWeatherTask withRetry() => _SeedingWeatherTask(
        tag: tag,
        seedingEventId: seedingEventId,
        trialId: trialId,
        latitude: latitude,
        longitude: longitude,
        completedAt: completedAt,
        retryCount: retryCount + 1,
        createdAt: createdAt,
      );
}

/// Queues archive-API weather backfill for completed seeding events.
/// Separate key from session and application backfill queues.
class SeedingWeatherBackfillService {
  SeedingWeatherBackfillService({
    required this.connectivityService,
    required this.seedingRepository,
  });

  final ConnectivityService connectivityService;
  final SeedingRepository seedingRepository;

  static const String _kKey = 'seeding_weather_backfill_pending';

  Future<void> queueSeedingWeatherBackfill({
    required String seedingEventId,
    required int trialId,
    required double latitude,
    required double longitude,
    required DateTime completedAt,
  }) async {
    final tag = 'seeding_weather_backfill_$seedingEventId';
    final task = _SeedingWeatherTask(
      tag: tag,
      seedingEventId: seedingEventId,
      trialId: trialId,
      latitude: latitude,
      longitude: longitude,
      completedAt: completedAt,
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

  Future<void> _execute(_SeedingWeatherTask task) async {
    if (task.isExpired) {
      await _remove(task.tag);
      return;
    }

    final result = await _fetchHistorical(
      latitude: task.latitude,
      longitude: task.longitude,
      date: task.completedAt,
    );

    if (result == null) {
      final updated = task.withRetry();
      if (updated.retryCount >= _kSeedingMaxRetries) {
        await _remove(task.tag);
        return;
      }
      await _persist(updated);
      throw Exception('Seeding weather backfill failed, will retry');
    }

    await seedingRepository.updateSeedingWeather(
      seedingEventId: task.seedingEventId,
      temperatureC: result.temperatureC,
      humidityPct: result.humidityPct,
      windSpeedKmh: result.windSpeedKmh,
      windDirection: result.windDirection,
      cloudCoverPct: result.cloudCoverPct,
      precipitation: result.precipitation,
      precipitationMm: null,
      soilMoisture: null,
      soilTemperature: null,
    );

    await _remove(task.tag);
    debugPrint('SeedingWeatherBackfill: completed ${task.tag}');
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

  Future<List<_SeedingWeatherTask>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => _SeedingWeatherTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(_SeedingWeatherTask task) async {
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
