import '../../core/database/app_database.dart';
import '../environmental/inter_event_weather_dto.dart';

// Threshold for excessive rainfall flag in a window (mm per window period).
const double kExcessiveRainfallMm = 10.0;
const int kDryPeriodThresholdDays = 5;
const double kDryPeriodMaxDailyMm = 1.0;

// ── Request / context types used by providers ─────────────────────────────────

class ApplicationEnvironmentalRequest {
  const ApplicationEnvironmentalRequest({
    required this.trialId,
    required this.applicationEventId,
  });

  final int trialId;
  final String applicationEventId;

  @override
  bool operator ==(Object other) =>
      other is ApplicationEnvironmentalRequest &&
      other.trialId == trialId &&
      other.applicationEventId == applicationEventId;

  @override
  int get hashCode => Object.hash(trialId, applicationEventId);
}

class ApplicationEnvironmentalContextDto {
  const ApplicationEnvironmentalContextDto({
    required this.preWindow,
    required this.postWindow,
    this.unavailableReason,
  });

  final EnvironmentalWindowDto preWindow;
  final EnvironmentalWindowDto postWindow;

  /// Null when the application context was resolved successfully.
  /// Non-null means the windows are intentionally unavailable and must not be
  /// interpreted as factual weather around an application event.
  final String? unavailableReason;

  bool get isUnavailable => unavailableReason != null;
}

// ── Output DTOs ───────────────────────────────────────────────────────────────

class EnvironmentalWindowDto {
  const EnvironmentalWindowDto({
    this.totalPrecipitationMm,
    this.minTempC,
    this.maxTempC,
    required this.frostFlagPresent,
    required this.excessiveRainfallFlag,
    required this.recordCount,
    required this.confidence,
  });

  final double? totalPrecipitationMm;
  final double? minTempC;
  final double? maxTempC;
  final bool frostFlagPresent;

  /// True when total precipitation in the window meets or exceeds 10 mm.
  final bool excessiveRainfallFlag;

  final int recordCount;

  /// Lowest confidence level across records in the window.
  /// 'measured' > 'estimated' > 'unavailable'. Empty window = 'unavailable'.
  final String confidence;
}

class EnvironmentalSeasonSummaryDto {
  const EnvironmentalSeasonSummaryDto({
    this.totalPrecipitationMm,
    required this.totalFrostEvents,
    required this.totalExcessiveRainfallEvents,
    required this.daysWithData,
    required this.daysExpected,
    required this.overallConfidence,
  });

  final double? totalPrecipitationMm;
  final int totalFrostEvents;
  final int totalExcessiveRainfallEvents;
  final int daysWithData;
  final int daysExpected;

  /// Lowest confidence across all records, or 'unavailable' when no data.
  final String overallConfidence;
}

// ── Pure computation functions ────────────────────────────────────────────────

/// Returns weather data for the [windowHours] hours preceding [applicationDate].
///
/// Daily records are matched by calendar day. A 72-hour window covers the
/// 3 calendar days before the application date (exclusive of the application
/// day itself).
EnvironmentalWindowDto computePreApplicationWindow(
  List<TrialEnvironmentalRecord> records,
  DateTime applicationDate, {
  int windowHours = 72,
}) {
  final appDay = _dayStart(applicationDate);
  final windowDays = (windowHours / 24).ceil();
  final windowStart = appDay.subtract(Duration(days: windowDays));

  final inWindow = records.where((r) {
    final rDay = DateTime.fromMillisecondsSinceEpoch(r.recordDate, isUtc: true);
    return !rDay.isBefore(windowStart) && rDay.isBefore(appDay);
  }).toList();

  return _buildWindowDto(inWindow);
}

/// Returns weather data for the [windowHours] hours following [applicationDate].
///
/// A 48-hour window covers the 2 calendar days starting from the application
/// day (inclusive).
EnvironmentalWindowDto computePostApplicationWindow(
  List<TrialEnvironmentalRecord> records,
  DateTime applicationDate, {
  int windowHours = 48,
}) {
  final appDay = _dayStart(applicationDate);
  final windowDays = (windowHours / 24).ceil();
  final windowEnd = appDay.add(Duration(days: windowDays));

  final inWindow = records.where((r) {
    final rDay = DateTime.fromMillisecondsSinceEpoch(r.recordDate, isUtc: true);
    return !rDay.isBefore(appDay) && rDay.isBefore(windowEnd);
  }).toList();

  return _buildWindowDto(inWindow);
}

/// Aggregates environmental data across the full trial season.
EnvironmentalSeasonSummaryDto computeSeasonSummary(
  List<TrialEnvironmentalRecord> records,
  DateTime trialStartDate,
  DateTime trialEndDate,
) {
  final start = _dayStart(trialStartDate);
  final end = _dayStart(trialEndDate).add(const Duration(days: 1));

  final daysExpected = end.difference(start).inDays;

  final inRange = records.where((r) {
    final rDay = DateTime.fromMillisecondsSinceEpoch(r.recordDate, isUtc: true);
    return !rDay.isBefore(start) && rDay.isBefore(end);
  }).toList();

  if (inRange.isEmpty) {
    return EnvironmentalSeasonSummaryDto(
      totalPrecipitationMm: null,
      totalFrostEvents: 0,
      totalExcessiveRainfallEvents: 0,
      daysWithData: 0,
      daysExpected: daysExpected,
      overallConfidence: 'unavailable',
    );
  }

  double? totalPrecip;
  var frostEvents = 0;
  var excessiveRainEvents = 0;
  var confidence = 'measured';

  for (final r in inRange) {
    final precip = r.dailyPrecipitationMm;
    if (precip != null) {
      totalPrecip = (totalPrecip ?? 0) + precip;
      if (precip >= kExcessiveRainfallMm) excessiveRainEvents++;
    }
    final minTemp = r.dailyMinTempC;
    if (minTemp != null && minTemp < 0) frostEvents++;

    confidence = _worseConfidence(confidence, r.confidence);
  }

  return EnvironmentalSeasonSummaryDto(
    totalPrecipitationMm: totalPrecip,
    totalFrostEvents: frostEvents,
    totalExcessiveRainfallEvents: excessiveRainEvents,
    daysWithData: inRange.length,
    daysExpected: daysExpected,
    overallConfidence: confidence,
  );
}

/// Aggregates weather events between two timeline dates for the corridor pills.
InterEventWeatherDto computeInterEventWindow(
  List<TrialEnvironmentalRecord> allRecords,
  DateTime from,
  DateTime to,
) {
  final fromDay = DateTime.utc(from.year, from.month, from.day);
  final toDay = DateTime.utc(to.year, to.month, to.day);
  final fromMs = fromDay.millisecondsSinceEpoch;
  final toMs = toDay.millisecondsSinceEpoch;

  final records = allRecords
      .where((r) => r.recordDate >= fromMs && r.recordDate <= toMs)
      .toList()
    ..sort((a, b) => a.recordDate.compareTo(b.recordDate));

  if (records.isEmpty) return const InterEventWeatherDto(events: []);

  final events = <InterEventWeatherEvent>[];

  // Rain runs — consecutive days with precip > 0, total >= kExcessiveRainfallMm
  for (final run in _extractRuns(records, (r) => (r.dailyPrecipitationMm ?? 0) > 0)) {
    final total = run.fold(0.0, (s, r) => s + (r.dailyPrecipitationMm ?? 0));
    if (total >= kExcessiveRainfallMm) {
      events.add(InterEventWeatherEvent(
        type: InterEventWeatherType.rain,
        from: DateTime.fromMillisecondsSinceEpoch(run.first.recordDate, isUtc: true),
        to: DateTime.fromMillisecondsSinceEpoch(run.last.recordDate, isUtc: true),
        valueMm: total,
      ));
    }
  }

  // Frost — any day with minTempC < 0
  final frostDays = records
      .where((r) => r.dailyMinTempC != null && r.dailyMinTempC! < 0)
      .toList();
  if (frostDays.isNotEmpty) {
    events.add(InterEventWeatherEvent(
      type: InterEventWeatherType.frost,
      from: DateTime.fromMillisecondsSinceEpoch(frostDays.first.recordDate, isUtc: true),
      to: DateTime.fromMillisecondsSinceEpoch(frostDays.last.recordDate, isUtc: true),
    ));
  }

  // Dry period — kDryPeriodThresholdDays+ consecutive days with precip < kDryPeriodMaxDailyMm
  for (final run in _extractRuns(
    records,
    (r) => (r.dailyPrecipitationMm ?? 0) < kDryPeriodMaxDailyMm,
  )) {
    if (run.length >= kDryPeriodThresholdDays) {
      events.add(InterEventWeatherEvent(
        type: InterEventWeatherType.dry,
        from: DateTime.fromMillisecondsSinceEpoch(run.first.recordDate, isUtc: true),
        to: DateTime.fromMillisecondsSinceEpoch(run.last.recordDate, isUtc: true),
      ));
    }
  }

  return InterEventWeatherDto(events: events);
}

List<List<TrialEnvironmentalRecord>> _extractRuns(
  List<TrialEnvironmentalRecord> records,
  bool Function(TrialEnvironmentalRecord) test,
) {
  final runs = <List<TrialEnvironmentalRecord>>[];
  List<TrialEnvironmentalRecord>? current;
  for (final r in records) {
    if (test(r)) {
      (current ??= []).add(r);
    } else {
      if (current != null) {
        runs.add(current);
        current = null;
      }
    }
  }
  if (current != null) runs.add(current);
  return runs;
}

// ── Shared helpers ────────────────────────────────────────────────────────────

EnvironmentalWindowDto _buildWindowDto(List<TrialEnvironmentalRecord> records) {
  if (records.isEmpty) {
    return const EnvironmentalWindowDto(
      totalPrecipitationMm: null,
      minTempC: null,
      maxTempC: null,
      frostFlagPresent: false,
      excessiveRainfallFlag: false,
      recordCount: 0,
      confidence: 'unavailable',
    );
  }

  double? totalPrecip;
  double? minTemp;
  double? maxTemp;
  var hasFrost = false;
  var confidence = 'measured';

  for (final r in records) {
    final precip = r.dailyPrecipitationMm;
    if (precip != null) totalPrecip = (totalPrecip ?? 0) + precip;

    final lo = r.dailyMinTempC;
    if (lo != null) {
      minTemp = minTemp == null ? lo : (lo < minTemp ? lo : minTemp);
      if (lo < 0) hasFrost = true;
    }

    final hi = r.dailyMaxTempC;
    if (hi != null) {
      maxTemp = maxTemp == null ? hi : (hi > maxTemp ? hi : maxTemp);
    }

    confidence = _worseConfidence(confidence, r.confidence);
  }

  return EnvironmentalWindowDto(
    totalPrecipitationMm: totalPrecip,
    minTempC: minTemp,
    maxTempC: maxTemp,
    frostFlagPresent: hasFrost,
    excessiveRainfallFlag:
        totalPrecip != null && totalPrecip >= kExcessiveRainfallMm,
    recordCount: records.length,
    confidence: confidence,
  );
}

/// Returns the worse of two confidence levels.
/// Priority (worst to best): unavailable > estimated > measured.
String _worseConfidence(String a, String b) {
  const rank = {'measured': 0, 'estimated': 1, 'unavailable': 2};
  return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
}

DateTime _dayStart(DateTime date) {
  final utc = date.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}
