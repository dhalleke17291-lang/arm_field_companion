import '../../core/database/app_database.dart';

// ---------------------------------------------------------------------------
// Predicates
// ---------------------------------------------------------------------------

/// True if any current session rating for a plot has a non-RECORDED status
/// (void, skipped, deferred, etc.).
bool plotHasRatingIssues(List<RatingRecord> plotRatings) =>
    plotRatings.any((r) => r.resultStatus != 'RECORDED');

/// True if the plot has an amended or re-saved rating, or a correction entry.
///
/// [hasCorrection] is the caller's lookup of whether [correctionPlotPks]
/// contains this plot's pk — avoids passing the full set into every call.
bool plotHasEdits(List<RatingRecord> plotRatings, {required bool hasCorrection}) =>
    hasCorrection || plotRatings.any((r) => r.amended || r.previousId != null);

/// True if the plot has at least one rating recorded in the current session.
bool plotIsRated(int plotPk, Set<int> ratedPks) => ratedPks.contains(plotPk);

/// True if the plot is in the active flagged set for this session.
bool plotIsFlagged(int plotPk, Set<int> flaggedIds) =>
    flaggedIds.contains(plotPk);

// ---------------------------------------------------------------------------
// Count accumulator
// ---------------------------------------------------------------------------

/// Aggregated per-status counts across all [plots] for one session.
class SessionPlotCounts {
  const SessionPlotCounts({
    required this.total,
    required this.rated,
    required this.unrated,
    required this.flagged,
    required this.withIssues,
    required this.edited,
  });

  final int total;
  final int rated;
  final int unrated;
  final int flagged;

  /// Plots with at least one non-RECORDED rating.
  final int withIssues;

  /// Plots with at least one amended/corrected rating.
  final int edited;
}

/// Accumulates [SessionPlotCounts] across [plots] using pre-indexed lookup
/// structures. This replaces the identical for-loop in
/// SessionSummaryScreen and SessionCompletenessScreen.
SessionPlotCounts countPlotStatus({
  required List<Plot> plots,
  required Map<int, List<RatingRecord>> ratingsByPlot,
  required Set<int> ratedPks,
  required Set<int> flaggedIds,
  required Set<int> correctionPlotPks,
}) {
  var rated = 0;
  var flagged = 0;
  var withIssues = 0;
  var edited = 0;

  for (final plot in plots) {
    final plotRatings = ratingsByPlot[plot.id] ?? [];
    if (plotIsRated(plot.id, ratedPks)) rated++;
    if (plotIsFlagged(plot.id, flaggedIds)) flagged++;
    if (plotHasRatingIssues(plotRatings)) withIssues++;
    if (plotHasEdits(plotRatings,
        hasCorrection: correctionPlotPks.contains(plot.id))) {
      edited++;
    }
  }

  return SessionPlotCounts(
    total: plots.length,
    rated: rated,
    unrated: plots.length - rated,
    flagged: flagged,
    withIssues: withIssues,
    edited: edited,
  );
}

// ---------------------------------------------------------------------------
// Filter pipeline
// ---------------------------------------------------------------------------

/// Applies the active Plot Queue filter predicates to [plotsInWalkOrder].
///
/// Filters are applied in a stable order: rep → unrated → issues → edited →
/// flagged. The order matches [PlotQueueScreen._plotsAfterQueueFilters] so
/// that extracting this function does not change which plots are shown.
List<Plot> applyPlotQueueFilters({
  required List<Plot> plotsInWalkOrder,
  required Set<int> ratedPks,
  required Map<int, List<RatingRecord>> ratingsByPlot,
  required Set<int> flaggedIds,
  required Set<int> correctionPlotPks,
  int? repFilter,
  bool unratedOnly = false,
  bool issuesOnly = false,
  bool editedOnly = false,
  bool flaggedOnly = false,
}) {
  var filtered = plotsInWalkOrder;

  if (repFilter != null) {
    filtered = filtered.where((p) => p.rep == repFilter).toList();
  }
  if (unratedOnly) {
    filtered =
        filtered.where((p) => !plotIsRated(p.id, ratedPks)).toList();
  }
  if (issuesOnly) {
    filtered = filtered.where((p) {
      return plotHasRatingIssues(ratingsByPlot[p.id] ?? []);
    }).toList();
  }
  if (editedOnly) {
    filtered = filtered.where((p) {
      return plotHasEdits(
        ratingsByPlot[p.id] ?? [],
        hasCorrection: correctionPlotPks.contains(p.id),
      );
    }).toList();
  }
  if (flaggedOnly) {
    filtered =
        filtered.where((p) => plotIsFlagged(p.id, flaggedIds)).toList();
  }

  return filtered;
}
