/// Immutable snapshot of derived values for a session (Lab/Derived MVP).
/// [calcVersion] allows cache invalidation when underlying data changes.
class DerivedSnapshot {
  const DerivedSnapshot({
    required this.sessionId,
    required this.calcVersion,
    required this.ratedPlotCount,
    required this.totalPlotCount,
    required this.progressFraction,
  });

  final int sessionId;

  /// Version for cache invalidation (e.g. timestamp or hash of inputs).
  final int calcVersion;
  final int ratedPlotCount;
  final int totalPlotCount;

  /// 0.0–1.0 session progress.
  final double progressFraction;

  double get progressPct => progressFraction * 100.0;
}
