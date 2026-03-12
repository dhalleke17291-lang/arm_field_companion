// Pure calculation functions for derived values (Lab/Derived/Diagnostics MVP).
// No I/O; no overwriting of raw evidence. Used by DerivedSnapshot cache.

/// Session progress: fraction of plots with at least one current rating in the session.
/// Returns 0.0–1.0; 1.0 when [ratedPlotCount] == [totalPlotCount] (and total > 0).
double sessionProgressFraction(int ratedPlotCount, int totalPlotCount) {
  if (totalPlotCount <= 0) return 0.0;
  final r = ratedPlotCount.clamp(0, totalPlotCount);
  return r / totalPlotCount;
}

/// Session progress as percentage 0–100.
double sessionProgressPct(int ratedPlotCount, int totalPlotCount) {
  return sessionProgressFraction(ratedPlotCount, totalPlotCount) * 100.0;
}

/// Trial-level completeness: fraction of sessions that are closed.
/// Returns 0.0–1.0.
double trialSessionsClosedFraction(int closedCount, int totalSessionCount) {
  if (totalSessionCount <= 0) return 0.0;
  final c = closedCount.clamp(0, totalSessionCount);
  return c / totalSessionCount;
}
