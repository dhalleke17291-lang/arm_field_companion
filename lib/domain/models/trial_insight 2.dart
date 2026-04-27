class TrialInsight {
  const TrialInsight({
    required this.type,
    required this.title,
    required this.detail,
    required this.basis,
    this.severity = InsightSeverity.info,
    this.relatedSessionIds = const [],
    this.relatedPlotIds = const [],
    this.relatedTreatmentIds = const [],
    this.timingLabel,
    this.assessmentName,
    this.treatmentName,
    this.fromDate,
    this.toDate,
  });

  final InsightType type;
  final String title;

  /// Human-readable detail with raw numbers inline.
  final String detail;

  final InsightBasis basis;

  final InsightSeverity severity;

  final List<int> relatedSessionIds;
  final List<int> relatedPlotIds;
  final List<int> relatedTreatmentIds;

  /// e.g. "14 DAA" — timing context for timeline placement.
  final String? timingLabel;

  /// ARM assessment code / name (e.g. "CONTRO"). Populated for treatmentTrend.
  final String? assessmentName;

  /// Treatment name (e.g. "APRON XL"). Populated for treatmentTrend.
  final String? treatmentName;

  /// Short date label for the first session in the trend (e.g. "Apr 2").
  final String? fromDate;

  /// Short date label for the last session in the trend (e.g. "Apr 23").
  final String? toDate;
}

enum InsightType {
  /// Open-session plot capture counts only — execution progress, not inference.
  sessionFieldCapture,
  trialHealth,
  treatmentTrend,
  checkTrend,
  repVariability,
  testVsReference,
  doseResponse,
  plotAnomaly,
  weatherContext,
  completenessPattern,
  raterPace,
  photoCoverage,
}

enum InsightSeverity {
  info,
  notable,
  attention,
}

/// Evidence backing an insight — what data it used, how it computed, and
/// how much history supports the row.
class InsightBasis {
  const InsightBasis({
    required this.repCount,
    required this.sessionCount,
    required this.method,
    required this.minimumDataMet,
    this.assessmentType,
    this.threshold,
  });

  final int repCount;
  final int sessionCount;
  final String method;
  final bool minimumDataMet;

  /// e.g. "CONTRO %", "PHYGEN %"
  final String? assessmentType;

  /// e.g. "±5%", "2 SD"
  final String? threshold;
}
