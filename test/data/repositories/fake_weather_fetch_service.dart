import 'package:arm_field_companion/data/services/weather_daily_fetch_service.dart';
import 'package:arm_field_companion/data/services/weather_daily_summary.dart';

/// Test fake for [WeatherDailyFetchService]. No real HTTP.
class FakeWeatherFetchService implements WeatherDailyFetchService {
  FakeWeatherFetchService({
    this.result,
    this.throwOnFetch = false,
  });

  /// Returned on each call unless [throwOnFetch] is true.
  final WeatherDailySummary? result;

  /// When true, throws to simulate unexpected transport/protocol errors.
  final bool throwOnFetch;

  int totalCalls = 0;

  @override
  Future<WeatherDailySummary?> fetchDailySummary(
    double lat,
    double lng,
    DateTime date,
  ) async {
    totalCalls++;
    if (throwOnFetch) throw StateError('simulated weather fetch failure');
    return result;
  }
}
