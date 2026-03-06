import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plot ${plot.plotId}',
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
                  _detailRow('Plot ID', plot.plotId),
                  if (plot.rep != null)
                    _detailRow('Rep / Block', plot.rep.toString()),
                  if (plot.row != null) _detailRow('Row', plot.row.toString()),
                  if (plot.column != null)
                    _detailRow('Column', plot.column.toString()),
                  if (plot.plotSortIndex != null)
                    _detailRow('Sort Index', plot.plotSortIndex.toString()),
                  _detailRow('Trial', trial.name),
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
                          Icon(Icons.history,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No ratings yet',
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
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
