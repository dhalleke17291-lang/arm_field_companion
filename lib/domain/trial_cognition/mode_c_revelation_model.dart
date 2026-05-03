/// Canonical question keys for Mode C intent revelation flow.
abstract class ModeCQuestionKeys {
  static const String claimBeingTested = 'claim_being_tested';
  static const String trialPurposeContext = 'trial_purpose_context';
  static const String primaryEndpoint = 'primary_endpoint';
  static const String treatmentRoles = 'treatment_roles';
  static const String knownInterpretationFactors = 'known_interpretation_factors';

  static const List<String> all = [
    claimBeingTested,
    trialPurposeContext,
    primaryEndpoint,
    treatmentRoles,
    knownInterpretationFactors,
  ];

  /// Keys required for canDriveReadinessClaims = true.
  static const List<String> required = [
    claimBeingTested,
    trialPurposeContext,
    primaryEndpoint,
    treatmentRoles,
  ];
}

/// Canonical question text for each Mode C question key.
const Map<String, String> kModeCQuestionText = {
  ModeCQuestionKeys.claimBeingTested:
      'What is this trial trying to show or compare?',
  ModeCQuestionKeys.trialPurposeContext:
      'What kind of decision will this trial support?',
  ModeCQuestionKeys.primaryEndpoint:
      'What is the main assessment or outcome that matters most?',
  ModeCQuestionKeys.treatmentRoles:
      'What role does each treatment play in the comparison?',
  ModeCQuestionKeys.knownInterpretationFactors:
      'What field conditions or events could affect how results should be interpreted?',
};

/// Touchpoint keys for Mode C revelation events.
abstract class ModeCTouchpoints {
  static const String trialCreation = 'trial_creation';
  static const String firstAssessmentSetup = 'first_assessment_setup';
  static const String firstApplicationOrOperation =
      'first_application_or_operation';
  static const String preFirstRating = 'pre_first_rating';
  static const String preExportReview = 'pre_export_review';
  static const String manualOverview = 'manual_overview';
}

/// Answer state constants for intent_revelation_events.answerState.
abstract class IntentAnswerState {
  static const String unknown = 'unknown';
  static const String captured = 'captured';
  static const String confirmed = 'confirmed';
  static const String revised = 'revised';
  static const String skipped = 'skipped';
}

/// Purpose status constants for trial_purposes.status.
abstract class TrialPurposeStatus {
  static const String draft = 'draft';
  static const String partial = 'partial';
  static const String confirmed = 'confirmed';
  static const String superseded = 'superseded';
}

/// Source mode constants for trial_purposes.sourceMode.
abstract class TrialPurposeSourceMode {
  static const String armStructure = 'arm_structure';
  static const String manualRevelation = 'manual_revelation';
  static const String protocolDocument = 'protocol_document';
  static const String mixed = 'mixed';
}
