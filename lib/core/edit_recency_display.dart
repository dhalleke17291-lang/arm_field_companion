import 'package:intl/intl.dart';

import 'database/app_database.dart';

/// Latest edit-recency instant for one plot’s session ratings, aligned with
/// how plots qualify as “edited” (amend/chain vs correction-only).
///
/// **Amended or re-saved (previousId):** per rating,
/// `lastEditedAt ?? amendedAt ?? createdAt`.
///
/// **Correction-only** (plot in corrections set but no amend/chain on any
/// rating): only `lastEditedAt` on any rating counts; otherwise returns null
/// (no invented timestamp).
///
/// When both paths apply, returns the latest of all contributing instants.
DateTime? latestEditRecencyForPlot(
  List<RatingRecord> plotRatings,
  bool plotHasCorrection,
) {
  DateTime? best;
  void pick(DateTime t) {
    final b = best;
    if (b == null || t.isAfter(b)) best = t;
  }

  for (final r in plotRatings) {
    if (r.amended || r.previousId != null) {
      pick(r.lastEditedAt ?? r.amendedAt ?? r.createdAt);
    }
  }

  if (plotHasCorrection) {
    for (final r in plotRatings) {
      final le = r.lastEditedAt;
      if (le != null) pick(le);
    }
  }

  return best;
}

/// Max recency across plots that are “edited” by the same rules as
/// [SessionSummaryScreen] / Plot Queue (amend, chain, or correction plot set).
DateTime? latestEditRecencyAcrossEditedPlots({
  required Iterable<Plot> plots,
  required Map<int, List<RatingRecord>> ratingsByPlot,
  required Set<int> correctionPlotPks,
}) {
  DateTime? best;
  for (final plot in plots) {
    final pr = ratingsByPlot[plot.id] ?? [];
    final isEdited = pr.any((r) => r.amended || (r.previousId != null)) ||
        correctionPlotPks.contains(plot.id);
    if (!isEdited) continue;
    final t = latestEditRecencyForPlot(pr, correctionPlotPks.contains(plot.id));
    if (t != null) {
      final b = best;
      if (b == null || t.isAfter(b)) best = t;
    }
  }
  return best;
}

String formatEditRecencyCompact(DateTime t) =>
    DateFormat('MMM d, h:mm a').format(t.toLocal());

String formatEditRecencyWithYear(DateTime t) =>
    DateFormat('MMM d, yyyy, h:mm a').format(t.toLocal());
