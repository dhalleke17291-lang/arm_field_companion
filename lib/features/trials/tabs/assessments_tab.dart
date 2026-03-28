import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assessment_result_direction.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/trial_state.dart';
import '../../../core/workspace/workspace_config.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../derived/domain/trial_statistics.dart';
import 'assessment_results_screen.dart';
import 'add_assessment_sheet.dart';

/// Assessments tab for trial detail: library + custom assessments list.
class AssessmentsTab extends ConsumerWidget {
  const AssessmentsTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync =
        ref.watch(trialAssessmentsWithDefinitionsForTrialProvider(trial.id));
    final legacyAsync = ref.watch(assessmentsForTrialProvider(trial.id));

    if (libraryAsync.isLoading && legacyAsync.isLoading) {
      return const AppLoadingView();
    }
    return libraryAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.invalidate(
            trialAssessmentsWithDefinitionsForTrialProvider(trial.id)),
      ),
      data: (libraryList) => legacyAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, st) => AppErrorView(
          error: e,
          stackTrace: st,
          onRetry: () => ref.invalidate(assessmentsForTrialProvider(trial.id)),
        ),
        data: (legacyList) =>
            _buildAssessmentsContent(context, ref, libraryList, legacyList),
      ),
    );
  }

  Widget _buildAssessmentsContent(
    BuildContext context,
    WidgetRef ref,
    List<(TrialAssessment, AssessmentDefinition)> libraryList,
    List<Assessment> legacyList,
  ) {
    final statsAsync = ref.watch(trialAssessmentStatisticsProvider(trial.id));
    final stats = statsAsync.valueOrNull ?? {};
    final config = safeConfigFromString(trial.workspaceType);
    final isStandalone = config.isStandalone;
    final isGlp = config.studyType == StudyType.glp;
    final locked = isProtocolLocked(trial.status);
    final total = libraryList.length + legacyList.length;
    if (total == 0) {
      return Column(
        children: [
          Expanded(
            child: AppEmptyState(
              icon: Icons.assessment,
              title: 'No Assessments Yet',
              subtitle: locked
                  ? getModeLockMessage(trial.status, trial.workspaceType)
                  : 'Add from library or create a custom assessment.',
              action: null,
            ),
          ),
          TabListBottomAddButton(
            label: 'Add Assessment',
            onPressed: locked
                ? null
                : () => _showAddAssessmentOptions(context, ref),
            disabledTooltip:
                locked ? getModeLockMessage(trial.status, trial.workspaceType) : null,
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: 10,
          ),
          decoration: const BoxDecoration(
            color: AppDesignTokens.sectionHeaderBg,
            border:
                Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assessment_outlined,
                  size: 16, color: AppDesignTokens.primary),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: Text(
                  total == 1 ? '1 assessment' : '$total assessments',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppDesignTokens.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ProtocolLockChip(isLocked: locked, status: trial.status),
            ],
          ),
        ),
        if (locked)
          ProtocolLockNotice(message: getModeLockMessage(trial.status, trial.workspaceType)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              if (libraryList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
                  child: Text(
                    'From library',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...libraryList.asMap().entries.map((entry) {
                  final displayNumber = entry.key + 1;
                  final ta = entry.value.$1;
                  final def = entry.value.$2;
                  final name = ta.displayNameOverride ?? def.name;
                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusCard),
                      border: Border.all(color: AppDesignTokens.borderCrisp),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrialItemNumberBadge(number: displayNumber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppDesignTokens.primaryText,
                                        ),
                                      ),
                                    ),
                                    if (ta.isActive)
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 20,
                                        color: AppDesignTokens.primary,
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: AppDesignTokens.iconSubtle,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${def.dataType}${def.unit != null ? ' (${def.unit})' : ''}'
                                      '${def.scaleMin != null && def.scaleMax != null ? ' · ${def.scaleMin}–${def.scaleMax}' : ''}',
                                  style: const TextStyle(
                                    color: AppDesignTokens.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                if (def.timingCode != null &&
                                    def.timingCode!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: scheme.outline
                                                .withValues(alpha: 0.6)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        def.timingCode!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                _buildAssessmentStatSlot(
                                  context,
                                  theme,
                                  statsAsync,
                                  stats,
                                  ta.id,
                                  null,
                                  isStandalone,
                                  isGlp,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (legacyList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 16, bottom: 6),
                  child: Text(
                    'Custom',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...legacyList.asMap().entries.map((entry) {
                  final displayNumber = libraryList.length + entry.key + 1;
                  final assessment = entry.value;
                  return Container(
                      margin: const EdgeInsets.only(
                          bottom: AppDesignTokens.spacing8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.cardSurface,
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard),
                        border: Border.all(color: AppDesignTokens.borderCrisp),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrialItemNumberBadge(number: displayNumber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          assessment.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppDesignTokens.primaryText,
                                          ),
                                        ),
                                      ),
                                      if (assessment.isActive)
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 20,
                                          color: AppDesignTokens.primary,
                                        )
                                      else
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: AppDesignTokens.iconSubtle,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${assessment.dataType}${assessment.unit != null ? ' (${assessment.unit})' : ''}'
                                        '${assessment.minValue != null && assessment.maxValue != null ? ' · ${assessment.minValue}–${assessment.maxValue}' : ''}',
                                    style: const TextStyle(
                                      color: AppDesignTokens.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                  _buildAssessmentStatSlot(
                                    context,
                                    theme,
                                    statsAsync,
                                    stats,
                                    null,
                                    assessment.name,
                                    isStandalone,
                                    isGlp,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                }),
              ],
            ],
          ),
        ),
        TabListBottomAddButton(
          label: 'Add Assessment',
          onPressed: locked
              ? null
              : () => _showAddAssessmentOptions(context, ref),
          disabledTooltip:
              locked ? getModeLockMessage(trial.status, trial.workspaceType) : null,
        ),
      ],
    );
  }

  /// Loading / error / lookup wrapper before the results block.
  Widget _buildAssessmentStatSlot(
    BuildContext context,
    ThemeData theme,
    AsyncValue<Map<int, AssessmentStatistics>> statsAsync,
    Map<int, AssessmentStatistics> stats,
    int? libraryTrialAssessmentId,
    String? legacyAssessmentName,
    bool isStandalone,
    bool isGlp,
  ) {
    if (statsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppDesignTokens.primary,
            ),
          ),
        ),
      );
    }
    if (statsAsync.hasError) {
      return const SizedBox.shrink();
    }
    AssessmentStatistics? stat;
    if (libraryTrialAssessmentId != null) {
      stat = stats[libraryTrialAssessmentId];
    } else if (legacyAssessmentName != null) {
      for (final s in stats.values) {
        if (s.progress.assessmentName == legacyAssessmentName) {
          stat = s;
          break;
        }
      }
    }
    if (stat == null) return const SizedBox.shrink();
    return _buildAssessmentResultsSection(
      stat,
      theme,
      context,
      isStandalone,
      isGlp,
    );
  }

  String _assessmentPreliminaryNotice(bool isStandalone, bool isGlp) {
    if (isStandalone) return 'Still collecting data — results may change';
    if (isGlp) {
      return 'Preliminary — do not use for regulatory conclusions';
    }
    return 'Preliminary — data collection in progress.\nDo not use for conclusions.';
  }

  String _assessmentFooterNote(bool isStandalone, bool isGlp) {
    if (isStandalone) {
      return 'More results available when data collection is complete';
    }
    if (isGlp) {
      return 'Full statistical analysis required for GLP submission';
    }
    return '';
  }

  Widget _buildAssessmentResultsSection(
    AssessmentStatistics stat,
    ThemeData theme,
    BuildContext context,
    bool isStandalone,
    bool isGlp,
  ) {
    final p = stat.progress;
    final completeness = p.completeness;
    final pctComplete = p.totalPlots > 0
        ? (100 * p.ratedPlots / p.totalPlots).round()
        : 0;

    late final double progressValue;
    late final Color progressColor;
    if (completeness == AssessmentCompleteness.noData || !stat.hasAnyData) {
      progressValue = 0;
      progressColor = AppDesignTokens.iconSubtle;
    } else if (completeness == AssessmentCompleteness.inProgress) {
      progressValue =
          p.totalPlots > 0 ? p.ratedPlots / p.totalPlots : 0;
      progressColor = AppDesignTokens.flagColor;
    } else {
      progressValue = 1.0;
      progressColor = AppDesignTokens.successFg;
    }

    final unitSuffix = stat.unit.trim().isEmpty ? '' : ' ${stat.unit}';

    List<TreatmentMean> orderedMeans;
    if (stat.treatmentMeans.isEmpty) {
      orderedMeans = [];
    } else if (stat.isPreliminary) {
      orderedMeans = List<TreatmentMean>.from(stat.treatmentMeans)
        ..sort((a, b) => a.treatmentCode.compareTo(b.treatmentCode));
    } else {
      orderedMeans = sortTreatmentMeans(stat.treatmentMeans, stat.resultDirection);
    }
    final displayMeans = orderedMeans.take(3).toList();
    final moreCount = orderedMeans.length - 3;

    final showBest = !stat.isPreliminary &&
        completeness == AssessmentCompleteness.complete &&
        displayMeans.isNotEmpty &&
        (stat.resultDirection == ResultDirection.higherIsBetter ||
            stat.resultDirection == ResultDirection.lowerIsBetter);

    final showFooterNote = stat.isPreliminary ||
        completeness == AssessmentCompleteness.noData;
    final footerNote = _assessmentFooterNote(isStandalone, isGlp);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: AppDesignTokens.emptyBadgeBg,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${p.ratedPlots} of ${p.totalPlots} plots',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ),
          if (completeness == AssessmentCompleteness.noData ||
              !stat.hasAnyData) ...[
            const SizedBox(height: 6),
            const Text(
              'No data yet',
              style: TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
          if (completeness == AssessmentCompleteness.inProgress &&
              p.missingReps.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.missingReps.length == 1
                  ? 'Rep ${p.missingReps.first} incomplete · $pctComplete% complete'
                  : 'Reps ${p.missingReps.join(', ')} incomplete · $pctComplete% complete',
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.warningFg,
              ),
            ),
          ],
          if (stat.hasAnyData && displayMeans.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (stat.isPreliminary) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.warningBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _assessmentPreliminaryNotice(isStandalone, isGlp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.warningFg,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...displayMeans.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final prefix = stat.isPreliminary ? '~' : '';
              final meanStr =
                  '$prefix${m.mean.toStringAsFixed(1)}$unitSuffix';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 25,
                      child: Text(
                        m.treatmentCode,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              meanStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: showBest && i == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: stat.isPreliminary
                                    ? AppDesignTokens.secondaryText
                                    : (showBest && i == 0
                                        ? AppDesignTokens.successFg
                                        : AppDesignTokens.primaryText),
                              ),
                            ),
                          ),
                          if (showBest && i == 0)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                'Best',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.successFg,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isStandalone) ...[
                      Expanded(
                        flex: 10,
                        child: Text(
                          m.standardDeviation.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          '${m.n}',
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
            }),
            if (moreCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'and $moreCount more…',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ),
          ],
          if (showFooterNote && footerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                footerNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ),
          ],
          if (stat.hasAnyData) ...[
            SizedBox(height: displayMeans.isNotEmpty ? 4 : 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AssessmentResultsScreen(
                        stat: stat,
                        trialId: trial.id,
                        trialName: trial.name,
                        workspaceType: trial.workspaceType,
                      ),
                    ),
                  );
                },
                child: const Text('Details →'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAssessmentOptions(BuildContext context, WidgetRef ref) {
    // Open the form dialog directly so the user always sees content.
    // "From Library" is available as a link inside the dialog.
    _showAddAssessmentDialog(context, ref);
  }

  Future<void> _showAddAssessmentDialog(
      BuildContext context, WidgetRef ref) async {
    await showAddCustomAssessmentSheet(context, ref, trial: trial);
  }
}
