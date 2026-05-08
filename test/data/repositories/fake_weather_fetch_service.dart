import 'package:arm_field_companion/data/services/weather_daily_fetch_service.dart';
import 'package:arm_field_companion/data/services/weather_daily_summary.dart';

/// Test fake for [WeatherDailyFetchService]. No real HTTP.
class FakeWeatherFetchService implements WeatherDailyFetchService {
  FakeWeatherFetchService({
    this.result,
    this.rangeResult = const [],
    this.throwOnFetch = false,
  });

  /// Returned on each call unless [throwOnFetch] is true.
  final WeatherDailySummary? result;
  final List<WeatherDailyRecord> rangeResult;

  /// When true, throws to simulate unexpected transport/protocol errors.
  final bool throwOnFetch;

  int totalCalls = 0;
  int totalRangeCalls = 0;

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

  @override
  Future<List<WeatherDailyRecord>> fetchDailyRange(
    double lat,
    double lng,
    DateTime startDate,
    DateTime endDate,
  ) async {
    totalRangeCalls++;
    if (throwOnFetch) throw StateError('simulated weather range failure');
    return rangeResult;
  }
}
