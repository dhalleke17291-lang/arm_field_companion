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

/// True when [Trials.workspaceType] is standalone (custom trial, wizard or manual).
bool trialWorkspaceIsStandalone(String? workspaceType) =>
    workspaceType != null && workspaceType.trim().toLowerCase() == 'standalone';

/// Short lifecycle hints for standalone trials (no Draft/Ready workflow).
String statusDescriptionForStandalone(String? status) {
  switch (status) {
    case kTrialStatusActive:
      return 'Trial is active. Rate plots, capture data, add notes.';
    case kTrialStatusClosed:
      return 'Data collection complete. Corrections with reason allowed.';
    case kTrialStatusArchived:
      return 'Trial archived. Read-only.';
    default:
      return 'Trial is active.';
  }
}

/// Lifecycle description for UI: standalone uses [statusDescriptionForStandalone].
String statusDescriptionForTrialDisplay(
  String? status, {
  required String? workspaceType,
}) {
  if (trialWorkspaceIsStandalone(workspaceType)) {
    return statusDescriptionForStandalone(status);
  }
  return statusDescriptionForTrialStatus(status);
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
/// [hasSessionData] = true when the trial has ratings, photos, or plot flags — not field notes.
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

/// User-facing message when standalone Active is locked because ratings/photos/flags exist.
const String kStructureLockedDataCollectionStartedUserMessage =
    'Structure locked — data collection has started';

/// Repository / assert message when structure is locked after session data exists.
const String kTrialStructureLockedBecauseDataCollectionStarted =
    'Trial structure is locked because data collection has started.';

/// Whether trial structure (treatments, plots, assessments) can be edited.
/// Prefer over [canEditProtocol] when [hasSessionData] is known (UI, use cases with DB).
///
/// Standalone Active: editable until first rating / photo / plot flag.
/// Non-standalone: same as [canEditProtocol] (Draft/Ready editable; Active+ locked).
bool canEditTrialStructure(Trial trial, {required bool hasSessionData}) {
  if (trial.isArmLinked == true) return false;
  if (trial.status == kTrialStatusClosed ||
      trial.status == kTrialStatusArchived) {
    return false;
  }
  if (trialWorkspaceIsStandalone(trial.workspaceType) &&
      trial.status == kTrialStatusActive) {
    return !hasSessionData;
  }
  return !isProtocolLocked(trial.status);
}

/// Whether plot treatment assignments can be edited.
/// Standalone Active: same window as [canEditTrialStructure] (until first session data).
/// Non-standalone: not lifecycle-locked and no session data.
bool canEditAssignmentsForTrial(Trial trial, {required bool hasSessionData}) {
  if (trial.isArmLinked == true) return false;
  if (trial.status == kTrialStatusClosed ||
      trial.status == kTrialStatusArchived) {
    return false;
  }
  if (trialWorkspaceIsStandalone(trial.workspaceType) &&
      trial.status == kTrialStatusActive) {
    return !hasSessionData;
  }
  return !isProtocolLocked(trial.status) && !hasSessionData;
}

/// When structure edits are blocked, user-facing explanation (prefers standalone data message).
String structureEditBlockedMessage(
  Trial trial, {
  required bool hasSessionData,
}) {
  if (trial.isArmLinked) return getArmProtocolLockMessage();
  if (!canEditTrialStructure(trial, hasSessionData: hasSessionData)) {
    if (trialWorkspaceIsStandalone(trial.workspaceType) &&
        trial.status == kTrialStatusActive &&
        hasSessionData) {
      return kStructureLockedDataCollectionStartedUserMessage;
    }
    return protocolEditBlockedMessage(trial);
  }
  return '';
}

/// Trial type from ARM linkage only (not [Trial.workspaceType]).
String trialTypeLabel(Trial trial) {
  return trial.isArmLinked ? 'Imported trial' : 'Custom trial';
}

/// Structure layer: whether treatments/plots/assessments may be edited (ARM or lifecycle).
/// When [hasSessionData] is null, uses legacy [canEditProtocol] (pessimistic for standalone Active).
String trialStructureStateLabel(Trial trial, {bool? hasSessionData}) {
  final editable = hasSessionData == null
      ? canEditProtocol(trial)
      : canEditTrialStructure(trial, hasSessionData: hasSessionData);
  return editable ? 'Structure editable' : 'Structure locked';
}

/// Compact type + structure state (e.g. chips, subtitles).
/// When [hasSessionData] is null, uses legacy [canEditProtocol] for the structure line.
String trialTypeAndStructureCompactLine(Trial trial, {bool? hasSessionData}) {
  return '${trialTypeLabel(trial)} • ${trialStructureStateLabel(trial, hasSessionData: hasSessionData)}';
}

/// True when structure or assignment UI should block treatment/plot/assignment edits.
bool plotAssignmentsEditLocked(Trial trial, bool hasSessionData) {
  return !canEditTrialStructure(trial, hasSessionData: hasSessionData) ||
      !canEditAssignmentsForTrial(trial, hasSessionData: hasSessionData);
}

/// Short label for the plots-tab assignment/structure chip.
String plotAssignmentsLockChipLabel(Trial trial, bool hasSessionData) {
  if (!canEditTrialStructure(trial, hasSessionData: hasSessionData)) {
    return trialTypeAndStructureCompactLine(
      trial,
      hasSessionData: hasSessionData,
    );
  }
  if (!canEditAssignmentsForTrial(trial, hasSessionData: hasSessionData)) {
    return '${trialTypeLabel(trial)} • ${getAssignmentsLockLabel(trial.status, hasSessionData)}';
  }
  return trialTypeAndStructureCompactLine(
    trial,
    hasSessionData: hasSessionData,
  );
}

/// User-facing message when structure edits are blocked for ARM-linked trials.
const String kArmProtocolStructureLockMessage =
    'This trial is imported. Structure cannot be changed.';

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

/// True if the trial has any ratings, photos, or plot flags (any session).
/// [Notes] (field observations) are excluded so they do not lock assignments.
///
/// Uses small Drift selects (not raw SQL) so results are correct inside nested
/// transactions (e.g. ARM import assigning plots before commit).
Future<bool> trialHasAnySessionData(AppDatabase db, int trialId) async {
  final rating = await (db.select(db.ratingRecords)
        ..where((r) => r.trialId.equals(trialId))
        ..limit(1))
      .getSingleOrNull();
  if (rating != null) return true;
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
    throw StateError('Trial $trialId not found');
  }
  if (trial.isArmLinked == true) {
    throw ProtocolEditBlockedException(protocolEditBlockedMessage(trial));
  }
  if (trial.status == kTrialStatusClosed ||
      trial.status == kTrialStatusArchived) {
    throw ProtocolEditBlockedException(protocolEditBlockedMessage(trial));
  }
  if (trialWorkspaceIsStandalone(trial.workspaceType) &&
      trial.status == kTrialStatusActive) {
    final hasData = await trialHasAnySessionData(db, trialId);
    if (hasData) {
      throw ProtocolEditBlockedException(
        kTrialStructureLockedBecauseDataCollectionStarted,
      );
    }
    return;
  }
  if (isProtocolLocked(trial.status)) {
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

/// Next lifecycle step for [trial]: standalone skips Ready (Draft/Ready → Active only).
List<String> allowedNextTrialStatusesForTrial(String? status, Trial trial) {
  if (trialWorkspaceIsStandalone(trial.workspaceType)) {
    switch (status) {
      case kTrialStatusDraft:
      case kTrialStatusReady:
        return [kTrialStatusActive];
      case kTrialStatusActive:
        return [kTrialStatusClosed];
      case kTrialStatusClosed:
        return [kTrialStatusArchived];
      case kTrialStatusArchived:
        return [];
      default:
        return [kTrialStatusActive];
    }
  }
  return allowedNextTrialStatuses(status);
}
