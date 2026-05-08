import 'package:arm_field_companion/data/services/open_meteo_weather_fetch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('fetchDailyRange', () {
    test('returns one record per date in range', () async {
      final service = OpenMeteoWeatherFetchService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['temperature_unit'], 'celsius');
          expect(request.url.queryParameters['wind_speed_unit'], 'kmh');
          expect(request.url.queryParameters['precipitation_unit'], 'mm');
          expect(request.url.queryParameters['timezone'], 'auto');
          return http.Response(
            '''
{
  "daily": {
    "time": ["2026-05-01", "2026-05-02"],
    "temperature_2m_min": [1.5, null],
    "temperature_2m_max": [12.5, 13],
    "precipitation_sum": [0, 2.4]
  }
}
''',
            200,
          );
        }),
      );

      final records = await service.fetchDailyRange(
        46.2382,
        -63.1311,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 2),
      );

      expect(records, hasLength(2));
      expect(records[0].date, DateTime(2026, 5, 1));
      expect(records[0].minTempC, 1.5);
      expect(records[0].maxTempC, 12.5);
      expect(records[0].precipMm, 0);
      expect(records[1].minTempC, isNull);
      expect(records[1].precipMm, 2.4);
    });

    test('returns empty list on non-200 response', () async {
      final service = OpenMeteoWeatherFetchService(
        client: MockClient((_) async => http.Response('nope', 500)),
      );

      final records = await service.fetchDailyRange(
        46.2382,
        -63.1311,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 2),
      );

      expect(records, isEmpty);
    });

    test('handles null values in API response', () async {
      final service = OpenMeteoWeatherFetchService(
        client: MockClient((_) async {
          return http.Response(
            '''
{
  "daily": {
    "time": ["2026-05-01"],
    "temperature_2m_min": [null],
    "temperature_2m_max": [null],
    "precipitation_sum": [null]
  }
}
''',
            200,
          );
        }),
      );

      final records = await service.fetchDailyRange(
        46.2382,
        -63.1311,
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 5, 1),
      );

      expect(records, hasLength(1));
      expect(records.single.minTempC, isNull);
      expect(records.single.maxTempC, isNull);
      expect(records.single.precipMm, isNull);
    });
  });
}
