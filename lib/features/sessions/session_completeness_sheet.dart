import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../plots/plot_queue_screen.dart';
import 'domain/session_completeness_report.dart';
import 'session_plot_predicates.dart';

void showSessionCompletenessSheet(
    BuildContext context, Trial trial, Session session) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CompletenessSheet(trial: trial, session: session),
  );
}

class _CompletenessSheet extends ConsumerStatefulWidget {
  const _CompletenessSheet({required this.trial, required this.session});
  final Trial trial;
  final Session session;

  @override
  ConsumerState<_CompletenessSheet> createState() => _CompletenessSheetState();
}

class _CompletenessSheetState extends ConsumerState<_CompletenessSheet> {
  bool _walkOrderLoaded = false;
  WalkOrderMode _walkOrderMode = WalkOrderMode.serpentine;
  List<int>? _customPlotIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalkOrder());
  }

  Future<void> _loadWalkOrder() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = SessionWalkOrderStore(prefs);
    final mode = store.getMode(widget.session.id);
    final customIds = mode == WalkOrderMode.custom
        ? store.getCustomOrder(widget.session.id)
        : null;
    setState(() {
      _walkOrderLoaded = true;
      _walkOrderMode = mode;
      _customPlotIds = customIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final session = widget.session;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final reportAsync = ref.watch(sessionCompletenessReportProvider(session.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync = ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (sheetContext, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignTokens.borderCrisp,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing16,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Text(
                    'Session Completeness',
                    style: AppDesignTokens.headingStyle(
                      fontSize: 16,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.view_list),
                    tooltip: 'Open full plot queue',
                    onPressed: () {
                      final nav = Navigator.of(sheetContext);
                      nav.pop();
                      nav.push<void>(MaterialPageRoute<void>(
                        builder: (_) =>
                            PlotQueueScreen(trial: trial, session: session),
                      ));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: plotsAsync.when(
                loading: () => const AppLoadingView(),
                error: (e, st) => AppErrorView(error: e, stackTrace: st),
                data: (rawPlots) => reportAsync.when(
                  loading: () => const AppLoadingView(),
                  error: (e, st) => AppErrorView(error: e, stackTrace: st),
                  data: (report) => ratingsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, st) => AppErrorView(error: e, stackTrace: st),
                    data: (ratings) => ratedPksAsync.when(
                      loading: () => const AppLoadingView(),
                      error: (e, st) =>
                          AppErrorView(error: e, stackTrace: st),
                      data: (ratedPks) => flaggedAsync.when(
                        loading: () => const AppLoadingView(),
                        error: (e, st) =>
                            AppErrorView(error: e, stackTrace: st),
                        data: (flaggedIds) => correctionsAsync.when(
                          loading: () => const AppLoadingView(),
                          error: (e, st) =>
                              AppErrorView(error: e, stackTrace: st),
                          data: (correctionPlotPks) => assessmentsAsync.when(
                            loading: () => const AppLoadingView(),
                            error: (e, st) =>
                                AppErrorView(error: e, stackTrace: st),
                            data: (assessments) {
                              if (!_walkOrderLoaded) {
                                return const AppLoadingView();
                              }
                              final expectedIds = {
                                for (final a in assessments) a.id
                              };
                              final sTotal = expectedIds.length;
                              final ratingsByPlot =
                                  <int, List<RatingRecord>>{};
                              for (final r in ratings) {
                                ratingsByPlot
                                    .putIfAbsent(r.plotPk, () => [])
                                    .add(r);
                              }
                              final plotBlocker = <int>{};
                              final plotWarning = <int>{};
                              for (final issue in report.issues) {
                                final pk = issue.plotPk;
                                if (pk == null) continue;
                                if (issue.severity ==
                                    SessionCompletenessIssueSeverity
                                        .blocker) {
                                  plotBlocker.add(pk);
                                } else {
                                  plotWarning.add(pk);
                                }
                              }
                              final counts = countPlotStatus(
                                plots: rawPlots,
                                ratingsByPlot: ratingsByPlot,
                                ratedPks: ratedPks,
                                flaggedIds: flaggedIds,
                                correctionPlotPks: correctionPlotPks,
                              );
                              final orderedPlots = sortPlotsByWalkOrder(
                                rawPlots,
                                _walkOrderMode,
                                customPlotIds: _customPlotIds,
                              );
                              return ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 24),
                                itemCount: orderedPlots.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return _SheetSummaryRow(
                                      report: report,
                                      ratedCount: counts.rated,
                                      notRatedCount: counts.unrated,
                                      flaggedCount: counts.flagged,
                                      issuesCount: counts.withIssues,
                                      editedCount: counts.edited,
                                      walkOrderLabel:
                                          SessionWalkOrderStore.labelForMode(
                                              _walkOrderMode),
                                    );
                                  }
                                  final plot = orderedPlots[index - 1];
                                  final plotRatings =
                                      ratingsByPlot[plot.id] ?? [];
                                  final isRated =
                                      plotIsRated(plot.id, ratedPks);
                                  final isFlagged =
                                      plotIsFlagged(plot.id, flaggedIds);
                                  final hasIssues =
                                      plotHasRatingIssues(plotRatings);
                                  final hasEdited = plotHasEdits(
                                    plotRatings,
                                    hasCorrection:
                                        correctionPlotPks.contains(plot.id),
                                  );
                                  int? c;
                                  int? s;
                                  if (sTotal > 0) {
                                    final coveredIds = plotRatings
                                        .where((r) => expectedIds
                                            .contains(r.assessmentId))
                                        .map((r) => r.assessmentId)
                                        .toSet();
                                    c = coveredIds.length;
                                    s = sTotal;
                                  }
                                  return _SheetPlotRow(
                                    plotLabel:
                                        getDisplayPlotLabel(plot, rawPlots),
                                    isRated: isRated,
                                    isFlagged: isFlagged,
                                    hasIssues: hasIssues,
                                    hasEdited: hasEdited,
                                    hasSessionBlocker:
                                        plotBlocker.contains(plot.id),
                                    hasSessionWarning:
                                        plotWarning.contains(plot.id),
                                    assessmentCovered: c,
                                    assessmentTotal: s,
                                    onOpenInPlotQueue: () {
                                      final nav = Navigator.of(sheetContext);
                                      nav.pop();
                                      nav.push<void>(
                                          MaterialPageRoute<void>(
                                        builder: (_) => PlotQueueScreen(
                                          trial: trial,
                                          session: session,
                                          scrollToPlotPkOnOpen: plot.id,
                                        ),
                                      ));
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SheetSummaryRow extends StatelessWidget {
  const _SheetSummaryRow({
    required this.report,
    required this.ratedCount,
    required this.notRatedCount,
    required this.flaggedCount,
    required this.issuesCount,
    required this.editedCount,
    required this.walkOrderLabel,
  });

  final SessionCompletenessReport report;
  final int ratedCount;
  final int notRatedCount;
  final int flaggedCount;
  final int issuesCount;
  final int editedCount;
  final String walkOrderLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progressPct = report.expectedPlots > 0
        ? ((report.completedPlots / report.expectedPlots) * 100).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(AppDesignTokens.spacing12),
        decoration: BoxDecoration(
          color: AppDesignTokens.sectionHeaderBg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${report.completedPlots}/${report.expectedPlots}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: report.canClose
                        ? Colors.green.shade700
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  report.canClose
                      ? 'Complete — ready to close'
                      : '$progressPct% complete',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: report.canClose
                        ? Colors.green.shade700
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (flaggedCount > 0)
                  _MiniChip(
                      label: '$flaggedCount flagged', color: Colors.amber),
                if (issuesCount > 0)
                  _MiniChip(
                      label: '$issuesCount issues', color: Colors.orange),
                if (editedCount > 0)
                  _MiniChip(
                      label: '$editedCount edited', color: Colors.blueGrey),
                if (notRatedCount > 0)
                  _MiniChip(
                      label: '$notRatedCount not rated', color: Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Walk order: $walkOrderLabel',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetPlotRow extends StatelessWidget {
  const _SheetPlotRow({
    required this.plotLabel,
    required this.isRated,
    required this.isFlagged,
    required this.hasIssues,
    required this.hasEdited,
    required this.hasSessionBlocker,
    required this.hasSessionWarning,
    this.assessmentCovered,
    this.assessmentTotal,
    required this.onOpenInPlotQueue,
  });

  final String plotLabel;
  final bool isRated;
  final bool isFlagged;
  final bool hasIssues;
  final bool hasEdited;
  final bool hasSessionBlocker;
  final bool hasSessionWarning;
  final int? assessmentCovered;
  final int? assessmentTotal;
  final VoidCallback onOpenInPlotQueue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        onTap: onOpenInPlotQueue,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            border: Border.all(color: AppDesignTokens.borderCrisp),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5A40),
                  borderRadius: BorderRadius.circular(
                      AppDesignTokens.radiusXSmall),
                ),
                child: Text(
                  plotLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    if (hasSessionBlocker)
                      const _MiniChip(label: 'Blocker', color: Colors.red),
                    if (hasSessionWarning)
                      const _MiniChip(label: 'Warning', color: Colors.amber),
                    _MiniChip(
                      label: isRated ? 'Rated' : 'Not Rated',
                      color: isRated ? Colors.green : Colors.grey,
                    ),
                    if (assessmentCovered != null && assessmentTotal != null)
                      _MiniChip(
                        label:
                            '$assessmentCovered/$assessmentTotal assessments',
                        color: assessmentCovered == assessmentTotal
                            ? Colors.green
                            : Colors.deepOrange,
                      ),
                    if (isFlagged)
                      const _MiniChip(label: 'Flagged', color: Colors.amber),
                    if (hasIssues)
                      const _MiniChip(label: 'Issues', color: Colors.orange),
                    if (hasEdited)
                      const _MiniChip(label: 'Edited', color: Colors.blueGrey),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}
