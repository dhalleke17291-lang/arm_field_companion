import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';

class PlotDetailScreen extends ConsumerWidget {
  final Trial trial;
  final Plot plot;

  const PlotDetailScreen({
    super.key,
    required this.trial,
    required this.plot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(plotRatingHistoryProvider(
      PlotRatingParams(trialId: trial.id, plotPk: plot.id),
    ));
    final sessions = ref.watch(sessionsForTrialProvider(trial.id)).value ?? [];
    final assessments =
        ref.watch(assessmentsForTrialProvider(trial.id)).value ?? [];
    final plotContextAsync = ref.watch(plotContextProvider(plot.id));
    final plots = ref.watch(plotsForTrialProvider(trial.id)).value ?? [];
    final displayNum = getDisplayPlotLabel(plot, plots);
    final assignmentSourceLabel = getAssignmentSourceLabel(
        treatmentId: plot.treatmentId, assignmentSource: plot.assignmentSource);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plot $displayNum',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (plot.rep != null)
              Text('Rep ${plot.rep}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plot Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.primary)),
                  const Divider(),
                  _detailRow('Plot (display)', displayNum),
                  if (plot.rep != null)
                    _detailRow('Rep / Block', plot.rep.toString()),
                  if (assignmentSourceLabel != 'Unknown' && assignmentSourceLabel != 'Unassigned')
                    _detailRow('Assignment source', assignmentSourceLabel),
                  if (plot.row != null) _detailRow('Row', plot.row.toString()),
                  if (plot.column != null)
                    _detailRow('Column', plot.column.toString()),
                  if (plot.plotSortIndex != null)
                    _detailRow('Sort Index', plot.plotSortIndex.toString()),
                  _detailRow('Trial', trial.name),
                  const Divider(),
                  plotContextAsync.when(
                    loading: () => const SizedBox(
                      height: 20,
                      child: Center(child: LinearProgressIndicator(minHeight: 2)),
                    ),
                    error: (e, st) => _detailRow('Treatment', e.toString()),
                    data: (ctx) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Treatment', ctx.hasTreatment
                            ? '${ctx.treatmentCode}  —  ${ctx.treatmentName}'
                            : 'Unassigned'),
                        if (ctx.hasComponents) ...[
                          const SizedBox(height: 8),
                          Text('Components',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 4),
                          ...ctx.components.map((c) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 8),
                                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        [
                                          c.productName,
                                          if (c.rate != null && c.rateUnit != null)
                                            '${c.rate} ${c.rateUnit}',
                                          if (c.applicationTiming != null)
                                            c.applicationTiming!,
                                        ].join('  ·  '),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.history,
                    color: Theme.of(context).colorScheme.primary, size: 18),
                const SizedBox(width: 6),
                Text('Rating History',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ratingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (ratings) => ratings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No Ratings Yet',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: ratings.length,
                      itemBuilder: (context, index) {
                        final rating = ratings[index];
                        final session = sessions
                            .where((s) => s.id == rating.sessionId)
                            .firstOrNull;
                        final assessment = assessments
                            .where((a) => a.id == rating.assessmentId)
                            .firstOrNull;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: rating.resultStatus == 'RECORDED'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                rating.resultStatus == 'RECORDED'
                                    ? Icons.check
                                    : Icons.info_outline,
                                color: rating.resultStatus == 'RECORDED'
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              assessment?.name ?? 'Assessment',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(session?.name ?? 'Unknown session'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  rating.resultStatus == 'RECORDED'
                                      ? '${rating.numericValue ?? "-"} ${assessment?.unit ?? ""}'
                                      : rating.resultStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rating.resultStatus == 'RECORDED'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                Text(
                                  _formatDate(rating.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
