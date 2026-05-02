import '../derived/trial_attention_service.dart';

void _sortAttentionTier(List<AttentionItem> tier) {
  tier.sort((a, b) {
    final c = a.type.index.compareTo(b.type.index);
    if (c != 0) return c;
    return a.label.compareTo(b.label);
  });
}

/// Chooses the single attention line for portfolio tiles.
///
/// [usedLabels] tracks primary labels already chosen for **earlier** trials in the same
/// list. Prefer the first unused item in severity order (high → info), but within each
/// severity tier candidates are **rotated** by [trialId] so identical issues across
/// trials surface different lines when possible. If every label in a tier was already
/// used on a prior card, the next severity tier is tried. If all labels are exhausted,
/// falls back to a stable [trialId]-indexed pick from all non-open items.
///
/// New [AttentionType] values participate unless excluded alongside [AttentionType.openSession].
AttentionItem? portfolioPrimaryAttentionLineDeduped(
  List<AttentionItem>? items,
  int trialId,
  Set<String> usedLabels,
) {
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
    final tier = skipOpen.where((i) => i.severity == sev).toList();
    if (tier.isEmpty) continue;
    _sortAttentionTier(tier);
    final start = trialId.abs() % tier.length;
    final rotated = <AttentionItem>[
      ...tier.sublist(start),
      ...tier.sublist(0, start),
    ];
    for (final c in rotated) {
      if (!usedLabels.contains(c.label)) {
        usedLabels.add(c.label);
        return c;
      }
    }
  }

  final sorted = skipOpen.toList();
  _sortAttentionTier(sorted);
  return sorted[trialId.abs() % sorted.length];
}

/// Non-list contexts: same as [portfolioPrimaryAttentionLineDeduped] with an empty set.
AttentionItem? portfolioPrimaryAttentionLine(
  List<AttentionItem>? items, {
  int trialId = 0,
}) {
  return portfolioPrimaryAttentionLineDeduped(items, trialId, <String>{});
}

/// How many non–open-session, non-info attention items exist beyond the one shown by
/// [portfolioPrimaryAttentionLine] / [portfolioPrimaryAttentionLineDeduped].
///
/// Info-severity items (positive confirmations) are excluded so they do not
/// inflate the "+N more" count on portfolio tiles.
int portfolioAdditionalAttentionCount(List<AttentionItem>? items) {
  if (items == null || items.isEmpty) return 0;
  final n = items
      .where((i) =>
          i.type != AttentionType.openSession &&
          i.severity != AttentionSeverity.info)
      .length;
  return n > 1 ? n - 1 : 0;
}
