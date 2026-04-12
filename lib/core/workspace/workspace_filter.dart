// Centralized workspace type predicates for Custom vs Protocol filtered lists and hub stats.
// Stored workspaceType is non-nullable in the DB with an efficacy default.
// Null or blank arguments here are defensive (nullable API); unrecognized strings
// indicate legacy or bad data, not normal app flow. See [trialsStreamProvider] for all trials.

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
