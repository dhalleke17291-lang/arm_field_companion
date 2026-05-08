import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/weather_snapshot_repository.dart';
import '../diagnostics/diagnostics_store.dart';
import 'connectivity_service.dart';
import 'weather_api_service.dart';

/// Maximum age of a backfill task before it expires.
const Duration kBackfillWindow = Duration(days: 7);

/// Maximum retry attempts before giving up.
const int kMaxBackfillRetries = 3;

/// A pending weather backfill request, serializable for persistence.
class BackfillTask {
  const BackfillTask({
    required this.tag,
    required this.latitude,
    required this.longitude,
    required this.eventTimestamp,
    required this.parentType,
    required this.parentId,
    required this.trialId,
    this.retryCount = 0,
    this.createdAt,
  });

  final String tag;
  final double latitude;
  final double longitude;
  final DateTime eventTimestamp;
  final String parentType;
  final int parentId;
  final int trialId;
  final int retryCount;
  final DateTime? createdAt;

  bool get isExpired =>
      DateTime.now().difference(eventTimestamp) > kBackfillWindow;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'latitude': latitude,
        'longitude': longitude,
        'eventTimestamp': eventTimestamp.toIso8601String(),
        'parentType': parentType,
        'parentId': parentId,
        'trialId': trialId,
        'retryCount': retryCount,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory BackfillTask.fromJson(Map<String, dynamic> json) => BackfillTask(
        tag: json['tag'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        eventTimestamp: DateTime.parse(json['eventTimestamp'] as String),
        parentType: json['parentType'] as String,
        parentId: json['parentId'] as int,
        trialId: json['trialId'] as int,
        retryCount: json['retryCount'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// Manages offline weather backfill. Queues tasks when offline,
/// executes them when connectivity returns via [ConnectivityService].
class WeatherBackfillService {
  WeatherBackfillService({
    required this.connectivityService,
    required this.weatherRepo,
    required this.diagnosticsStore,
  });

  final ConnectivityService connectivityService;
  final WeatherSnapshotRepository weatherRepo;
  final DiagnosticsStore diagnosticsStore;

  static const String _kPendingTasksKey = 'weather_backfill_pending';

  /// Queue a weather backfill for a record that was saved offline.
  Future<void> queueBackfill({
    required double latitude,
    required double longitude,
    required DateTime eventTimestamp,
    required String parentType,
    required int parentId,
    required int trialId,
  }) async {
    final tag = 'weather_backfill_${parentId}_$parentType';
    final task = BackfillTask(
      tag: tag,
      latitude: latitude,
      longitude: longitude,
      eventTimestamp: eventTimestamp,
      parentType: parentType,
      parentId: parentId,
      trialId: trialId,
      createdAt: DateTime.now(),
    );

    await _persistTask(task);

    connectivityService.executeWhenOnline(
      tag: tag,
      task: () => _executeBackfill(task),
    );
  }

  /// Load persisted tasks and re-register with connectivity service.
  /// Call at app startup.
  Future<void> loadPendingTasks() async {
    final tasks = await _loadTasks();
    for (final task in tasks) {
      if (task.isExpired) {
        await _expireTask(task);
        continue;
      }
      connectivityService.executeWhenOnline(
        tag: task.tag,
        task: () => _executeBackfill(task),
      );
    }
  }

  /// Number of pending backfill tasks.
  Future<int> get pendingCount async {
    final tasks = await _loadTasks();
    return tasks.where((t) => !t.isExpired).length;
  }

  Future<void> _executeBackfill(BackfillTask task) async {
    if (task.isExpired) {
      await _expireTask(task);
      return;
    }

    // Check if weather was manually entered in the meantime
    final existing = await weatherRepo.getWeatherSnapshotForParent(
      task.parentType,
      task.parentId,
    );
    if (existing != null && existing.source != 'missing') {
      await _removeTask(task.tag);
      return;
    }

    // Fetch historical weather
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString('weather_provider');
    final providerType = providerName == 'environment_canada'
        ? WeatherProviderType.environmentCanada
        : WeatherProviderType.openMeteo;

    final result = await _fetchHistorical(
      latitude: task.latitude,
      longitude: task.longitude,
      date: task.eventTimestamp,
      providerType: providerType,
    );

    if (result == null) {
      final updated = BackfillTask(
        tag: task.tag,
        latitude: task.latitude,
        longitude: task.longitude,
        eventTimestamp: task.eventTimestamp,
        parentType: task.parentType,
        parentId: task.parentId,
        trialId: task.trialId,
        retryCount: task.retryCount + 1,
        createdAt: task.createdAt,
      );

      if (updated.retryCount >= kMaxBackfillRetries) {
        await _expireTask(updated);
        diagnosticsStore.recordError(
          'Weather backfill expired after $kMaxBackfillRetries retries: '
          '${task.parentType} #${task.parentId}',
          code: 'weather_backfill_expired',
        );
        return;
      }

      await _persistTask(updated);
      throw Exception('Backfill failed, will retry');
    }

    // Write the weather data
    await weatherRepo.upsertWeatherSnapshotFromBackfill(
      trialId: task.trialId,
      parentType: task.parentType,
      parentId: task.parentId,
      temperatureC: result.temperatureC,
      humidityPct: result.humidityPct,
      windSpeedKmh: result.windSpeedKmh,
      windDirection: result.windDirection,
      cloudCover: result.cloudCoverPct != null
          ? _cloudCoverLabel(result.cloudCoverPct!)
          : null,
      precipitation: result.precipitation,
      precipitationMm: result.precipitationMm,
      source: 'api_historical',
    );

    await _removeTask(task.tag);
    debugPrint('WeatherBackfill: completed ${task.tag}');
  }

  Future<WeatherApiResult?> _fetchHistorical({
    required double latitude,
    required double longitude,
    required DateTime date,
    required WeatherProviderType providerType,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hour = date.hour;

      final baseUrl = providerType == WeatherProviderType.environmentCanada
          ? 'https://archive-api.open-meteo.com/v1/archive'
          : 'https://archive-api.open-meteo.com/v1/archive';

      final url = Uri.parse(
        '$baseUrl?latitude=$latitude&longitude=$longitude'
        '&start_date=$dateStr&end_date=$dateStr'
        '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,'
        'wind_direction_10m,cloud_cover,precipitation'
        '&wind_speed_unit=kmh&temperature_unit=celsius',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));
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
        precipitationMm: precips != null && idx < precips.length
            ? (precips[idx] as num?)?.toDouble()
            : null,
        providerName: providerType == WeatherProviderType.environmentCanada
            ? 'Environment Canada (GEM)'
            : 'Open-Meteo',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _expireTask(BackfillTask task) async {
    await _removeTask(task.tag);
    // Mark the record as 'missing' if no weather exists
    final existing = await weatherRepo.getWeatherSnapshotForParent(
      task.parentType,
      task.parentId,
    );
    if (existing == null) {
      await weatherRepo.upsertWeatherSnapshotFromBackfill(
        trialId: task.trialId,
        parentType: task.parentType,
        parentId: task.parentId,
        // qualitative only — no numeric value available from this source
        precipitationMm: null,
        source: 'missing',
      );
    }
  }

  // --- Persistence ---

  Future<List<BackfillTask>> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingTasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BackfillTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistTask(BackfillTask task) async {
    final tasks = await _loadTasks();
    tasks.removeWhere((t) => t.tag == task.tag);
    tasks.add(task);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPendingTasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _removeTask(String tag) async {
    final tasks = await _loadTasks();
    tasks.removeWhere((t) => t.tag == tag);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPendingTasksKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }
}

String _degreesToCompass(double degrees) {
  const directions = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
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

String _cloudCoverLabel(double pct) {
  if (pct < 15) return 'Clear';
  if (pct < 50) return 'Partly cloudy';
  if (pct < 85) return 'Mostly cloudy';
  return 'Overcast';
}
