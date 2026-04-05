/// Pre-close navigation / data-quality counts (non-guard plots only).
/// Matches former `_SessionCloseAttentionSummary` on [TrialDetailScreen].
class SessionCloseAttentionSummary {
  const SessionCloseAttentionSummary({
    required this.totalPlots,
    required this.ratedPlots,
    required this.unratedPlots,
    required this.flaggedPlots,
    required this.issuesPlots,
    required this.editedPlots,
  });

  final int totalPlots;
  final int ratedPlots;
  final int unratedPlots;
  final int flaggedPlots;
  final int issuesPlots;
  final int editedPlots;

  bool get needsAttention =>
      unratedPlots > 0 ||
      flaggedPlots > 0 ||
      issuesPlots > 0 ||
      editedPlots > 0;
}
