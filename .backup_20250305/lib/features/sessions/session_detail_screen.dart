import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../export/data/export_repository.dart';
import '../export/domain/export_session_csv_usecase.dart';
import 'package:share_plus/share_plus.dart';

class SessionDetailScreen extends ConsumerWidget {
  final Trial trial;
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final assessmentsAsync =
        ref.watch(sessionAssessmentsProvider(session.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text(session.sessionDateLocal,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
      ),
      body: plotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (plots) => ratingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (ratings) => assessmentsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (assessments) => _buildContent(
                context, plots, ratings, assessments),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final repo = ExportRepository(db);
    final usecase = ExportSessionCsvUsecase(repo);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...')),
      );

      final result = await usecase.exportSessionToCsv(
        sessionId: session.id,
        trialName: trial.name,
        sessionName: session.name,
        sessionDateLocal: session.sessionDateLocal,
        sessionRaterName: session.raterName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.rowCount} ratings exported'),
                const SizedBox(height: 8),
                const Text('Saved to:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(result.filePath,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.shareXFiles(
                    [XFile(result.filePath)],
                    subject: '${trial.name} - ${session.name} Export',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildContent(
    BuildContext context,
    List<Plot> plots,
    List<RatingRecord> ratings,
    List<Assessment> assessments,
  ) {
    final ratedPks = ratings.map((r) => r.plotPk).toSet();
    final ratedCount = ratedPks.length;

    return Column(
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '$ratedCount / ${plots.length} plots rated',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
        // Export CSV (closed session)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Consumer(builder: (context, ref, _) {
            return ElevatedButton.icon(
              onPressed: () async {
                try {
                  final usecase = ref.read(exportSessionCsvUsecaseProvider);
                  final result = await usecase.exportSessionToCsv(
                    sessionId: session.id,
                    trialName: trial.name,
                    sessionName: session.name,
                    sessionDateLocal: session.sessionDateLocal,
                    sessionRaterName: session.raterName,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Exported ${result.rowCount} rows to: ${result.filePath}',
                        ),
                      ),
                    );
                  // Share the exported CSV (AirDrop/Email/Files/Drive)
                  await Share.shareXFiles(
                    [XFile(result.filePath)],
                    text: 'Ag-Quest Field Companion export: ${trial.name} / ${session.name}',
                  );

                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            );
          }),
        ),

              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('CLOSED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Assessment chips
        if (assessments.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              itemCount: assessments.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(assessments[index].name,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),

        // Plot ratings list
        Expanded(
          child: ListView.builder(
            itemCount: plots.length,
            itemBuilder: (context, index) {
              final plot = plots[index];
              final plotRatings =
                  ratings.where((r) => r.plotPk == plot.id).toList();
              final isRated = plotRatings.isNotEmpty;

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isRated
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    child: isRated
                        ? const Icon(Icons.check, color: Colors.green)
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.grey),
                  ),
                  title: Text('Plot ${plot.plotId}',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: plot.rep != null
                      ? Text('Rep ${plot.rep}')
                      : null,
                  children: plotRatings.isEmpty
                      ? [
                          const ListTile(
                            title: Text('Not rated',
                                style: TextStyle(color: Colors.grey)),
                          )
                        ]
                      : plotRatings.map((rating) {
                          final assessment = assessments
                              .where((a) => a.id == rating.assessmentId)
                              .firstOrNull;
                          return ListTile(
                            dense: true,
                            title: Text(
                                assessment?.name ?? 'Assessment'),
                            trailing: Text(
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
                          );
                        }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
