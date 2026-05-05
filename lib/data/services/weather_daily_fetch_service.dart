import 'weather_daily_summary.dart';

/// Fetches one calendar day’s weather aggregates for coordinates.
///
/// Implementations typically call an HTTP API (e.g. Open-Meteo). Returns null
/// when data is unavailable or the request fails.
abstract class WeatherDailyFetchService {
  Future<WeatherDailySummary?> fetchDailySummary(
    double lat,
    double lng,
    DateTime date,
  );
}
