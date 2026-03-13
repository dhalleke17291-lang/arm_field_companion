import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import 'plot_notes_dialog.dart';
import '../../core/widgets/app_standard_widgets.dart';

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
    final assignments =
        ref.watch(assignmentsForTrialProvider(trial.id)).value ?? [];
    final assignmentForPlot =
        assignments.where((a) => a.plotId == plot.id).firstOrNull;
    final plotToShow = plots.where((p) => p.id == plot.id).firstOrNull ?? plot;
    final displayNum = getDisplayPlotLabel(plotToShow, plots);
    final assignmentSourceLabel = getAssignmentSourceLabel(
        treatmentId: assignmentForPlot?.treatmentId ?? plotToShow.treatmentId,
        assignmentSource:
            assignmentForPlot?.assignmentSource ?? plotToShow.assignmentSource);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: 'Plot $displayNum',
        subtitle: plotToShow.rep != null ? 'Rep ${plotToShow.rep}' : null,
        titleFontSize: 17,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Notes',
            onPressed: () =>
                showPlotNotesDialog(context, ref, plotToShow, trial),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Card(
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
                    StandardDetailRow(
                        label: 'Plot (display)', value: displayNum),
                    if (plotToShow.rep != null)
                      StandardDetailRow(
                          label: 'Rep / Block',
                          value: plotToShow.rep.toString()),
                    if (assignmentSourceLabel != 'Unknown' &&
                        assignmentSourceLabel != 'Unassigned')
                      StandardDetailRow(
                          label: 'Assignment source',
                          value: assignmentSourceLabel),
                    if (plotToShow.row != null)
                      StandardDetailRow(
                          label: 'Range', value: plotToShow.row.toString()),
                    if (plotToShow.column != null)
                      StandardDetailRow(
                          label: 'Column', value: plotToShow.column.toString()),
                    if (plotToShow.plotSortIndex != null)
                      StandardDetailRow(
                          label: 'Sort Index',
                          value: plotToShow.plotSortIndex.toString()),
                    StandardDetailRow(label: 'Trial', value: trial.name),
                    if (trial.plotDimensions != null ||
                        trial.plotRows != null ||
                        trial.plotSpacing != null) ...[
                      const Divider(),
                      if (trial.plotDimensions != null)
                        StandardDetailRow(
                            label: 'Plot dimensions',
                            value: trial.plotDimensions!),
                      if (trial.plotRows != null)
                        StandardDetailRow(
                            label: 'Number of ranges',
                            value: trial.plotRows.toString()),
                      if (trial.plotSpacing != null)
                        StandardDetailRow(
                            label: 'Plot spacing', value: trial.plotSpacing!),
                    ],
                    const Divider(),
                    if (plotToShow.notes != null &&
                        plotToShow.notes!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notes',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                            const SizedBox(height: 4),
                            Text(
                              plotToShow.notes!.trim(),
                              style: const TextStyle(fontSize: 13),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )
                    else
                      const StandardDetailRow(
                          label: 'Notes', value: 'No notes'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text(plotToShow.notes?.trim().isNotEmpty == true
                          ? 'Edit Notes'
                          : 'Add Notes'),
                      onPressed: () =>
                          showPlotNotesDialog(context, ref, plotToShow, trial),
                    ),
                    const Divider(),
                    plotContextAsync.when(
                      loading: () => const SizedBox(
                        height: 20,
                        child: Center(
                            child: LinearProgressIndicator(minHeight: 2)),
                      ),
                      error: (e, st) => StandardDetailRow(
                          label: 'Treatment', value: e.toString()),
                      data: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StandardDetailRow(
                              label: 'Treatment',
                              value: ctx.hasTreatment
                                  ? '${ctx.treatmentCode}  —  ${ctx.treatmentName}'
                                  : 'Unassigned'),
                          if (ctx.hasComponents) ...[
                            const SizedBox(height: 8),
                            Text('Components',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                            const SizedBox(height: 4),
                            ...ctx.components.map((c) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 8),
                                      const Icon(Icons.circle,
                                          size: 6, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          [
                                            c.productName,
                                            if (c.rate != null &&
                                                c.rateUnit != null)
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ...ratingsAsync.when(
            loading: () => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, st) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Error: $e')),
              ),
            ],
            data: (ratings) => ratings.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No Ratings Yet',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
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
                                  backgroundColor:
                                      rating.resultStatus == 'RECORDED'
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle:
                                    Text(session?.name ?? 'Unknown session'),
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
                          childCount: ratings.length,
                        ),
                      ),
                    ),
                  ],
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
