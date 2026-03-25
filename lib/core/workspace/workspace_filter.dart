// Centralized workspace type predicates for trial filtering.
// Keeps Custom vs Protocol separation explicit and future-safe.

import 'workspace_config.dart';

/// Returns true when [workspaceType] is 'standalone' (custom trial).
bool isStandalone(String? workspaceType) {
  final t = workspaceTypeFromStringOrNull(workspaceType);
  return t != null && WorkspaceConfig.forType(t).isStandalone;
}

/// Returns true when [workspaceType] is a known protocol type.
/// Explicit allowlist: variety, efficacy, glp. Unknown values return false.
bool isProtocol(String? workspaceType) {
  final t = workspaceTypeFromStringOrNull(workspaceType);
  return t != null && WorkspaceConfig.forType(t).isProtocol;
}
