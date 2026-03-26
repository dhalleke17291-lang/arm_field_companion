// Centralized workspace type predicates for trial filtering.
// Keeps Custom vs Protocol separation explicit and future-safe.

import 'workspace_config.dart';

// [isStandalone] / [isProtocol]: [workspaceTypeFromStringOrNull] may yield null for
// unknown or blank values. These predicates coerce null to [WorkspaceType.efficacy]
// before resolving [WorkspaceConfig], so trials are not excluded from *both*
// custom-only and protocol-only provider streams — unknown rows count as protocol.

/// Returns true when [workspaceType] is 'standalone' (custom trial).
///
/// Unknown, blank, or invalid values resolve to [WorkspaceType.efficacy] for
/// filtering (protocol), matching export and trial detail policy.
bool isStandalone(String? workspaceType) {
  final wt = workspaceTypeFromStringOrNull(workspaceType);
  final resolved = wt ?? WorkspaceType.efficacy;
  final config = WorkspaceConfig.forType(resolved);
  return config.isStandalone;
}

/// Returns true when [workspaceType] is a protocol trial (variety, efficacy, glp).
///
/// Unknown, blank, or invalid values resolve to [WorkspaceType.efficacy], so
/// they are treated as protocol.
bool isProtocol(String? workspaceType) {
  final wt = workspaceTypeFromStringOrNull(workspaceType);
  final resolved = wt ?? WorkspaceType.efficacy;
  final config = WorkspaceConfig.forType(resolved);
  return config.isProtocol;
}
