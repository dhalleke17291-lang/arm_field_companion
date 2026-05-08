import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/signals/signal_providers.dart';
import '../../../../domain/signals/signal_review_projection.dart';
import '../../../../domain/trial_cognition/readiness_criteria_codec.dart';
import '../../../../domain/trial_cognition/trial_readiness_statement.dart';
import '_overview_card.dart';

class Section10Readiness extends ConsumerWidget {
  const Section10Readiness({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coherenceAsync = ref.watch(trialCoherenceProvider(trial.id));
    final riskAsync = ref.watch(trialInterpretationRiskProvider(trial.id));
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));
    final projectedSignalsAsync =
        ref.watch(projectedOpenSignalsForTrialProvider(trial.id));

    return OverviewSectionCard(
      number: 10,
      title: 'Trial Readiness Statement',
      subtitle: 'What must be resolved before export or review',
      child: coherenceAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (coherence) => riskAsync.when(
          loading: () => const OverviewSectionLoading(),
          error: (_, __) => const OverviewSectionError(),
          data: (risk) => ctqAsync.when(
            loading: () => const OverviewSectionLoading(),
            error: (_, __) => const OverviewSectionError(),
            data: (ctq) {
              final purpose = purposeAsync.valueOrNull;
              final statement = computeTrialReadinessStatement(
                coherenceDto: coherence,
                riskDto: risk,
                ctqDto: ctq,
                trialState: trial.status,
                knownInterpretationFactors: purpose?.knownInterpretationFactors,
              );
              return _ReadinessBody(
                statement: statement,
                readinessCriteriaSummary: purpose?.readinessCriteriaSummary,
                signalActions: projectedSignalsAsync.valueOrNull
                        ?.where((signal) => signal.requiresReadinessAction)
                        .toList(growable: false) ??
                    const <SignalReviewProjection>[],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReadinessBody extends StatelessWidget {
  const _ReadinessBody({
    required this.statement,
    this.readinessCriteriaSummary,
    this.signalActions = const <SignalReviewProjection>[],
  });

  final TrialReadinessStatement statement;
  final String? readinessCriteriaSummary;
  final List<SignalReviewProjection> signalActions;

  /// Returns a single WHY sentence for the not-export-ready state, or null
  /// when export-ready (WHY is suppressed entirely when ready).
  ///
  /// Priority order:
  ///   1. Both missing evidence AND unresolved signals → combined message
  ///   2. Unresolved signal review items only
  ///   3. Missing required CTQ evidence only
  ///   4. Any other blocking reason from the provider — coherence trivia filtered
  String? _computeWhyText() {
    if (statement.isReadyForExport) return null;

    final hasUnresolvedSignals = signalActions.isNotEmpty;
    final hasMissingEvidence =
        statement.actionItems.any((a) => a.startsWith('Resolve:'));

    if (hasUnresolvedSignals && hasMissingEvidence) {
      return 'Required evidence is missing and review items must be decided before export.';
    }
    if (hasUnresolvedSignals) {
      return 'Unresolved review items must be decided before export.';
    }
    if (hasMissingEvidence) {
      return 'Required evidence is missing.';
    }

    // Fallback: most specific blocking reason — never coherence trivia
    for (final r in statement.reasons) {
      if (r == 'No coherence concerns identified.') continue;
      if (r == 'All critical-to-quality factors satisfied.') continue;
      if (r.startsWith('Interpretation risk is low')) continue;
      if (r.startsWith('Interpretation risk is moderate')) continue;
      return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg) = statement.isReadyForExport
        ? (AppDesignTokens.successBg, AppDesignTokens.successFg)
        : (AppDesignTokens.warningBg, AppDesignTokens.warningFg);
    final whyText = _computeWhyText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(
          label: statement.statusLabel,
          bg: chipBg,
          fg: chipFg,
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        Text(
          statement.summaryText,
          style: const TextStyle(
            fontSize: 13,
            color: AppDesignTokens.primaryText,
            height: 1.5,
          ),
        ),
        if (whyText != null) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'WHY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            whyText,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.primaryText,
              height: 1.4,
            ),
          ),
        ],
        if (statement.actionItems.isNotEmpty || signalActions.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'ITEMS REQUIRING ACTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          ..._bulletList(statement.actionItems),
          ..._signalActionBulletList(signalActions),
        ],
        if (statement.cautions.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'CAUTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          ..._bulletList(statement.cautions),
        ],
        _CriteriaSection(rawJson: readinessCriteriaSummary),
      ],
    );
  }

  static List<Widget> _bulletList(List<String> items) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignTokens.primaryText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  static List<Widget> _signalActionBulletList(
    List<SignalReviewProjection> items,
  ) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                          height: 1.4,
                        ),
                      ),
                      if (item.readinessActionReason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.readinessActionReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignTokens.primaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        item.statusLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.secondaryText,
                          height: 1.3,
                        ),
                      ),
                      if (item.blocksExport &&
                          item.blocksExportReason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.blocksExportReason!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.warningFg,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

class _CriteriaSection extends StatelessWidget {
  const _CriteriaSection({required this.rawJson});

  final String? rawJson;

  @override
  Widget build(BuildContext context) {
    final criteria = ReadinessCriteriaCodec.parse(rawJson);
    if (criteria == null) return const SizedBox.shrink();

    final rows = <String>[];
    if (criteria.minEfficacyPercent != null) {
      final at = criteria.efficacyAt == 'all_endpoints'
          ? 'all endpoints'
          : 'primary endpoint';
      rows.add(
          'Minimum efficacy: ${criteria.minEfficacyPercent!.toStringAsFixed(0)}% at $at');
    }
    if (criteria.phytotoxicityThresholdPercent != null) {
      rows.add(
          'Phytotoxicity threshold: ≤${criteria.phytotoxicityThresholdPercent!.toStringAsFixed(0)}%');
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDesignTokens.spacing8),
        const Text(
          'READINESS CRITERIA',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing4),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              r,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignTokens.primaryText,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
