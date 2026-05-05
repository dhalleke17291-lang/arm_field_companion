class TrialEnvironmentalRecordDto {
  const TrialEnvironmentalRecordDto({
    required this.id,
    required this.trialId,
    required this.recordDate,
    required this.siteLatitude,
    required this.siteLongitude,
    this.dailyMinTempC,
    this.dailyMaxTempC,
    this.dailyPrecipitationMm,
    this.weatherFlags,
    required this.dataSource,
    required this.fetchedAt,
    required this.confidence,
  });

  final int id;
  final int trialId;
  final DateTime recordDate;
  final double siteLatitude;
  final double siteLongitude;
  final double? dailyMinTempC;
  final double? dailyMaxTempC;
  final double? dailyPrecipitationMm;

  /// Raw JSON array string, e.g. '["frost","excessive_rainfall"]', or null.
  final String? weatherFlags;

  final String dataSource;
  final DateTime fetchedAt;

  /// 'measured' | 'estimated' | 'unavailable'
  final String confidence;

  bool get hasFrostFlag =>
      weatherFlags != null && weatherFlags!.contains('frost');
}
