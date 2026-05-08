import 'trial_intent_inferrer.dart';

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
    this.readinessCriteriaSummary,
    required this.missingIntentFields,
    required this.provenanceSummary,
    required this.canDriveReadinessClaims,
    this.requiresConfirmation = false,
    this.inferenceSource,
    this.inferredPurpose,
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
  final String? readinessCriteriaSummary;

  /// Question keys with no captured answer.
  final List<String> missingIntentFields;

  /// Human-readable provenance label (deterministic, not prose).
  final String provenanceSummary;

  /// True only when status == confirmed and no required fields are missing.
  final bool canDriveReadinessClaims;

  /// True when this row was written by TrialIntentSeeder and not yet
  /// confirmed by the researcher.
  final bool requiresConfirmation;

  /// 'arm_structure' | 'standalone_structure' | 'manual_revelation' etc.
  final String? inferenceSource;

  /// Structured inferred fields with per-field confidence — present when
  /// [requiresConfirmation] is true and [inferredFieldsJson] was stored.
  final InferredTrialPurpose? inferredPurpose;

  bool get isUnknown => purposeStatus == 'unknown';
  bool get isConfirmed => purposeStatus == 'confirmed';
  bool get isPartial => purposeStatus == 'partial';
}
