import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/plot_sort.dart';
import '../../core/providers.dart';
import '../../core/session_walk_order_store.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../plots/plot_queue_screen.dart';
import 'domain/session_completeness_report.dart';
import 'session_plot_predicates.dart';

/// Read-only plot-level completeness; Phase 2: rows in session walk order (Plot Queue parity).
class SessionCompletenessScreen extends ConsumerStatefulWidget {
  const SessionCompletenessScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  @override
  ConsumerState<SessionCompletenessScreen> createState() =>
      _SessionCompletenessScreenState();
}

class _SessionCompletenessScreenState
    extends ConsumerState<SessionCompletenessScreen> {
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

  void _invalidateForRetry() {
    final t = widget.trial;
    final s = widget.session;
    ref.invalidate(plotsForTrialProvider(t.id));
    ref.invalidate(sessionRatingsProvider(s.id));
    ref.invalidate(ratedPlotPksProvider(s.id));
    ref.invalidate(flaggedPlotIdsForSessionProvider(s.id));
    ref.invalidate(plotPksWithCorrectionsForSessionProvider(s.id));
    ref.invalidate(sessionAssessmentsProvider(s.id));
    ref.invalidate(sessionCompletenessReportProvider(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final trial = widget.trial;
    final session = widget.session;
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final reportAsync =
        ref.watch(sessionCompletenessReportProvider(session.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));
    final assessmentsAsync = ref.watch(sessionAssessmentsProvider(session.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Session Completeness',
        subtitle: '${session.name} · ${session.sessionDateLocal}',
        titleFontSize: 17,
        actions: [
          Semantics(
            label: 'Open full plot queue, all plots',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.view_list, color: Colors.white),
              tooltip: 'Open full plot queue',
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PlotQueueScreen(
                      trial: trial,
                      session: session,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: plotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: _invalidateForRetry,
          ),
          data: (rawPlots) => reportAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: _invalidateForRetry,
            ),
            data: (report) => ratingsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: _invalidateForRetry,
              ),
              data: (ratings) => ratedPksAsync.when(
                loading: () => const AppLoadingView(),
                error: (e, st) => AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: _invalidateForRetry,
                ),
                data: (ratedPks) => flaggedAsync.when(
                  loading: () => const AppLoadingView(),
                  error: (e, st) => AppErrorView(
                    error: e,
                    stackTrace: st,
                    onRetry: _invalidateForRetry,
                  ),
                  data: (flaggedIds) => correctionsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, st) => AppErrorView(
                      error: e,
                      stackTrace: st,
                      onRetry: _invalidateForRetry,
                    ),
                    data: (correctionPlotPks) => assessmentsAsync.when(
                      loading: () => const AppLoadingView(),
                      error: (e, st) => AppErrorView(
                        error: e,
                        stackTrace: st,
                        onRetry: _invalidateForRetry,
                      ),
                      data: (assessments) {
                        if (!_walkOrderLoaded) {
                          return const AppLoadingView();
                        }
                        if (rawPlots.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  AppDesignTokens.spacing24),
                              child: Text(
                                'No plots in this trial.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }
                        final expectedAssessmentIds = {
                          for (final a in assessments) a.id
                        };
                        final sTotal = expectedAssessmentIds.length;

                        final ratingsByPlot = <int, List<RatingRecord>>{};
                        for (final r in ratings) {
                          ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                        }

                        final plotSessionBlocker = <int>{};
                        final plotSessionWarning = <int>{};
                        for (final issue in report.issues) {
                          final pk = issue.plotPk;
                          if (pk == null) continue;
                          if (issue.severity ==
                              SessionCompletenessIssueSeverity.blocker) {
                            plotSessionBlocker.add(pk);
                          } else {
                            plotSessionWarning.add(pk);
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

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SummaryStrip(
                              report: report,
                              totalPlots: counts.total,
                              ratedCount: counts.rated,
                              notRatedCount: counts.unrated,
                              flaggedCount: counts.flagged,
                              issuesCount: counts.withIssues,
                              editedCount: counts.edited,
                              showCoverageRowFootnote: sTotal > 0,
                              walkOrderLabel:
                                  SessionWalkOrderStore.labelForMode(
                                      _walkOrderMode),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: AppDesignTokens.spacing16,
                                  right: AppDesignTokens.spacing16,
                                  bottom: AppDesignTokens.spacing16,
                                ),
                                itemCount: orderedPlots.length,
                                itemBuilder: (context, index) {
                                  final plot = orderedPlots[index];
                                  final plotRatings =
                                      ratingsByPlot[plot.id] ?? [];
                                  final isRated = plotIsRated(plot.id, ratedPks);
                                  final isFlagged = plotIsFlagged(plot.id, flaggedIds);
                                  final hasIssues = plotHasRatingIssues(plotRatings);
                                  final hasEdited = plotHasEdits(
                                    plotRatings,
                                    hasCorrection: correctionPlotPks.contains(plot.id),
                                  );
                                  final label =
                                      getDisplayPlotLabel(plot, rawPlots);

                                  int? c;
                                  int? s;
                                  _AssessmentCoverageLabel? coverageLabel;
                                  if (sTotal > 0) {
                                    final coveredIds = plotRatings
                                        .where((r) => expectedAssessmentIds
                                            .contains(r.assessmentId))
                                        .map((r) => r.assessmentId)
                                        .toSet();
                                    c = coveredIds.length;
                                    s = sTotal;
                                    if (c == 0) {
                                      coverageLabel =
                                          _AssessmentCoverageLabel.notStarted;
                                    } else if (c < sTotal) {
                                      coverageLabel =
                                          _AssessmentCoverageLabel.partial;
                                    } else {
                                      coverageLabel =
                                          _AssessmentCoverageLabel.complete;
                                    }
                                  }

                                  return _PlotCompletenessRow(
                                    plotLabel: label,
                                    isRated: isRated,
                                    isFlagged: isFlagged,
                                    hasIssues: hasIssues,
                                    hasEdited: hasEdited,
                                    hasSessionBlocker:
                                        plotSessionBlocker.contains(plot.id),
                                    hasSessionWarning:
                                        plotSessionWarning.contains(plot.id),
                                    assessmentCovered: c,
                                    assessmentTotal: s,
                                    coverageLabel: coverageLabel,
                                    onOpenInPlotQueue: () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => PlotQueueScreen(
                                            trial: trial,
                                            session: session,
                                            scrollToPlotPkOnOpen: plot.id,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
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
    );
  }
}

enum _AssessmentCoverageLabel { complete, partial, notStarted }

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.report,
    required this.totalPlots,
    required this.ratedCount,
    required this.notRatedCount,
    required this.flaggedCount,
    required this.issuesCount,
    required this.editedCount,
    required this.showCoverageRowFootnote,
    required this.walkOrderLabel,
  });

  final SessionCompletenessReport report;
  final int totalPlots;
  final int ratedCount;
  final int notRatedCount;
  final int flaggedCount;
  final int issuesCount;
  final int editedCount;
  final bool showCoverageRowFootnote;
  final String walkOrderLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final guardsCount = totalPlots - report.expectedPlots;
    final progressFraction = report.expectedPlots > 0
        ? report.completedPlots / report.expectedPlots
        : 0.0;
    final progressPct = (progressFraction * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing12,
      ),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big progress line
          Row(
            children: [
              Text(
                '${report.completedPlots}/${report.expectedPlots}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: report.canClose
                      ? Colors.green.shade700
                      : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                report.canClose ? 'Complete — ready to close' : '$progressPct% complete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: report.canClose
                      ? Colors.green.shade700
                      : scheme.onSurface,
                ),
              ),
              const Spacer(),
              // Info icon with help dialog
              GestureDetector(
                onTap: () => _showHelpDialog(context),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (guardsCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Excludes $guardsCount guard plot${guardsCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Compact chips row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (flaggedCount > 0)
                _SummaryChip(label: '$flaggedCount flagged', color: Colors.amber),
              if (issuesCount > 0)
                _SummaryChip(label: '$issuesCount issues', color: Colors.orange),
              if (editedCount > 0)
                _SummaryChip(label: '$editedCount edited', color: Colors.blueGrey),
              if (notRatedCount > 0)
                _SummaryChip(
                  label: '$notRatedCount not rated',
                  color: Colors.grey,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Walk order: $walkOrderLabel',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Status Guide'),
        content: const SingleChildScrollView(
          child: Text(
            'Blocker — must be resolved before session can close.\n\n'
            'Warning — non-critical, review recommended.\n\n'
            'Partial / Not Started — assessment coverage per plot.\n\n'
            'Rated — plot has at least one current rating.\n\n'
            'Flagged — plot was flagged during rating.\n\n'
            'Issues — a rating has a non-recorded status.\n\n'
            'Edited — value was amended, corrected, or re-saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _PlotCompletenessRow extends StatelessWidget {
  const _PlotCompletenessRow({
    required this.plotLabel,
    required this.isRated,
    required this.isFlagged,
    required this.hasIssues,
    required this.hasEdited,
    required this.hasSessionBlocker,
    required this.hasSessionWarning,
    this.assessmentCovered,
    this.assessmentTotal,
    this.coverageLabel,
    required this.onOpenInPlotQueue,
  });

  /// Display label from [getDisplayPlotLabel].
  final String plotLabel;
  final bool isRated;
  final bool isFlagged;
  final bool hasIssues;
  final bool hasEdited;
  final bool hasSessionBlocker;
  final bool hasSessionWarning;
  final int? assessmentCovered;
  final int? assessmentTotal;
  final _AssessmentCoverageLabel? coverageLabel;
  final VoidCallback onOpenInPlotQueue;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.spacing8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5A40),
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusXSmall),
                ),
                child: Text(
                  plotLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: Text(
                  'Plot $plotLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          if (coverageLabel != null &&
              assessmentCovered != null &&
              assessmentTotal != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: '${assessmentCovered!}/${assessmentTotal!}',
                  fg: AppDesignTokens.primaryText,
                  bg: AppDesignTokens.sectionHeaderBg,
                  border: AppDesignTokens.borderCrisp,
                ),
                _StatusChip(
                  label: switch (coverageLabel!) {
                    _AssessmentCoverageLabel.complete => 'All Assessments',
                    _AssessmentCoverageLabel.partial => 'Partial',
                    _AssessmentCoverageLabel.notStarted => 'Not Started',
                  },
                  fg: switch (coverageLabel!) {
                    _AssessmentCoverageLabel.complete => Colors.green.shade800,
                    _AssessmentCoverageLabel.partial =>
                      Colors.deepOrange.shade800,
                    _AssessmentCoverageLabel.notStarted =>
                      AppDesignTokens.secondaryText,
                  },
                  bg: switch (coverageLabel!) {
                    _AssessmentCoverageLabel.complete => Colors.green.shade100,
                    _AssessmentCoverageLabel.partial =>
                      Colors.deepOrange.shade50,
                    _AssessmentCoverageLabel.notStarted =>
                      AppDesignTokens.emptyBadgeBg,
                  },
                  border: switch (coverageLabel!) {
                    _AssessmentCoverageLabel.complete => Colors.green.shade300,
                    _AssessmentCoverageLabel.partial =>
                      Colors.deepOrange.shade200,
                    _AssessmentCoverageLabel.notStarted =>
                      AppDesignTokens.borderCrisp,
                  },
                ),
              ],
            ),
          if (coverageLabel != null &&
              assessmentCovered != null &&
              assessmentTotal != null)
            const SizedBox(height: 6),
          if (hasSessionBlocker || hasSessionWarning) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (hasSessionBlocker)
                  _StatusChip(
                    label: 'Blocker',
                    fg: Colors.red.shade900,
                    bg: Colors.red.shade50,
                    border: Colors.red.shade400,
                  ),
                if (hasSessionWarning)
                  _StatusChip(
                    label: 'Warning',
                    fg: Colors.amber.shade900,
                    bg: Colors.amber.shade100,
                    border: Colors.amber.shade700,
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: isRated ? 'Rated' : 'Not Rated',
                fg: isRated
                    ? Colors.green.shade800
                    : AppDesignTokens.secondaryText,
                bg: isRated
                    ? Colors.green.shade100
                    : AppDesignTokens.emptyBadgeBg,
                border: isRated
                    ? Colors.green.shade300
                    : AppDesignTokens.borderCrisp,
              ),
              if (isFlagged)
                _StatusChip(
                  label: 'Flagged',
                  fg: Colors.amber.shade900,
                  bg: Colors.amber.shade100,
                  border: Colors.amber.shade400,
                ),
              if (hasIssues)
                _StatusChip(
                  label: 'Issues',
                  fg: Colors.orange.shade800,
                  bg: Colors.orange.shade100,
                  border: Colors.orange.shade300,
                ),
              if (hasEdited)
                _StatusChip(
                  label: 'Edited',
                  fg: Colors.blueGrey.shade800,
                  bg: Colors.blueGrey.shade50,
                  border: Colors.blueGrey.shade200,
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppDesignTokens.spacing8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          onTap: onOpenInPlotQueue,
          child: card,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}
