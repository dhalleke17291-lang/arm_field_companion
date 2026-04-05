import 'package:drift/drift.dart';

import 'database/app_database.dart';
import 'protocol_edit_blocked_exception.dart';

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

/// Label for lifecycle lock state: "Editable" or "Locked" (structure layer).
String getProtocolLockLabel(String? status) {
  return isProtocolLocked(status) ? 'Locked' : 'Editable';
}

/// Message when structure edits are blocked because the trial lifecycle is past setup.
String getProtocolLockMessage(String? status) {
  if (status == null || !isProtocolLocked(status)) return '';
  final label = labelForTrialStatus(status);
  return 'This custom trial is currently locked because the trial is $label. Structure cannot be changed.';
}

/// Legacy API: [workspaceType] is ignored; use [getProtocolLockMessage] only.
String getModeLockMessage(String? status, String? workspaceType) {
  return getProtocolLockMessage(status);
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
    return 'This custom trial has session data. Assignments cannot be changed.';
  }
  return '';
}

/// Full explanation when locked: what you cannot edit and what you can still do.
/// Use in status bar or help so users understand lock vs. unlock behavior.
String getProtocolLockExplanation(String? status) {
  if (status == null || !isProtocolLocked(status)) return '';
  return "You cannot add or edit: treatments, plots, assessments, or plot assignments. "
      "You can still: run sessions, record ratings, add plot notes, and export.";
}

/// True when trial structure (treatments, plots, assessments, assignments) may be edited.
/// ARM-linked trials are never structurally editable here. Otherwise, lifecycle must not be locked.
/// Structure mutations must use [assertCanEditProtocolForTrialId] (or this predicate) at repository/use-case layer.
bool canEditProtocol(Trial trial) {
  if (trial.isArmLinked == true) return false;
  return !isProtocolLocked(trial.status);
}

/// Trial type from ARM linkage only (not [Trial.workspaceType]).
String trialTypeLabel(Trial trial) {
  return trial.isArmLinked ? 'ARM-linked trial' : 'Custom trial';
}

/// Structure layer: whether treatments/plots/assessments may be edited (ARM or lifecycle).
String trialStructureStateLabel(Trial trial) {
  return canEditProtocol(trial) ? 'Structure editable' : 'Structure locked';
}

/// Compact type + structure state (e.g. chips, subtitles).
String trialTypeAndStructureCompactLine(Trial trial) {
  return '${trialTypeLabel(trial)} • ${trialStructureStateLabel(trial)}';
}

/// True when structure or assignment UI should block treatment/plot/assignment edits.
bool plotAssignmentsEditLocked(Trial trial, bool hasSessionData) {
  return !canEditProtocol(trial) ||
      isAssignmentsLocked(trial.status, hasSessionData);
}

/// Short label for the plots-tab assignment/structure chip.
String plotAssignmentsLockChipLabel(Trial trial, bool hasSessionData) {
  if (!canEditProtocol(trial)) {
    return trialTypeAndStructureCompactLine(trial);
  }
  if (isAssignmentsLocked(trial.status, hasSessionData)) {
    return '${trialTypeLabel(trial)} • ${getAssignmentsLockLabel(trial.status, hasSessionData)}';
  }
  return trialTypeAndStructureCompactLine(trial);
}

/// User-facing message when structure edits are blocked for ARM-linked trials.
const String kArmProtocolStructureLockMessage =
    'This trial is ARM-linked. Structure cannot be changed.';

String getArmProtocolLockMessage() => kArmProtocolStructureLockMessage;

/// Plot table notes: allowed when protocol is lifecycle-locked (e.g. active) but blocked for ARM-linked trials.
Future<void> assertPlotNotesEditableForTrialId(AppDatabase db, int trialId) async {
  final trial = await loadTrialForProtocolCheck(db, trialId);
  if (trial == null) {
    throw StateError('Trial not found');
  }
  if (trial.isArmLinked == true) {
    throw ProtocolEditBlockedException(getArmProtocolLockMessage());
  }
}

/// User-facing message when [canEditProtocol] is false (ARM-linked or lifecycle-locked).
String protocolEditBlockedMessage(Trial trial) {
  if (trial.isArmLinked) return getArmProtocolLockMessage();
  return getProtocolLockMessage(trial.status);
}

/// True if the trial has any ratings, notes, photos, or plot flags (any session).
///
/// Uses small Drift selects (not raw SQL) so results are correct inside nested
/// transactions (e.g. ARM import assigning plots before commit).
Future<bool> trialHasAnySessionData(AppDatabase db, int trialId) async {
  final rating = await (db.select(db.ratingRecords)
        ..where((r) => r.trialId.equals(trialId))
        ..limit(1))
      .getSingleOrNull();
  if (rating != null) return true;
  final note = await (db.select(db.notes)
        ..where((n) => n.trialId.equals(trialId))
        ..limit(1))
      .getSingleOrNull();
  if (note != null) return true;
  final photo = await (db.select(db.photos)
        ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
        ..limit(1))
      .getSingleOrNull();
  if (photo != null) return true;
  final flag = await (db.select(db.plotFlags)
        ..where((f) => f.trialId.equals(trialId))
        ..limit(1))
      .getSingleOrNull();
  return flag != null;
}

Future<Trial?> loadTrialForProtocolCheck(AppDatabase db, int trialId) {
  return (db.select(db.trials)
        ..where((t) => t.id.equals(trialId) & t.isDeleted.equals(false)))
      .getSingleOrNull();
}

/// Throws [ProtocolEditBlockedException] when structure edits are not allowed.
Future<void> assertCanEditProtocolForTrialId(AppDatabase db, int trialId) async {
  final trial = await loadTrialForProtocolCheck(db, trialId);
  if (trial == null) {
    throw StateError('Trial not found');
  }
  if (!canEditProtocol(trial)) {
    throw ProtocolEditBlockedException(protocolEditBlockedMessage(trial));
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
