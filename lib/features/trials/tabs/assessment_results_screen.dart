import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assessment_result_direction.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/workspace/workspace_config.dart';
import '../../derived/domain/trial_statistics.dart';
import '../../export/standalone_report_data.dart';

String _resultsPreliminaryBanner(bool isStandalone, bool isGlp) {
  if (isStandalone) return 'Still collecting data — results may change';
  if (isGlp) return 'Preliminary — do not use for regulatory conclusions';
  return 'Preliminary — data collection in progress.\nDo not use for conclusions.';
}

String _resultsFooterNote(bool isStandalone, bool isGlp) {
  if (isStandalone) {
    return 'More results available when data collection is complete';
  }
  if (isGlp) {
    return 'Full statistical analysis required for GLP submission';
  }
  return 'Full statistical analysis available when data collection is complete';
}

/// Full-screen assessment statistics and per-plot ratings for one trial assessment.
class AssessmentResultsScreen extends ConsumerWidget {
  const AssessmentResultsScreen({
    super.key,
    required this.stat,
    required this.trialId,
    required this.trialName,
    required this.workspaceType,
  });

  final AssessmentStatistics stat;
  final int trialId;
  final String trialName;
  final String workspaceType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(trialRatingRowsProvider(trialId));
    final p = stat.progress;
    final completeness = p.completeness;
    final config = safeConfigFromString(workspaceType);
    final isStandalone = config.isStandalone;
    final isGlp = config.studyType == StudyType.glp;

    final sortedTreatmentMeans = stat.isPreliminary
        ? sortTreatmentMeans(stat.treatmentMeans, ResultDirection.neutral)
        : sortTreatmentMeans(stat.treatmentMeans, stat.resultDirection);

    final showFooter = stat.isPreliminary ||
        completeness == AssessmentCompleteness.noData;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: AppDesignTokens.onPrimary,
          size: 24,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.assessmentName,
              style: AppDesignTokens.headerTitleStyle(
                fontSize: 17,
                color: AppDesignTokens.onPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              trialName,
              style: TextStyle(
                color: AppDesignTokens.onPrimary.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBanner(stat: stat),
            const SizedBox(height: 16),
            if (stat.treatmentMeans.isNotEmpty) ...[
              _TreatmentResultsSection(
                stat: stat,
                sortedMeans: sortedTreatmentMeans,
                isStandalone: isStandalone,
                isGlp: isGlp,
              ),
              const SizedBox(height: 20),
            ],
            _PerPlotDetailSection(
              stat: stat,
              rowsAsync: rowsAsync,
            ),
            if (showFooter) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _resultsFooterNote(isStandalone, isGlp),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.stat});

  final AssessmentStatistics stat;

  @override
  Widget build(BuildContext context) {
    final p = stat.progress;
    final c = p.completeness;

    if (c == AssessmentCompleteness.complete) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignTokens.successBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppDesignTokens.successFg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete · ${p.ratedPlots} of ${p.totalPlots} plots rated',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.successFg,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (c == AssessmentCompleteness.inProgress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignTokens.warningBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timelapse, color: AppDesignTokens.warningFg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In progress · ${p.ratedPlots} of ${p.totalPlots} plots rated',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.warningFg,
                    ),
                  ),
                  if (p.missingReps.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.missingReps.length == 1
                          ? 'Rep ${p.missingReps.first} incomplete'
                          : 'Reps ${p.missingReps.join(', ')} incomplete',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.warningFg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.emptyBadgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radio_button_unchecked,
              color: AppDesignTokens.secondaryText),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No data recorded yet',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreatmentResultsSection extends StatelessWidget {
  const _TreatmentResultsSection({
    required this.stat,
    required this.sortedMeans,
    required this.isStandalone,
    required this.isGlp,
  });

  final AssessmentStatistics stat;
  final List<TreatmentMean> sortedMeans;
  final bool isStandalone;
  final bool isGlp;

  @override
  Widget build(BuildContext context) {
    final showStar = !stat.isPreliminary &&
        stat.resultDirection != ResultDirection.neutral &&
        stat.treatmentMeans.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Treatment Results',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
        if (stat.isPreliminary) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppDesignTokens.warningBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _resultsPreliminaryBanner(isStandalone, isGlp),
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.warningFg,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _TreatmentTable(
          sortedMeans: sortedMeans,
          stat: stat,
          showStar: showStar,
          showSdN: !isStandalone,
        ),
      ],
    );
  }
}

class _TreatmentTable extends StatelessWidget {
  const _TreatmentTable({
    required this.sortedMeans,
    required this.stat,
    required this.showStar,
    required this.showSdN,
  });

  final List<TreatmentMean> sortedMeans;
  final AssessmentStatistics stat;
  final bool showStar;
  final bool showSdN;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDesignTokens.borderCrisp, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const BoxDecoration(
              color: AppDesignTokens.sectionHeaderBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 25,
                  child: Text(
                    'Treatment',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 10,
                  child: Text(
                    'Mean',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
                if (showSdN) ...[
                  const Expanded(
                    flex: 10,
                    child: Text(
                      'SD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 6,
                    child: Text(
                      'n',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var i = 0; i < sortedMeans.length; i++)
            _TreatmentDataRow(
              mean: sortedMeans[i],
              stat: stat,
              isWinner: showStar && i == 0,
              alternate: i.isOdd,
              isLast: i == sortedMeans.length - 1,
              showSdN: showSdN,
            ),
        ],
      ),
    );
  }
}

class _TreatmentDataRow extends StatelessWidget {
  const _TreatmentDataRow({
    required this.mean,
    required this.stat,
    required this.isWinner,
    required this.alternate,
    required this.isLast,
    required this.showSdN,
  });

  final TreatmentMean mean;
  final AssessmentStatistics stat;
  final bool isWinner;
  final bool alternate;
  final bool isLast;
  final bool showSdN;

  @override
  Widget build(BuildContext context) {
    final bg = alternate ? AppDesignTokens.bgWarm : AppDesignTokens.cardSurface;
    final meanText = stat.isPreliminary
        ? '~${mean.mean.toStringAsFixed(1)}'
        : '${mean.mean.toStringAsFixed(1)}${isWinner ? ' ★' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppDesignTokens.borderCrisp,
                  width: 0.5,
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 25,
            child: Text(
              mean.treatmentCode,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              meanText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
                color: stat.isPreliminary
                    ? AppDesignTokens.secondaryText
                    : (isWinner
                        ? AppDesignTokens.successFg
                        : AppDesignTokens.primaryText),
              ),
            ),
          ),
          if (showSdN) ...[
            Expanded(
              flex: 10,
              child: Text(
                mean.standardDeviation.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Text(
                '${mean.n}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PerPlotDetailSection extends StatelessWidget {
  const _PerPlotDetailSection({
    required this.stat,
    required this.rowsAsync,
  });

  final AssessmentStatistics stat;
  final AsyncValue<List<RatingResultRow>> rowsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Per-plot detail',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
        rowsAsync.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const Text(
            'Could not load plot detail',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          data: (rows) {
            // TEMP: using assessmentName match — upgrade to assessmentId
            // when assessmentId becomes available in export rows
            final filtered = rows.where((row) {
              if (row.assessmentName != stat.progress.assessmentName) {
                return false;
              }
              if (row.resultStatus != 'RECORDED') return false;
              if (double.tryParse(row.value) == null) return false;
              return true;
            }).toList()
              ..sort((a, b) {
                final c = a.rep.compareTo(b.rep);
                if (c != 0) return c;
                return a.plotId.compareTo(b.plotId);
              });

            if (filtered.isEmpty) {
              return const Center(
                child: Text(
                  'No plot-level data available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              );
            }

            return _PerPlotTable(rows: filtered);
          },
        ),
      ],
    );
  }
}

class _PerPlotTable extends StatelessWidget {
  const _PerPlotTable({required this.rows});

  final List<RatingResultRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDesignTokens.borderCrisp, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const BoxDecoration(
              color: AppDesignTokens.sectionHeaderBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 10,
                  child: Text(
                    'Plot',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    'Rep',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    'Treatment',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    'Value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _PerPlotDataRow(
              row: rows[i],
              alternate: i.isOdd,
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PerPlotDataRow extends StatelessWidget {
  const _PerPlotDataRow({
    required this.row,
    required this.alternate,
    required this.isLast,
  });

  final RatingResultRow row;
  final bool alternate;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bg = alternate ? AppDesignTokens.bgWarm : AppDesignTokens.cardSurface;
    final v = double.tryParse(row.value);
    final valueStr = v != null ? v.toStringAsFixed(1) : row.value;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppDesignTokens.borderCrisp,
                  width: 0.5,
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 10,
            child: Text(
              row.plotId,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              '${row.rep}',
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              row.treatmentCode,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              valueStr,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
