import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

/// Warning-only pre-export summary for session CSV / ARM XML. Does not block export.
Future<bool> confirmSessionExportTrust({
  required BuildContext context,
  required WidgetRef ref,
  required int trialId,
  required int sessionId,
}) async {
  final plots = await ref.read(plotsForTrialProvider(trialId).future);
  final ratedPks = await ref.read(ratedPlotPksProvider(sessionId).future);
  final ratings = await ref.read(sessionRatingsProvider(sessionId).future);
  final corrections =
      await ref.read(plotPksWithCorrectionsForSessionProvider(sessionId).future);

  final unratedPlots = plots.where((p) => !ratedPks.contains(p.id)).length;
  final noRatings = ratings.isEmpty;

  final ratingsByPlot = <int, List<RatingRecord>>{};
  for (final r in ratings) {
    ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
  }
  var issuesPlotCount = 0;
  var editedPlotCount = 0;
  for (final plot in plots) {
    final pr = ratingsByPlot[plot.id] ?? [];
    if (pr.any((r) => r.resultStatus != 'RECORDED')) {
      issuesPlotCount++;
    }
    if (pr.any((r) => r.amended || (r.previousId != null)) ||
        corrections.contains(plot.id)) {
      editedPlotCount++;
    }
  }

  final lines = <String>[];
  if (noRatings) {
    lines.add('No ratings in this session');
  } else {
    if (unratedPlots > 0) {
      lines.add('$unratedPlots plots not rated');
    }
    if (issuesPlotCount > 0) {
      lines.add('$issuesPlotCount plots have issues');
    }
    if (editedPlotCount > 0) {
      lines.add('$editedPlotCount plots edited');
    }
  }
  if (lines.isEmpty) {
    lines.add('No additional notes for this export');
  }

  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Before you export'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Export anyway'),
        ),
      ],
    ),
  );
  return go == true;
}
