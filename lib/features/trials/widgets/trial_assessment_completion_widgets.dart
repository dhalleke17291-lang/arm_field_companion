import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/providers.dart';
import '../../diagnostics/assessment_completion.dart';

/// Per-assessment progress rows for trial trust (Assessments tab + detail).
class TrialAssessmentCompletionCard extends ConsumerWidget {
  const TrialAssessmentCompletionCard({
    super.key,
    required this.trialId,
    this.dense = false,
  });

  final int trialId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialAssessmentCompletionProvider(trialId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (map) {
        if (map.isEmpty) return const SizedBox.shrink();
        final entries = map.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final pad = dense ? AppDesignTokens.spacing8 : AppDesignTokens.spacing12;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            side: const BorderSide(color: AppDesignTokens.borderCrisp),
          ),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assessments',
                  style: AppDesignTokens.headingStyle(
                    fontSize: dense ? 13 : 14,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                SizedBox(height: dense ? 6 : AppDesignTokens.spacing8),
                ...entries.map((e) => Padding(
                      padding: EdgeInsets.only(bottom: dense ? 8 : 10),
                      child: _AssessmentCompletionRow(completion: e.value),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssessmentCompletionRow extends StatelessWidget {
  const _AssessmentCompletionRow({required this.completion});

  final AssessmentCompletion completion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (completion.progressFraction * 100).round();
    final barColor = completion.progressFraction >= 1.0
        ? AppDesignTokens.successFg
        : completion.ratedPlotCount > 0
            ? AppDesignTokens.warningFg
            : scheme.error;
    final icon = completion.progressFraction >= 1.0
        ? Icons.check_circle_outline
        : completion.ratedPlotCount > 0
            ? Icons.warning_amber_rounded
            : Icons.cancel_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: barColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                completion.assessmentName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${completion.ratedPlotCount}/${completion.analyzablePlotCount} · $pct%'
              '${completion.excludedFromAnalysisCount > 0 ? ' · ${completion.excludedFromAnalysisCount} excluded' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completion.analyzablePlotCount <= 0
                ? 0
                : completion.progressFraction,
            minHeight: 6,
            backgroundColor: AppDesignTokens.borderCrisp.withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Thin trial-level completion summary (header strip on trial detail).
class TrialCompletionSummaryCard extends ConsumerWidget {
  const TrialCompletionSummaryCard({super.key, required this.trialId});

  final int trialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync =
        ref.watch(trialAssessmentCompletionProvider(trialId));
    final ratedAsync = ref.watch(ratedPlotsCountForTrialProvider(trialId));
    return completionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, __) => AppErrorHint(error: e),
      data: (map) {
        if (map.isEmpty) return const SizedBox.shrink();
        final first = map.values.first;
        final analyzablePlotCount = first.analyzablePlotCount;
        final totalDataPlots = first.totalDataPlots;
        final excludedFromAnalysisCount = first.excludedFromAnalysisCount;
        final nAssess = map.length;
        final completeAssess =
            map.values.where((c) => c.isComplete).length;
        final sumPairs =
            map.values.fold<int>(0, (s, c) => s + c.ratedPlotCount);
        final denomPairs = nAssess * analyzablePlotCount;
        final overall = denomPairs <= 0
            ? 0.0
            : (sumPairs / denomPairs).clamp(0.0, 1.0);
        final ratedAny = ratedAsync.valueOrNull;
        return Card(
          margin: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing8,
            AppDesignTokens.spacing16,
            AppDesignTokens.spacing8,
          ),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
            side: const BorderSide(color: AppDesignTokens.borderCrisp),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacing12,
              vertical: AppDesignTokens.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial Completion',
                  style: AppDesignTokens.headingStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overall,
                    minHeight: 6,
                    backgroundColor:
                        AppDesignTokens.borderCrisp.withValues(alpha: 0.35),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overall >= 1.0
                          ? AppDesignTokens.successFg
                          : AppDesignTokens.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(overall * 100).round()}% plot-assessment coverage',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ratedAny == null
                      ? '$nAssess assessments · $completeAssess of $nAssess complete'
                      : '$ratedAny/$totalDataPlots data plots rated'
                          '${excludedFromAnalysisCount > 0 ? ' · $excludedFromAnalysisCount excluded' : ''}'
                          ' · $nAssess assessments · $completeAssess of $nAssess complete',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
