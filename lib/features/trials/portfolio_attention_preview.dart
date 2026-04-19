import 'package:collection/collection.dart';

import '../derived/trial_attention_service.dart';

/// Chooses the single attention line to show on portfolio tiles: highest severity among
/// items that are not [AttentionType.openSession] (open field work is called out separately).
AttentionItem? portfolioPrimaryAttentionLine(List<AttentionItem>? items) {
  if (items == null || items.isEmpty) return null;
  final skipOpen =
      items.where((i) => i.type != AttentionType.openSession).toList();
  if (skipOpen.isEmpty) return null;
  for (final sev in [
    AttentionSeverity.high,
    AttentionSeverity.medium,
    AttentionSeverity.low,
    AttentionSeverity.info,
  ]) {
    final m = skipOpen.where((i) => i.severity == sev).firstOrNull;
    if (m != null) return m;
  }
  return skipOpen.first;
}

/// How many non–open-session attention items exist beyond the one shown by
/// [portfolioPrimaryAttentionLine].
///
/// New [AttentionType] values are included in this count by default. If a type should not
/// inflate "+N more" (e.g. a duplicate or non-actionable summary row), exclude it in the
/// filter alongside [AttentionType.openSession].
int portfolioAdditionalAttentionCount(List<AttentionItem>? items) {
  if (items == null || items.isEmpty) return 0;
  final n = items.where((i) => i.type != AttentionType.openSession).length;
  return n > 1 ? n - 1 : 0;
}
