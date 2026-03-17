import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import '../../core/widgets/loading_error_widgets.dart';

/// Phase 1: read-only plot-level completeness for one session (trial plot order).
class SessionCompletenessScreen extends ConsumerWidget {
  const SessionCompletenessScreen({
    super.key,
    required this.trial,
    required this.session,
  });

  final Trial trial;
  final Session session;

  void _invalidateForRetry(WidgetRef ref) {
    ref.invalidate(plotsForTrialProvider(trial.id));
    ref.invalidate(sessionRatingsProvider(session.id));
    ref.invalidate(ratedPlotPksProvider(session.id));
    ref.invalidate(flaggedPlotIdsForSessionProvider(session.id));
    ref.invalidate(plotPksWithCorrectionsForSessionProvider(session.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final ratingsAsync = ref.watch(sessionRatingsProvider(session.id));
    final ratedPksAsync = ref.watch(ratedPlotPksProvider(session.id));
    final flaggedAsync = ref.watch(flaggedPlotIdsForSessionProvider(session.id));
    final correctionsAsync =
        ref.watch(plotPksWithCorrectionsForSessionProvider(session.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: GradientScreenHeader(
        title: 'Session Completeness',
        subtitle: '${session.name} · ${session.sessionDateLocal}',
        titleFontSize: 17,
      ),
      body: SafeArea(
        child: plotsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => _invalidateForRetry(ref),
          ),
          data: (plots) => ratingsAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: () => _invalidateForRetry(ref),
            ),
            data: (ratings) => ratedPksAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () => _invalidateForRetry(ref),
              ),
              data: (ratedPks) => flaggedAsync.when(
                loading: () => const AppLoadingView(),
                error: (e, st) => AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: () => _invalidateForRetry(ref),
                ),
                data: (flaggedIds) => correctionsAsync.when(
                  loading: () => const AppLoadingView(),
                  error: (e, st) => AppErrorView(
                    error: e,
                    stackTrace: st,
                    onRetry: () => _invalidateForRetry(ref),
                  ),
                  data: (correctionPlotPks) {
                    if (plots.isEmpty) {
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
                    final ratingsByPlot = <int, List<RatingRecord>>{};
                    for (final r in ratings) {
                      ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
                    }

                    var ratedCount = 0;
                    var notRatedCount = 0;
                    var flaggedCount = 0;
                    var issuesCount = 0;
                    var editedCount = 0;

                    for (final plot in plots) {
                      final plotRatings = ratingsByPlot[plot.id] ?? [];
                      final isRated = ratedPks.contains(plot.id);
                      if (isRated) {
                        ratedCount++;
                      } else {
                        notRatedCount++;
                      }
                      if (flaggedIds.contains(plot.id)) flaggedCount++;
                      final hasIssues = plotRatings
                          .any((r) => r.resultStatus != 'RECORDED');
                      if (hasIssues) issuesCount++;
                      final hasEdited = plotRatings.any((r) =>
                              r.amended ||
                              (r.previousId != null)) ||
                          correctionPlotPks.contains(plot.id);
                      if (hasEdited) editedCount++;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryStrip(
                          totalPlots: plots.length,
                          ratedCount: ratedCount,
                          notRatedCount: notRatedCount,
                          flaggedCount: flaggedCount,
                          issuesCount: issuesCount,
                          editedCount: editedCount,
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(
                              left: AppDesignTokens.spacing16,
                              right: AppDesignTokens.spacing16,
                              bottom: AppDesignTokens.spacing16,
                            ),
                            itemCount: plots.length,
                            itemBuilder: (context, index) {
                              final plot = plots[index];
                              final plotRatings =
                                  ratingsByPlot[plot.id] ?? [];
                              final isRated = ratedPks.contains(plot.id);
                              final isFlagged = flaggedIds.contains(plot.id);
                              final hasIssues = plotRatings.any(
                                  (r) => r.resultStatus != 'RECORDED');
                              final hasEdited = plotRatings.any((r) =>
                                      r.amended ||
                                      (r.previousId != null)) ||
                                  correctionPlotPks.contains(plot.id);
                              final label =
                                  getDisplayPlotLabel(plot, plots);

                              return _PlotCompletenessRow(
                                plotLabel: label,
                                isRated: isRated,
                                isFlagged: isFlagged,
                                hasIssues: hasIssues,
                                hasEdited: hasEdited,
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
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.totalPlots,
    required this.ratedCount,
    required this.notRatedCount,
    required this.flaggedCount,
    required this.issuesCount,
    required this.editedCount,
  });

  final int totalPlots;
  final int ratedCount;
  final int notRatedCount;
  final int flaggedCount;
  final int issuesCount;
  final int editedCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing8,
      ),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(
          bottom: BorderSide(color: AppDesignTokens.borderCrisp),
        ),
      ),
      child: Text(
        '$totalPlots plots · $ratedCount rated · $notRatedCount not rated · '
        '$flaggedCount flagged · $issuesCount issues · $editedCount edited',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          height: 1.35,
        ),
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
  });

  /// Display label from [getDisplayPlotLabel].
  final String plotLabel;
  final bool isRated;
  final bool isFlagged;
  final bool hasIssues;
  final bool hasEdited;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppDesignTokens.spacing8),
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
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: isRated ? 'Rated' : 'Not rated',
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
