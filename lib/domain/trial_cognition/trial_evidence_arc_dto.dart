/// DTO answering: What evidence exists? What is missing? What are the risk flags?
class TrialEvidenceArcDto {
  const TrialEvidenceArcDto({
    required this.trialId,
    required this.evidenceState,
    required this.plannedEvidenceSummary,
    required this.actualEvidenceSummary,
    required this.missingEvidenceItems,
    required this.evidenceAnchors,
    required this.riskFlags,
  });

  final int trialId;

  /// no_evidence | started | partial | sufficient_for_review | export_ready_candidate
  final String evidenceState;

  final String plannedEvidenceSummary;
  final String actualEvidenceSummary;
  final List<String> missingEvidenceItems;
  final List<String> evidenceAnchors;
  final List<String> riskFlags;

  bool get hasEvidence => evidenceState != 'no_evidence';
  bool get isSufficientForReview =>
      evidenceState == 'sufficient_for_review' ||
      evidenceState == 'export_ready_candidate';
}
