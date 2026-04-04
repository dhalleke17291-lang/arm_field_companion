// Centralized workspace type predicates for Custom vs Protocol filtered lists and hub stats.
// Recognized values only; null, blank, or unknown strings match neither list (see [trialsStreamProvider] for all trials).

import 'workspace_config.dart';

/// True when [workspaceType] parses to [WorkspaceType.standalone] (Custom list / hub).
///
/// Null, blank, or unrecognized values → false (trial appears in "All Trials" only).
bool isStandalone(String? workspaceType) {
  return workspaceTypeFromStringOrNull(workspaceType) == WorkspaceType.standalone;
}

/// True when [workspaceType] parses to variety, efficacy, or glp (Protocol list / hub).
///
/// Null, blank, or unrecognized values → false (trial appears in "All Trials" only).
bool isProtocol(String? workspaceType) {
  final wt = workspaceTypeFromStringOrNull(workspaceType);
  return wt == WorkspaceType.variety ||
      wt == WorkspaceType.efficacy ||
      wt == WorkspaceType.glp;
}
