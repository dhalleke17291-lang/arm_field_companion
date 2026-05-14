enum SignalOperationalState {
  needsAction,
  underReview,
  reviewLater,
  historical,
}

enum SignalFamilyKey {
  untreatedCheckVariance,
  raterDivergence,
  timingWindowReview,
  replicationPattern,
  singleton,
}

class SignalReviewProjection {
  const SignalReviewProjection({
    required this.signalId,
    required this.type,
    required this.status,
    required this.severity,
    required this.operationalState,
    required this.displayTitle,
    required this.shortSummary,
    required this.detailText,
    required this.whyItMatters,
    required this.recommendedAction,
    required this.statusLabel,
    required this.severityLabel,
    required this.isActive,
    required this.isNeedsAction,
    required this.isUnderReview,
    required this.isHistorical,
    required this.requiresReadinessAction,
    required this.readinessActionReason,
    required this.blocksExport,
    required this.blocksExportReason,
    this.reliabilityTier,
  });

  final int signalId;
  final String type;
  final String status;
  final String severity;
  final SignalOperationalState operationalState;
  final String displayTitle;
  final String shortSummary;
  final String detailText;
  final String whyItMatters;
  final String recommendedAction;
  final String statusLabel;
  final String severityLabel;
  final bool isActive;
  final bool isNeedsAction;
  final bool isUnderReview;
  final bool isHistorical;
  final bool requiresReadinessAction;
  final String? readinessActionReason;
  final bool blocksExport;
  final String? blocksExportReason;
  final String? reliabilityTier;
}

class SignalReviewGroupProjection {
  const SignalReviewGroupProjection({
    required this.groupId,
    required this.groupType,
    required this.familyKey,
    required this.familyDefinition,
    required this.groupingBasis,
    required this.familyScientificRole,
    required this.familyInterpretationImpact,
    required this.reviewQuestion,
    required this.displayTitle,
    required this.shortSummary,
    required this.whyItMatters,
    required this.recommendedAction,
    required this.statusLabel,
    required this.severityLabel,
    required this.signalCount,
    required this.affectedAssessmentIds,
    required this.affectedPlotIds,
    required this.affectedSessionIds,
    required this.memberSignals,
  });

  final String groupId;
  final String groupType;
  final SignalFamilyKey familyKey;
  final String familyDefinition;
  final String groupingBasis;
  final String familyScientificRole;
  final String familyInterpretationImpact;
  final String reviewQuestion;
  final String displayTitle;
  final String shortSummary;
  final String whyItMatters;
  final String recommendedAction;
  final String statusLabel;
  final String severityLabel;
  final int signalCount;
  final List<int> affectedAssessmentIds;
  final List<int> affectedPlotIds;
  final List<int> affectedSessionIds;
  final List<SignalReviewProjection> memberSignals;
}
