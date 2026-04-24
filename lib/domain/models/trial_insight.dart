/// Domain model for a single computed trial insight.
///
/// Every insight carries its [basis] — the raw numbers, method, thresholds,
/// and confidence level. If the basis can't be shown, the insight doesn't exist.
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
    this.verdict,
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

  /// One-sentence human verdict. Must pass `docs/INSIGHT_VOICE_SPEC.md`.
  ///
  /// Null when the service cannot stand behind a clean call for the given
  /// confidence tier and situation. Null means the UI falls back to showing
  /// only [title] and [detail] — silence beats noise.
  final String? verdict;

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

enum InsightConfidence {
  /// 2 sessions or <4 reps.
  preliminary,

  /// 3-4 sessions, 4+ reps.
  moderate,

  /// 5+ sessions, consistent trend.
  established,
}

/// Evidence backing an insight — what data it used, how it computed, and
/// how confident the result is.
class InsightBasis {
  const InsightBasis({
    required this.repCount,
    required this.sessionCount,
    required this.method,
    required this.minimumDataMet,
    required this.confidence,
    this.assessmentType,
    this.threshold,
  });

  final int repCount;
  final int sessionCount;
  final String method;
  final bool minimumDataMet;
  final InsightConfidence confidence;

  /// e.g. "CONTRO %", "PHYGEN %"
  final String? assessmentType;

  /// e.g. "±5%", "2 SD"
  final String? threshold;

  String get confidenceLabel => switch (confidence) {
        InsightConfidence.preliminary => 'Preliminary',
        InsightConfidence.moderate => 'Moderate',
        InsightConfidence.established => 'Established',
      };

  String get basisSummary {
    final parts = <String>[
      '$sessionCount session${sessionCount == 1 ? '' : 's'}',
      '$repCount rep${repCount == 1 ? '' : 's'}',
    ];
    if (assessmentType != null) parts.add(assessmentType!);
    return '${parts.join(', ')}. $confidenceLabel.';
  }
}

/// Resolves confidence from session count and rep count.
InsightConfidence resolveConfidence({
  required int sessionCount,
  required int repCount,
  bool consistentTrend = false,
}) {
  if (sessionCount >= 5 && consistentTrend) return InsightConfidence.established;
  if (sessionCount >= 3 && repCount >= 4) return InsightConfidence.moderate;
  return InsightConfidence.preliminary;
}
