import 'dart:convert';

import 'package:http/http.dart' as http;

/// Weather data fetched from any provider.
class WeatherApiResult {
  const WeatherApiResult({
    required this.temperatureC,
    required this.humidityPct,
    required this.windSpeedKmh,
    this.windDirection,
    this.cloudCoverPct,
    this.precipitation,
    this.precipitationMm,
    this.providerName,
  });

  final double temperatureC;
  final double humidityPct;
  final double windSpeedKmh;
  final String? windDirection;
  final double? cloudCoverPct;
  final String? precipitation;

  /// Raw numeric precipitation in millimetres from the API response.
  /// Null when the API returned no precipitation data.
  final double? precipitationMm;
  final String? providerName;
}

/// Abstract weather provider. Each source implements this.
abstract class WeatherProvider {
  String get displayName;
  String get providerId;

  Future<WeatherApiResult?> fetchCurrent({
    required double latitude,
    required double longitude,
    Duration timeout = const Duration(seconds: 10),
  });
}

/// Available weather provider types.
enum WeatherProviderType {
  openMeteo,
  environmentCanada,
}

/// Open-Meteo: free, no API key, global coverage.
class OpenMeteoProvider implements WeatherProvider {
  @override
  String get displayName => 'Open-Meteo';
  @override
  String get providerId => 'open_meteo';

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  @override
  Future<WeatherApiResult?> fetchCurrent({
    required double latitude,
    required double longitude,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
        'wind_direction_10m,cloud_cover,precipitation'
        '&wind_speed_unit=kmh&temperature_unit=celsius',
      );

      final response = await http.get(url).timeout(timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return null;

      final windDeg = (current['wind_direction_10m'] as num?)?.toDouble();
      final precipMm = (current['precipitation'] as num?)?.toDouble();

      return WeatherApiResult(
        temperatureC:
            (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        humidityPct:
            (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
        windSpeedKmh:
            (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        windDirection: windDeg != null ? _degreesToCompass(windDeg) : null,
        cloudCoverPct:
            (current['cloud_cover'] as num?)?.toDouble(),
        precipitation: _describePrecipitation(precipMm),
        precipitationMm: precipMm,
        providerName: displayName,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Environment Canada: uses Open-Meteo's Canadian model (GEM) for
/// better accuracy in Canada. Same API, different model parameter.
class EnvironmentCanadaProvider implements WeatherProvider {
  @override
  String get displayName => 'Environment Canada (GEM)';
  @override
  String get providerId => 'environment_canada';

  static const String _baseUrl =
      'https://api.open-meteo.com/v1/gem';

  @override
  Future<WeatherApiResult?> fetchCurrent({
    required double latitude,
    required double longitude,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
        'wind_direction_10m,cloud_cover,precipitation'
        '&wind_speed_unit=kmh&temperature_unit=celsius',
      );

      final response = await http.get(url).timeout(timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return null;

      final windDeg = (current['wind_direction_10m'] as num?)?.toDouble();
      final precipMm = (current['precipitation'] as num?)?.toDouble();

      return WeatherApiResult(
        temperatureC:
            (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        humidityPct:
            (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
        windSpeedKmh:
            (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        windDirection: windDeg != null ? _degreesToCompass(windDeg) : null,
        cloudCoverPct:
            (current['cloud_cover'] as num?)?.toDouble(),
        precipitation: _describePrecipitation(precipMm),
        precipitationMm: precipMm,
        providerName: displayName,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Resolves provider type to implementation.
WeatherProvider weatherProviderFor(WeatherProviderType type) {
  switch (type) {
    case WeatherProviderType.openMeteo:
      return OpenMeteoProvider();
    case WeatherProviderType.environmentCanada:
      return EnvironmentCanadaProvider();
  }
}

// --- Shared helpers ---

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
