import 'workspace/workspace_config.dart';

/// Trial lifecycle states (Constitution §9).
/// Stored on [Trials.status] (`trials.status` TEXT). Values are lowercase strings
/// defined below — use these constants only; do not invent alternate spellings.
///
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

/// Whether a trial counts for the list header "Active" pill and Active filter:
/// [kTrialStatusActive] or [kTrialStatusReady] (same as hub stats), or an open
/// field session while not closed/archived (matches trial detail effective status).
bool trialIsListedAsActive({
  required String trialStatus,
  required bool hasOpenFieldSession,
}) {
  final s = trialStatus.toLowerCase();
  if (s == kTrialStatusClosed || s == kTrialStatusArchived) return false;
  if (s == kTrialStatusActive || s == kTrialStatusReady) return true;
  return hasOpenFieldSession;
}

/// Stored status adjusted for list badges when an open session implies "Active"
/// (aligned with trial detail [TrialDetailScreen] effective status strip).
String effectiveTrialStatusForListDisplay({
  required String trialStatus,
  required bool hasOpenFieldSession,
}) {
  final s = trialStatus.toLowerCase();
  if (s != kTrialStatusClosed &&
      s != kTrialStatusArchived &&
      hasOpenFieldSession) {
    return kTrialStatusActive;
  }
  return trialStatus;
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

/// Short, user-facing description of what the status means (for hints in the UI).
String statusDescriptionForTrialStatus(String? status) {
  switch (status) {
    case kTrialStatusDraft:
      return 'Trial is in setup. Add plots and treatments, then mark ready.';
    case kTrialStatusReady:
      return 'Setup complete. You can start sessions to collect data.';
    case kTrialStatusActive:
      return 'Data collection in progress.';
    case kTrialStatusClosed:
      return 'Data collection finished.';
    case kTrialStatusArchived:
      return 'Trial archived.';
    default:
      return '';
  }
}

/// Label for protocol lock state: "Editable" or "Locked".
String getProtocolLockLabel(String? status) {
  return isProtocolLocked(status) ? 'Locked' : 'Editable';
}

/// Standard message when an action is blocked because protocol is locked.
String getProtocolLockMessage(String? status) {
  if (status == null || !isProtocolLocked(status)) return '';
  final label = labelForTrialStatus(status);
  return 'Protocol is locked because this trial is $label.';
}

/// Mode-aware lock message. Use when workspaceType is available.
/// Standalone trials show a softer warning; protocol/GLP show strict lock.
/// Falls back to [getProtocolLockMessage] when workspaceType is unknown.
String getModeLockMessage(String? status, String? workspaceType) {
  if (status == null || !isProtocolLocked(status)) return '';
  final config = safeConfigFromString(workspaceType ?? '');
  if (config.isStandalone) {
    final label = labelForTrialStatus(status);
    return 'This trial is $label. Structural changes may affect existing data.';
  }
  if (config.studyType == StudyType.glp) {
    return 'GLP protocol is locked. Changes require a controlled amendment workflow.';
  }
  return 'Protocol is locked. Changes require protocol-controlled workflow.';
}

/// True when plot assignments must not be edited (protocol lock or trial has session data).
/// [hasSessionData] = true only when a session has actual data (ratings, notes, photos, flags).
bool isAssignmentsLocked(String? status, bool hasSessionData) {
  return isProtocolLocked(status) || hasSessionData;
}

/// Label for assignment lock chip in Plots UI.
/// Distinguishes protocol lock ("locked") from session-data fixation ("fixed").
/// Use this (not getProtocolLockLabel) when the chip reflects assignment state.
String getAssignmentsLockLabel(String? status, bool hasSessionData) {
  if (!isAssignmentsLocked(status, hasSessionData)) {
    return 'Editable';
  }
  if (isProtocolLocked(status)) {
    return 'Assignments locked';
  }
  if (hasSessionData) {
    return 'Assignments fixed';
  }
  return 'Assignments locked';
}

/// Message when an assignment action is blocked.
String getAssignmentsLockMessage(String? status, bool hasSessionData) {
  if (isProtocolLocked(status)) return getProtocolLockMessage(status);
  if (hasSessionData) {
    return 'Assignments are fixed because this trial has session data.';
  }
  return '';
}

/// Full explanation when locked: what you cannot edit and what you can still do.
/// Use in status bar or help so users understand lock vs. unlock behavior.
String getProtocolLockExplanation(String? status) {
  if (status == null || !isProtocolLocked(status)) return '';
  return "When locked you cannot add or edit: treatments, plots, assessments, or plot assignments. "
      "You can still: run sessions, record ratings, add plot notes, and export.";
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
