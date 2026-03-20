import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'session_export_trust_messaging.dart';

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

  final metricLines = sessionExportTrustDialogBodyLines(
    noRatings: noRatings,
    unratedPlots: unratedPlots,
    issuesPlotCount: issuesPlotCount,
    editedPlotCount: editedPlotCount,
  );

  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
      return AlertDialog(
        title: const Text('Before you export'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kSessionExportTrustDialogIntro,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: muted,
                ),
              ),
              const SizedBox(height: 12),
              ...metricLines.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 8),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: muted.withValues(alpha: 0.6),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kSessionExportTrustEditedClarification,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: muted.withValues(alpha: 0.85),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
      );
    },
  );
  return go == true;
}
