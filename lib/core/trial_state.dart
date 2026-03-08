/// Trial lifecycle states (Constitution §9).
/// Draft → Ready → Active → Closed → Archived.
///
/// Keep transitions strict: only the defined next steps (e.g. draft→ready→active).
/// Do not add casual "reopen" or status jumping unless explicitly designed.
/// If protocol changes are ever needed after activation, use an amendment/versioned
/// path later, not unlock buttons.
const String kTrialStatusDraft = 'draft';
const String kTrialStatusReady = 'ready';
const String kTrialStatusActive = 'active';
const String kTrialStatusClosed = 'closed';
const String kTrialStatusArchived = 'archived';

/// All valid status values for validation.
const List<String> kTrialStatusValues = [
  kTrialStatusDraft,
  kTrialStatusReady,
  kTrialStatusActive,
  kTrialStatusClosed,
  kTrialStatusArchived,
];

/// When true, protocol (plots, assessment definitions, assignments) must not be edited.
/// This locks *definitions* only. Recording assessment values (ratings) in sessions
/// remains allowed in active trials.
bool isProtocolLocked(String? status) {
  if (status == null) return false;
  return status == kTrialStatusActive ||
      status == kTrialStatusClosed ||
      status == kTrialStatusArchived;
}

/// Display label for status.
String labelForTrialStatus(String? status) {
  switch (status) {
    case kTrialStatusDraft:
      return 'Draft';
    case kTrialStatusReady:
      return 'Ready';
    case kTrialStatusActive:
      return 'Active';
    case kTrialStatusClosed:
      return 'Closed';
    case kTrialStatusArchived:
      return 'Archived';
    default:
      return status ?? 'Active';
  }
}

/// Next status(es) allowed from current (for UI transitions).
List<String> allowedNextTrialStatuses(String? status) {
  switch (status) {
    case kTrialStatusDraft:
      return [kTrialStatusReady];
    case kTrialStatusReady:
      return [kTrialStatusActive];
    case kTrialStatusActive:
      return [kTrialStatusClosed];
    case kTrialStatusClosed:
      return [kTrialStatusArchived];
    case kTrialStatusArchived:
      return [];
    default:
      return [kTrialStatusDraft, kTrialStatusReady, kTrialStatusActive];
  }
}
