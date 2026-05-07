import 'package:arm_field_companion/core/connectivity/weather_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeatherApiResult.precipitationMm', () {
    test('WAR-1: stores non-null precipitationMm when provided', () {
      const result = WeatherApiResult(
        temperatureC: 18.5,
        humidityPct: 72.0,
        windSpeedKmh: 10.0,
        precipitation: 'Light rain',
        precipitationMm: 1.8,
      );

      expect(result.precipitationMm, 1.8);
      expect(result.precipitation, 'Light rain');
    });

    test('WAR-2: precipitationMm is null when not provided', () {
      const result = WeatherApiResult(
        temperatureC: 22.0,
        humidityPct: 45.0,
        windSpeedKmh: 5.0,
      );

      expect(result.precipitationMm, isNull);
      expect(result.precipitation, isNull);
    });

    test('WAR-3: zero precipitationMm is distinct from null', () {
      const result = WeatherApiResult(
        temperatureC: 15.0,
        humidityPct: 60.0,
        windSpeedKmh: 8.0,
        precipitationMm: 0.0,
      );

      expect(result.precipitationMm, 0.0);
      expect(result.precipitationMm, isNotNull);
    });
  });
}
