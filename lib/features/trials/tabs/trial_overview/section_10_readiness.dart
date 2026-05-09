import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/signals/signal_providers.dart';
import '../../../../domain/signals/signal_review_projection.dart';
import '../../../../domain/trial_cognition/interpretation_factors_codec.dart';
import '../../../../domain/trial_cognition/readiness_criteria_codec.dart';
import '../../widgets/signal_action_sheet.dart';
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
                trialId: trial.id,
                readinessCriteriaSummary: purpose?.readinessCriteriaSummary,
                knownInterpretationFactors: purpose?.knownInterpretationFactors,
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

class _ReadinessBody extends ConsumerWidget {
  const _ReadinessBody({
    required this.statement,
    required this.trialId,
    this.readinessCriteriaSummary,
    this.knownInterpretationFactors,
    this.signalActions = const <SignalReviewProjection>[],
  });

  final TrialReadinessStatement statement;
  final int trialId;
  final String? readinessCriteriaSummary;
  final String? knownInterpretationFactors;
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

    // Fallback: derive clean prose from action items and reasons
    // Never surface raw internal check strings
    final hasCoherenceIssue = statement.actionItems
        .any((a) => a.startsWith('Review deviation:') ||
                    a.startsWith('Provide missing input for:'));
    final hasCTQIssue = statement.actionItems
        .any((a) => a.startsWith('Resolve:'));

    if (hasCoherenceIssue && hasCTQIssue) {
      return 'Trial execution has deviations and required evidence is missing.';
    }
    if (hasCoherenceIssue) {
      return 'Trial execution has deviations that require review.';
    }
    if (hasCTQIssue) {
      return 'Required evidence has not been recorded.';
    }
    if (statement.actionItems.isNotEmpty) {
      return 'One or more required conditions have not been met.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawSignalsById = {
      for (final signal
          in ref.watch(openSignalsForTrialProvider(trialId)).valueOrNull ??
              const <Signal>[])
        signal.id: signal,
    };

    final (chipBg, chipFg) = statement.isReadyForExport
        ? (AppDesignTokens.successBg, AppDesignTokens.successFg)
        : (AppDesignTokens.warningBg, AppDesignTokens.warningFg);
    final whyText = _computeWhyText();
    final siteContextText = _buildSiteContextText(knownInterpretationFactors);

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
            fontSize: 15,
            color: AppDesignTokens.primaryText,
            height: 1.5,
          ),
        ),
        if (siteContextText != null) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          Text(
            siteContextText,
            style: const TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
              height: 1.4,
            ),
          ),
        ],
        if (whyText != null) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'WHY',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            whyText,
            style: const TextStyle(
              fontSize: 14,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          ..._bulletList(statement.actionItems),
          ..._signalActionBulletList(
            signalActions,
            context: context,
            rawSignalsById: rawSignalsById,
            trialId: trialId,
          ),
        ],
        if (statement.cautions.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          const Text(
            'CAUTIONS',
            style: TextStyle(
              fontSize: 14,
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

  // TODO: labels duplicated from _kSiteConditionLabels in
  // trial_interpretation_risk_evaluator.dart — move to shared codec if a
  // third callsite appears.
  static const _kSiteLabels = <String, String>{
    'low_pest_pressure': 'Low pest/disease pressure this season',
    'high_pest_pressure': 'High pest/disease pressure this season',
    'drought_stress': 'Drought stress this season',
    'excessive_rainfall': 'Excessive rainfall during trial period',
    'frost_risk': 'Frost risk during trial period',
    'spatial_gradient': 'Spatial gradient in the field',
    'previous_crop_residue': 'Previous crop residue effects',
    'atypical_season': 'Atypical season for this region',
    'drainage_issues': 'Drainage issues noted',
  };

  static String? _buildSiteContextText(String? raw) {
    final parsed = InterpretationFactorsCodec.parse(raw);
    if (parsed == null || parsed.noneSelected) return null;
    final parts = <String>[];
    for (final k in parsed.selectedKeys) {
      final label = _kSiteLabels[k];
      if (label != null) parts.add(label);
    }
    if (parsed.otherText != null) parts.add(parsed.otherText!);
    if (parts.isEmpty) return null;
    return 'Site & season context: ${parts.join(' · ')}';
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
                    fontSize: 14,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
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
    List<SignalReviewProjection> items, {
    required BuildContext context,
    required Map<int, Signal> rawSignalsById,
    required int trialId,
  }) {
    return items.map((item) {
      final rawSignal = rawSignalsById[item.signalId];
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: InkWell(
          onTap: rawSignal != null
              ? () => showSignalActionSheet(context,
                  signal: rawSignal, trialId: trialId)
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  fontSize: 14,
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
                        fontSize: 14,
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
                          fontSize: 14,
                          color: AppDesignTokens.primaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      item.statusLabel,
                      style: const TextStyle(
                        fontSize: 15,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.warningFg,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (rawSignal != null)
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppDesignTokens.secondaryText,
                ),
            ],
          ),
        ),
      );
    }).toList();
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
            fontSize: 14,
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
                fontSize: 14,
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
