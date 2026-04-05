import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../domain/ratings/assessment_scale_resolver.dart';
import '../../domain/ratings/save_rating_input.dart';
import '../ratings/rating_scale_map.dart';
import '../ratings/usecases/save_rating_usecase.dart';
import 'plot_notes_dialog.dart';
import '../../core/widgets/app_standard_widgets.dart';

const List<String> _plotDirectionOptions = [
  'North',
  'South',
  'East',
  'West',
  'NE',
  'NW',
  'SE',
  'SW',
  'Other',
];

Future<void> _confirmAndSoftDeletePlot(
  BuildContext context,
  WidgetRef ref,
  Trial trial,
  Plot plot,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete plot'),
      content: const Text(
        'This plot will be moved to Recovery.\n\n'
        'Existing ratings for this plot are not deleted.\n\n'
        'The trial and sessions are unchanged.\n\n'
        'You can restore this plot later from Recovery.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete plot'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final user = await ref.read(currentUserProvider.future);
    final userId = await ref.read(currentUserIdProvider.future);
    await ref.read(plotRepositoryProvider).softDeletePlot(
          plot.id,
          deletedBy: user?.displayName,
          deletedByUserId: userId,
        );
    if (!context.mounted) return;
    final trialId = trial.id;
    final plotPk = plot.id;
    ref.invalidate(plotsForTrialProvider(trialId));
    ref.invalidate(deletedPlotsProvider);
    ref.invalidate(plotRatingHistoryProvider(
        PlotRatingParams(trialId: trialId, plotPk: plotPk)));
    ref.invalidate(plotContextProvider(plotPk));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Plot moved to Recovery')),
    );
  } catch (e) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Could not delete plot'),
        content: SelectableText('$e'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

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
                showPlotNotesDialog(context, ref, plotToShow, trial, sameTrialPlots: plots),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'delete_plot') {
                _confirmAndSoftDeletePlot(context, ref, trial, plot);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete_plot',
                child: Text('Delete plot'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    if (plotToShow.isGuardRow)
                      const StandardDetailRow(
                          label: 'Plot type', value: 'Guard row'),
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
                    if (_hasPlotDimensionSummary(plotToShow)) ...[
                      const Divider(),
                      _PlotDimensionSummary(plot: plotToShow),
                    ],
                    _PlotDetailsForm(
                      key: ValueKey('plot_details_${plotToShow.id}'),
                      plot: plotToShow,
                      trial: trial,
                      ref: ref,
                    ),
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
                          showPlotNotesDialog(context, ref, plotToShow, trial, sameTrialPlots: plots),
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
                                  : (ctx.hasRemovedTreatment
                                      ? '(removed)'
                                      : 'Unassigned')),
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
                                      Icon(Icons.circle,
                                          size: 6,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant),
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
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            const SizedBox(height: 12),
                            Text('No Ratings Yet',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(session?.name ?? 'Unknown session'),
                                    if (rating.amended) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _showAmendmentInfoSheet(
                                            context, ref, rating, assessment),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.orange.shade700),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text('Amended',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      rating.resultStatus == 'RECORDED'
                                          ? '${rating.numericValue ?? rating.textValue ?? "-"} ${assessment?.unit ?? ""}'
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
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                          minimumSize: Size.zero,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap),
                                      onPressed: () =>
                                          _showEditRatingSheet(context, ref,
                                              rating, assessment, trial, plot),
                                      child: const Text('Edit rating',
                                          style: TextStyle(fontSize: 12)),
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
            child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

void _showAmendmentInfoSheet(
  BuildContext context,
  WidgetRef ref,
  RatingRecord rating,
  Assessment? assessment,
) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Amendment details',
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _infoRow(ctx, 'Original value',
              rating.originalValue ?? (rating.numericValue?.toString() ?? rating.textValue ?? '—')),
          _infoRow(ctx, 'Current value',
              rating.numericValue?.toString() ?? rating.textValue ?? '—'),
          _infoRow(ctx, 'Amendment reason',
              rating.amendmentReason?.isNotEmpty == true
                  ? rating.amendmentReason!
                  : 'No reason recorded'),
          _infoRow(ctx, 'Amended by', rating.amendedBy ?? '—'),
          _infoRow(
              ctx,
              'Amended at',
              rating.amendedAt != null
                  ? rating.amendedAt!.toIso8601String()
                  : '—'),
        ],
      ),
    ),
  );
}

Widget _infoRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

({double min, double max}) _editRatingNumericBounds(
  Assessment? assessment, {
  AssessmentDefinitionScale? definitionScale,
}) {
  if (assessment == null) {
    return (min: 0.0, max: 999.0);
  }
  return resolvedNumericBoundsForAssessment(assessment, definitionScale);
}

Future<void> _showEditRatingSheet(
  BuildContext context,
  WidgetRef ref,
  RatingRecord rating,
  Assessment? assessment,
  Trial trial,
  Plot plot,
) async {
  String? lastRater = '';
  try {
    final prefs = await SharedPreferences.getInstance();
    lastRater = prefs.getString('last_rater_name');
  } catch (_) {}

  if (!context.mounted) return;
  final trialAssessments =
      ref.read(trialAssessmentsForTrialProvider(trial.id)).valueOrNull ??
          <TrialAssessment>[];
  final definitions =
      ref.read(assessmentDefinitionsProvider).valueOrNull ??
          <AssessmentDefinition>[];
  final ratingScaleMap = buildRatingScaleMap(
    trialAssessments: trialAssessments,
    definitions: definitions,
    trialIdForLog: trial.id,
  );
  final definitionScale =
      assessment != null ? ratingScaleMap[assessment.id] : null;

  final valueController = TextEditingController(
      text: rating.numericValue?.toString() ?? rating.textValue ?? '');
  final reasonController = TextEditingController();
  final amendedByController = TextEditingController(text: lastRater ?? '');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit rating',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: 'New value',
                hintText: assessment?.unit != null ? 'e.g. ${assessment?.unit}' : null,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Amendment reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amendedByController,
              decoration: const InputDecoration(
                labelText: 'Amended by',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final newValStr = valueController.text.trim();
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Amendment reason is required')));
                  return;
                }
                final session = await ref
                    .read(sessionRepositoryProvider)
                    .getSessionById(rating.sessionId);
                if (session == null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Session not found')));
                  }
                  return;
                }

                double? numericValue = rating.numericValue;
                String? textValue = rating.textValue;
                if (rating.resultStatus == 'RECORDED' &&
                    assessment?.dataType == 'numeric') {
                  final parsed = double.tryParse(newValStr);
                  if (parsed == null && newValStr.isNotEmpty) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid number')));
                    }
                    return;
                  }
                  if (parsed != null) {
                    final bounds = _editRatingNumericBounds(assessment,
                        definitionScale: definitionScale);
                    numericValue = parsed.clamp(bounds.min, bounds.max);
                  } else {
                    numericValue = rating.numericValue;
                  }
                  textValue = null;
                } else if (rating.resultStatus == 'RECORDED') {
                  numericValue = null;
                  textValue =
                      newValStr.isNotEmpty ? newValStr : rating.textValue;
                }

                final bounds = _editRatingNumericBounds(assessment,
                    definitionScale: definitionScale);
                final assessmentConstraints = assessment != null
                    ? RatingAssessmentConstraints(
                        dataType: assessment.dataType,
                        minValue: bounds.min,
                        maxValue: bounds.max,
                        unit: assessment.unit,
                      )
                    : null;

                final now = DateTime.now();
                final ratingTime =
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                try {
                  final userId = await ref.read(currentUserIdProvider.future);
                  final saveUseCase = ref.read(saveRatingUseCaseProvider);
                  final ratingRepo = ref.read(ratingRepositoryProvider);
                  final result = await saveUseCase.execute(SaveRatingInput(
                    trialId: rating.trialId,
                    plotPk: rating.plotPk,
                    assessmentId: rating.assessmentId,
                    sessionId: rating.sessionId,
                    resultStatus: rating.resultStatus,
                    numericValue: numericValue,
                    textValue: textValue,
                    subUnitId: rating.subUnitId,
                    raterName: session.raterName,
                    performedByUserId: userId,
                    isSessionClosed: session.endedAt != null,
                    minValue: bounds.min,
                    maxValue: bounds.max,
                    ratingTime: ratingTime,
                    assessmentConstraints: assessmentConstraints,
                  ));

                  if (!result.isSuccess) {
                    if (ctx.mounted) {
                      final msg = result.isDebounced
                          ? 'Please wait and try again'
                          : (result.errorMessage ?? 'Could not save rating');
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                    return;
                  }

                  final saved = result.rating!;
                  await ratingRepo.updateRating(
                    ratingId: saved.id,
                    amendmentReason: reason,
                    amendedBy: amendedByController.text.trim().isEmpty
                        ? null
                        : amendedByController.text.trim(),
                    lastEditedByUserId: userId,
                  );
                  if (ctx.mounted) {
                    ref.invalidate(plotRatingHistoryProvider(
                        PlotRatingParams(trialId: trial.id, plotPk: plot.id)));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Rating updated')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _hasPlotDimensionSummary(Plot plot) {
  return (plot.plotLengthM != null && plot.plotWidthM != null) ||
      (plot.harvestLengthM != null && plot.harvestWidthM != null);
}

class _PlotDimensionSummary extends StatelessWidget {
  const _PlotDimensionSummary({required this.plot});

  final Plot plot;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (plot.plotLengthM != null &&
        plot.plotWidthM != null &&
        plot.plotAreaM2 != null) {
      parts.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Plot: ${plot.plotLengthM} m × ${plot.plotWidthM} m = ${plot.plotAreaM2} m²',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }
    if (plot.harvestLengthM != null &&
        plot.harvestWidthM != null &&
        plot.harvestAreaM2 != null) {
      parts.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Harvest: ${plot.harvestLengthM} m × ${plot.harvestWidthM} m = ${plot.harvestAreaM2} m²',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts,
    );
  }
}

class _PlotDetailsForm extends ConsumerStatefulWidget {
  const _PlotDetailsForm({
    super.key,
    required this.plot,
    required this.trial,
    required this.ref,
  });

  final Plot plot;
  final Trial trial;
  final WidgetRef ref;

  @override
  ConsumerState<_PlotDetailsForm> createState() => _PlotDetailsFormState();
}

class _PlotDetailsFormState extends ConsumerState<_PlotDetailsForm> {
  late TextEditingController _plotLengthController;
  late TextEditingController _plotWidthController;
  late TextEditingController _plotAreaController;
  late TextEditingController _harvestLengthController;
  late TextEditingController _harvestWidthController;
  late TextEditingController _harvestAreaController;
  late TextEditingController _directionOtherController;
  late TextEditingController _soilSeriesController;
  late TextEditingController _plotNotesController;
  String? _directionDropdown;
  bool _plotAreaOverride = false;
  bool _harvestAreaOverride = false;
  bool _saving = false;
  bool _isGuardRow = false;
  bool _guardToggleBusy = false;

  @override
  void initState() {
    super.initState();
    _syncFromPlot(widget.plot);
  }

  @override
  void didUpdateWidget(covariant _PlotDetailsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plot.id == widget.plot.id &&
        (oldWidget.plot.plotLengthM != widget.plot.plotLengthM ||
            oldWidget.plot.plotNotes != widget.plot.plotNotes ||
            oldWidget.plot.isGuardRow != widget.plot.isGuardRow)) {
      _syncFromPlot(widget.plot);
    }
  }

  void _syncFromPlot(Plot plot) {
    _plotLengthController =
        TextEditingController(text: plot.plotLengthM?.toString() ?? '');
    _plotWidthController =
        TextEditingController(text: plot.plotWidthM?.toString() ?? '');
    _plotAreaController =
        TextEditingController(text: plot.plotAreaM2?.toString() ?? '');
    _harvestLengthController =
        TextEditingController(text: plot.harvestLengthM?.toString() ?? '');
    _harvestWidthController =
        TextEditingController(text: plot.harvestWidthM?.toString() ?? '');
    _harvestAreaController =
        TextEditingController(text: plot.harvestAreaM2?.toString() ?? '');
    _directionOtherController =
        TextEditingController(text: plot.plotDirection ?? '');
    _soilSeriesController =
        TextEditingController(text: plot.soilSeries ?? '');
    _plotNotesController =
        TextEditingController(text: plot.plotNotes ?? '');
    final dir = plot.plotDirection?.trim() ?? '';
    if (dir.isEmpty) {
      _directionDropdown = null;
    } else if (_plotDirectionOptions.contains(dir)) {
      _directionDropdown = dir;
      _directionOtherController.text = '';
    } else {
      _directionDropdown = 'Other';
      _directionOtherController.text = dir;
    }
    _plotAreaOverride = plot.plotAreaM2 != null &&
        plot.plotLengthM != null &&
        plot.plotWidthM != null &&
        (plot.plotAreaM2! - (plot.plotLengthM! * plot.plotWidthM!)).abs() > 0.001;
    _harvestAreaOverride = plot.harvestAreaM2 != null &&
        plot.harvestLengthM != null &&
        plot.harvestWidthM != null &&
        (plot.harvestAreaM2! -
                (plot.harvestLengthM! * plot.harvestWidthM!))
            .abs() > 0.001;
    _isGuardRow = plot.isGuardRow;
  }

  @override
  void dispose() {
    _plotLengthController.dispose();
    _plotWidthController.dispose();
    _plotAreaController.dispose();
    _harvestLengthController.dispose();
    _harvestWidthController.dispose();
    _harvestAreaController.dispose();
    _directionOtherController.dispose();
    _soilSeriesController.dispose();
    _plotNotesController.dispose();
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final s = c.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  int _dimensionsFilledCount() {
    int n = 0;
    if (_parseDouble(_plotLengthController) != null) n++;
    if (_parseDouble(_plotWidthController) != null) n++;
    if (_parseDouble(_plotAreaController) != null || _plotAreaOverride) n++;
    if (_parseDouble(_harvestLengthController) != null) n++;
    if (_parseDouble(_harvestWidthController) != null) n++;
    if (_parseDouble(_harvestAreaController) != null || _harvestAreaOverride) n++;
    if (_directionDropdown != null && _directionDropdown!.isNotEmpty) n++;
    return n;
  }

  int _fieldConditionsFilledCount() {
    int n = 0;
    if (_soilSeriesController.text.trim().isNotEmpty) n++;
    if (_plotNotesController.text.trim().isNotEmpty) n++;
    return n;
  }

  bool get _dimensionsHasData =>
      _dimensionsFilledCount() > 0;
  bool get _fieldConditionsHasData =>
      _fieldConditionsFilledCount() > 0;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final plotLen = _parseDouble(_plotLengthController);
      final plotWid = _parseDouble(_plotWidthController);
      final harvestLen = _parseDouble(_harvestLengthController);
      final harvestWid = _parseDouble(_harvestWidthController);
      double? plotArea = _plotAreaOverride
          ? _parseDouble(_plotAreaController)
          : (plotLen != null && plotWid != null ? plotLen * plotWid : null);
      double? harvestArea = _harvestAreaOverride
          ? _parseDouble(_harvestAreaController)
          : (harvestLen != null && harvestWid != null
              ? harvestLen * harvestWid
              : null);
      String? direction;
      if (_directionDropdown == 'Other') {
        direction = _directionOtherController.text.trim().isEmpty
            ? null
            : _directionOtherController.text.trim();
      } else if (_directionDropdown != null &&
          _directionDropdown!.isNotEmpty) {
        direction = _directionDropdown;
      }
      await ref.read(plotRepositoryProvider).updatePlotDetails(
            widget.plot.id,
            plotLengthM: plotLen,
            plotWidthM: plotWid,
            plotAreaM2: plotArea,
            harvestLengthM: harvestLen,
            harvestWidthM: harvestWid,
            harvestAreaM2: harvestArea,
            plotDirection: direction,
            soilSeries: _soilSeriesController.text.trim().isEmpty
                ? null
                : _soilSeriesController.text.trim(),
            plotNotes: _plotNotesController.text.trim().isEmpty
                ? null
                : _plotNotesController.text.trim(),
          );
      ref.invalidate(plotsForTrialProvider(widget.trial.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plot details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plotLen = _parseDouble(_plotLengthController);
    final plotWid = _parseDouble(_plotWidthController);
    final harvestLen = _parseDouble(_harvestLengthController);
    final harvestWid = _parseDouble(_harvestWidthController);
    final calculatedPlotArea = (plotLen != null && plotWid != null)
        ? plotLen * plotWid
        : null;
    final calculatedHarvestArea = (harvestLen != null && harvestWid != null)
        ? harvestLen * harvestWid
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          dense: true,
          title: const Text(
            'Guard row',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Border or buffer plot (label only)',
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          value: _isGuardRow,
          onChanged: _saving || _guardToggleBusy
              ? null
              : (v) async {
                  setState(() {
                    _isGuardRow = v;
                    _guardToggleBusy = true;
                  });
                  try {
                    await ref
                        .read(plotRepositoryProvider)
                        .updatePlotGuardRow(widget.plot.id, v);
                    ref.invalidate(plotsForTrialProvider(widget.trial.id));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          v ? 'Marked as guard row' : 'Guard row cleared',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isGuardRow = !v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Update failed: $e'),
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    );
                  } finally {
                    if (context.mounted) {
                      setState(() => _guardToggleBusy = false);
                    }
                  }
                },
        ),
        const Divider(height: 1),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          title: Text(
            'Plot dimensions (${_dimensionsFilledCount()} filled)',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          initiallyExpanded: _dimensionsHasData,
          children: [
            TextField(
              controller: _plotLengthController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Plot length (m)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plotWidthController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Plot width (m)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (calculatedPlotArea != null && !_plotAreaOverride)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Plot area: $calculatedPlotArea m²',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'calculated',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              title: const Text('Use custom plot area'),
              value: _plotAreaOverride,
              onChanged: (v) => setState(() => _plotAreaOverride = v),
            ),
            if (_plotAreaOverride) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _plotAreaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Plot area (m²)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _harvestLengthController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Harvest length (m)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _harvestWidthController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Harvest width (m)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (calculatedHarvestArea != null && !_harvestAreaOverride)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Harvest area: $calculatedHarvestArea m²',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'calculated',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              title: const Text('Use custom harvest area'),
              value: _harvestAreaOverride,
              onChanged: (v) => setState(() => _harvestAreaOverride = v),
            ),
            if (_harvestAreaOverride) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _harvestAreaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Harvest area (m²)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('dir_$_directionDropdown'),
              initialValue: _directionDropdown,
              decoration: const InputDecoration(
                labelText: 'Plot direction / orientation',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('—')),
                ..._plotDirectionOptions.map((s) =>
                    DropdownMenuItem<String?>(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _directionDropdown = v),
            ),
            if (_directionDropdown == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _directionOtherController,
                decoration: const InputDecoration(
                  labelText: 'Custom direction',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          title: Text(
            'Field conditions (${_fieldConditionsFilledCount()} filled)',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          initiallyExpanded: _fieldConditionsHasData,
          children: [
            TextField(
              controller: _soilSeriesController,
              decoration: const InputDecoration(
                labelText: 'Soil series',
                hintText: 'e.g. Weyburn loam',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plotNotesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Plot notes',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save plot details'),
        ),
      ],
    );
  }
}
