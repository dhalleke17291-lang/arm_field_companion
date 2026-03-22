// Centralized workspace type predicates for trial filtering.
// Keeps Custom vs Protocol separation explicit and future-safe.

/// Returns true when [workspaceType] is 'standalone' (custom trial).
bool isStandalone(String? workspaceType) {
  if (workspaceType == null || workspaceType.isEmpty) return false;
  return workspaceType.trim().toLowerCase() == 'standalone';
}

/// Returns true when [workspaceType] is a known protocol type.
/// Explicit allowlist: variety, efficacy, glp. Unknown values return false.
bool isProtocol(String? workspaceType) {
  if (workspaceType == null || workspaceType.isEmpty) return false;
  final wt = workspaceType.trim().toLowerCase();
  return wt == 'variety' || wt == 'efficacy' || wt == 'glp';
}
