/// Daily aggregates returned by [WeatherDailyFetchService].
///
/// All fields may be present or partially missing depending on upstream data.
class WeatherDailySummary {
  const WeatherDailySummary({
    this.minTempC,
    this.maxTempC,
    this.precipMm,
  });

  final double? minTempC;
  final double? maxTempC;
  final double? precipMm;
}
