import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../diagnostics/edited_items_screen.dart';
import '../plots/plot_queue_screen.dart';
import 'session_completeness_screen.dart';

void _navigatePlotQueue(
  BuildContext context,
  Trial trial,
  Session session, [
  PlotQueueInitialFilters? initialFilters,
]) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PlotQueueScreen(
        trial: trial,
        session: session,
        initialFilters: initialFilters,
      ),
    ),
  );
}

void _navigateSessionCompleteness(
    BuildContext context, Trial trial, Session session) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          SessionCompletenessScreen(trial: trial, session: session),
    ),
  );
}

/// Read-only aggregate dashboard for one session (v1: metrics + navigation links).
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  void _invalidate(WidgetRef ref) {
    ref.invalidate(plotsForTrialProvider(trial.id));
    ref.invalidate(sessionRatingsProvider(session.id));
    ref.invalidate(ratedPlotPksProvider(session.id));
    ref.invalidate(flaggedPlotIdsForSessionProvider(session.id));
    ref.invalidate(plotPksWithCorrectionsForSessionProvider(session.id));
    ref.invalidate(sessionAssessmentsProvider(session.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync = ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));
    final assessmentsAsync =
        ref.watch(sessionAssessmentsProvider(session.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Session Summary',
        subtitle: '${session.name} · ${session.sessionDateLocal}',
        titleFontSize: 17,
      ),
      body: SafeArea(
        child: plotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => _invalidate(ref),
          ),
          data: (rawPlots) => ratingsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: () => _invalidate(ref),
            ),
            data: (ratings) => ratedPksAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () => _invalidate(ref),
              ),
              data: (ratedPks) => flaggedAsync.when(
                loading: () => const AppLoadingView(),
                error: (e, st) => AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: () => _invalidate(ref),
                ),
                data: (flaggedIds) => correctionsAsync.when(
                  loading: () => const AppLoadingView(),
                  error: (e, st) => AppErrorView(
                    error: e,
                    stackTrace: st,
                    onRetry: () => _invalidate(ref),
                  ),
                  data: (correctionPlotPks) => assessmentsAsync.when(
                    loading: () => const AppLoadingView(),
                    error: (e, st) => AppErrorView(
                      error: e,
                      stackTrace: st,
                      onRetry: () => _invalidate(ref),
                    ),
                    data: (assessments) {
                      final expectedAssessmentIds =
                          {for (final a in assessments) a.id};
                      final sTotal = expectedAssessmentIds.length;

                      final ratingsByPlot = <int, List<RatingRecord>>{};
                      for (final r in ratings) {
                        ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                      }

                      var ratedCount = 0;
                      var notRatedCount = 0;
                      var flaggedCount = 0;
                      var issuesPlotCount = 0;
                      var editedPlotCount = 0;
                      var completeCount = 0;
                      var partialCount = 0;
                      var notStartedCount = 0;

                      for (final plot in rawPlots) {
                        final plotRatings = ratingsByPlot[plot.id] ?? [];
                        if (ratedPks.contains(plot.id)) {
                          ratedCount++;
                        } else {
                          notRatedCount++;
                        }
                        if (flaggedIds.contains(plot.id)) flaggedCount++;
                        if (plotRatings
                            .any((r) => r.resultStatus != 'RECORDED')) {
                          issuesPlotCount++;
                        }
                        if (plotRatings.any((r) =>
                                r.amended ||
                                (r.previousId != null)) ||
                            correctionPlotPks.contains(plot.id)) {
                          editedPlotCount++;
                        }

                        if (sTotal > 0) {
                          final coveredIds = plotRatings
                              .where((r) => expectedAssessmentIds
                                  .contains(r.assessmentId))
                              .map((r) => r.assessmentId)
                              .toSet();
                          final c = coveredIds.length;
                          if (c == 0) {
                            notStartedCount++;
                          } else if (c < sTotal) {
                            partialCount++;
                          } else {
                            completeCount++;
                          }
                        }
                      }

                      final total = rawPlots.length;
                      final progressPct = total > 0
                          ? ((100 * ratedCount) / total).round()
                          : null;

                      return ListView(
                        padding: const EdgeInsets.all(
                            AppDesignTokens.spacing16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              padding: const EdgeInsets.all(
                                  AppDesignTokens.spacing16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Open Plot Queue',
                                    child: InkWell(
                                      onTap: () => _navigatePlotQueue(
                                          context, trial, session),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _CardHeaderRow(
                                              title: 'Progress'),
                                          const SizedBox(height: 10),
                                          _MetricRow('Total plots', '$total'),
                                          _MetricRow(
                                              'Rated plots', '$ratedCount'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _MetricRow(
                                    'Not rated plots',
                                    '$notRatedCount',
                                    onTap: () => _navigatePlotQueue(
                                      context,
                                      trial,
                                      session,
                                      const PlotQueueInitialFilters(
                                          unratedOnly: true),
                                    ),
                                    semanticsLabel:
                                        'Open Plot Queue, unrated plots only',
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Open Plot Queue',
                                    child: InkWell(
                                      onTap: () => _navigatePlotQueue(
                                          context, trial, session),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10),
                                        child: Text(
                                          progressPct != null
                                              ? 'Progress: $progressPct%'
                                              : 'Progress: —',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              button: true,
                              label: 'Open Session Completeness',
                              child: GestureDetector(
                                onTap: () => _navigateSessionCompleteness(
                                    context, trial, session),
                                behavior: HitTestBehavior.opaque,
                                child: AppCard(
                                  padding: const EdgeInsets.all(
                                      AppDesignTokens.spacing16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _CardHeaderRow(
                                          title: 'Assessment coverage'),
                                      const SizedBox(height: 10),
                                      if (sTotal == 0)
                                        Text(
                                          'No assessments in this session.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        )
                                      else ...[
                                        _MetricRow('Complete plots',
                                            '$completeCount'),
                                        _MetricRow(
                                            'Partial plots', '$partialCount'),
                                        _MetricRow('Not started plots',
                                            '$notStartedCount'),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$sTotal assessments per plot',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        'Open Session Completeness for plot-by-plot coverage.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: AppCard(
                              padding: const EdgeInsets.all(
                                  AppDesignTokens.spacing16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Open Plot Queue',
                                    child: InkWell(
                                      onTap: () => _navigatePlotQueue(
                                          context, trial, session),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _CardHeaderRow(title: 'Attention'),
                                          SizedBox(height: 10),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _MetricRow(
                                    'Flagged plots',
                                    '$flaggedCount',
                                    onTap: () => _navigatePlotQueue(
                                      context,
                                      trial,
                                      session,
                                      const PlotQueueInitialFilters(
                                          flaggedOnly: true),
                                    ),
                                    semanticsLabel:
                                        'Open Plot Queue, flagged plots only',
                                  ),
                                  _MetricRow(
                                    'Plots with issues',
                                    '$issuesPlotCount',
                                    onTap: () => _navigatePlotQueue(
                                      context,
                                      trial,
                                      session,
                                      const PlotQueueInitialFilters(
                                          issuesOnly: true),
                                    ),
                                    semanticsLabel:
                                        'Open Plot Queue, plots with issues only',
                                  ),
                                  _MetricRow(
                                    'Edited plots',
                                    '$editedPlotCount',
                                    onTap: () => _navigatePlotQueue(
                                      context,
                                      trial,
                                      session,
                                      const PlotQueueInitialFilters(
                                          editedOnly: true),
                                    ),
                                    semanticsLabel:
                                        'Open Plot Queue, edited plots only',
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Open Plot Queue',
                                    child: InkWell(
                                      onTap: () => _navigatePlotQueue(
                                          context, trial, session),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10),
                                        child: Text(
                                          'Open Plot Queue and use filters to review flagged, issue, or edited plots.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            'Open related screens',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _navigateSessionCompleteness(
                                  context, trial, session),
                              child: const Text('Open Session Completeness'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _navigatePlotQueue(context, trial, session),
                              child: const Text('Open Plot Queue'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const EditedItemsScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Open Edited Items (trial-level)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppDesignTokens.primaryText,
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _SectionTitle(title)),
        Icon(
          Icons.chevron_right,
          size: 22,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(
    this.label,
    this.value, {
    this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}
