import 'ctq_factor_acknowledgment_dto.dart';

/// One CTQ factor evaluation item.
/// status: unknown | missing | satisfied | review_needed | blocked | not_applicable
class TrialCtqItemDto {
  const TrialCtqItemDto({
    required this.factorKey,
    required this.label,
    required this.importance,
    required this.status,
    required this.evidenceSummary,
    required this.reason,
    required this.source,
    this.isAcknowledged = false,
    this.latestAcknowledgment,
  });

  final String factorKey;
  final String label;
  final String importance;
  final String status;
  final String evidenceSummary;
  final String reason;
  final String source;
  final bool isAcknowledged;
  final CtqFactorAcknowledgmentDto? latestAcknowledgment;

  bool get isBlocked => status == 'blocked';
  bool get isSatisfied => status == 'satisfied';
  bool get needsReview => status == 'review_needed';
}

/// DTO for trial critical-to-quality readiness status.
/// overallStatus: unknown | incomplete | review_needed | ready_for_review
class TrialCtqDto {
  const TrialCtqDto({
    required this.trialId,
    required this.ctqItems,
    required this.blockerCount,
    required this.warningCount,
    required this.reviewCount,
    required this.satisfiedCount,
    required this.overallStatus,
  });

  final int trialId;
  final List<TrialCtqItemDto> ctqItems;
  final int blockerCount;
  final int warningCount;
  final int reviewCount;
  final int satisfiedCount;
  final String overallStatus;

  bool get isReadyForReview => overallStatus == 'ready_for_review';
  bool get hasBlockers => blockerCount > 0;
}
