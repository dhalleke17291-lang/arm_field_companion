/// DTO answering: What is this trial trying to prove? Is purpose captured?
class TrialPurposeDto {
  const TrialPurposeDto({
    required this.trialId,
    required this.purposeStatus,
    this.claimBeingTested,
    this.trialPurpose,
    this.regulatoryContext,
    this.primaryEndpoint,
    this.treatmentRoles,
    this.knownInterpretationFactors,
    required this.missingIntentFields,
    required this.provenanceSummary,
    required this.canDriveReadinessClaims,
  });

  final int trialId;

  /// unknown | draft | partial | confirmed | superseded
  final String purposeStatus;

  final String? claimBeingTested;
  final String? trialPurpose;
  final String? regulatoryContext;
  final String? primaryEndpoint;
  final String? treatmentRoles;
  final String? knownInterpretationFactors;

  /// Question keys with no captured answer.
  final List<String> missingIntentFields;

  /// Human-readable provenance label (deterministic, not prose).
  final String provenanceSummary;

  /// True only when status == confirmed and no required fields are missing.
  final bool canDriveReadinessClaims;

  bool get isUnknown => purposeStatus == 'unknown';
  bool get isConfirmed => purposeStatus == 'confirmed';
  bool get isPartial => purposeStatus == 'partial';
}
