import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/signals/signal_providers.dart';
import '../../../../domain/trial_cognition/trial_readiness_statement.dart';
import '../../../../shared/layout/responsive_layout.dart';
import 'section_1_identity.dart';
import 'section_2_design.dart';
import 'section_3_arc.dart';
import 'section_4_ctq.dart';
import 'section_5_endpoint.dart';
import 'section_6_comparison.dart';
import 'section_7_coherence.dart';
import 'section_8_environmental.dart';
import 'section_9_decisions.dart';
import 'section_10_readiness.dart';
import '_overview_card.dart';

/// Read-only ten-section Trial Review tab.
/// Each section handles its own loading/error/empty state independently.
class TrialOverviewTab extends StatelessWidget {
  const TrialOverviewTab({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppDesignTokens.spacing8,
          bottom: AppDesignTokens.spacing32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrialReviewSummaryCard(trial: trial),
            Section1Identity(trial: trial),
            Section2Design(trial: trial),
            Section3Arc(trial: trial),
            Section4Ctq(trial: trial),
            Section5Endpoint(trial: trial),
            Section6Comparison(trial: trial),
            Section7Coherence(trial: trial),
            Section8Environmental(trial: trial),
            Section9Decisions(trial: trial),
            Section10Readiness(trial: trial),
          ],
        ),
      ),
    );
  }
}

/// Top summary card for the Trial Review tab.
/// Shows current readiness, attention items, and primary next action
/// derived from the three cognition providers — no new providers.
class TrialReviewSummaryCard extends ConsumerWidget {
  const TrialReviewSummaryCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final cohAsync = ref.watch(trialCoherenceProvider(trial.id));
    final riskAsync = ref.watch(trialInterpretationRiskProvider(trial.id));
    final signalsAsync = ref.watch(openSignalsForTrialProvider(trial.id));
    final decisionsAsync = ref.watch(trialDecisionSummaryProvider(trial.id));
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));

    final ctq = ctqAsync.valueOrNull;
    final coh = cohAsync.valueOrNull;
    final risk = riskAsync.valueOrNull;

    if (ctq == null || coh == null || risk == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing12,
          AppDesignTokens.spacing16,
          AppDesignTokens.spacing8,
        ),
        decoration: BoxDecoration(
          color: AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: AppDesignTokens.borderCrisp),
          boxShadow: AppDesignTokens.cardShadowRating,
        ),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: OverviewSectionLoading(),
        ),
      );
    }

    final statement = computeTrialReadinessStatement(
      coherenceDto: coh,
      riskDto: risk,
      ctqDto: ctq,
      trialState: trial.status,
      knownInterpretationFactors:
          purposeAsync.valueOrNull?.knownInterpretationFactors,
    );

    final openSignalsCount = signalsAsync.valueOrNull?.length;
    final decisions = decisionsAsync.valueOrNull;
    final documentedCount = decisions == null
        ? null
        : decisions.ctqAcknowledgments.length +
            decisions.signalDecisions.length;

    return _SummaryCardBody(
      statement: statement,
      openSignalsCount: openSignalsCount,
      documentedDecisionsCount: documentedCount,
    );
  }
}

class _SummaryCardBody extends StatelessWidget {
  const _SummaryCardBody({
    required this.statement,
    required this.openSignalsCount,
    required this.documentedDecisionsCount,
  });

  final TrialReadinessStatement statement;
  final int? openSignalsCount;
  final int? documentedDecisionsCount;

  @override
  Widget build(BuildContext context) {
    final isReady = statement.isReadyForExport;

    final (chipBg, chipFg) = isReady
        ? (AppDesignTokens.successBg, AppDesignTokens.successFg)
        : statement.actionItems.isEmpty
            ? (AppDesignTokens.partialBg, AppDesignTokens.partialFg)
            : (AppDesignTokens.warningBg, AppDesignTokens.warningFg);

    // Top 4 attention items — action items first, then cautions.
    final attentionItems = [
      ...statement.actionItems,
      ...statement.cautions,
    ].take(4).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing12,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: AppDesignTokens.cardShadowRating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverviewStatusChip(
              label: statement.statusLabel,
              bg: chipBg,
              fg: chipFg,
            ),
            const SizedBox(height: AppDesignTokens.spacing12),
            if (isReady) ...[
              Text(
                statement.summaryText,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppDesignTokens.primaryText,
                  height: 1.4,
                ),
              ),
              if (openSignalsCount != null && openSignalsCount! == 0) ...[
                const SizedBox(height: AppDesignTokens.spacing8),
                const Text(
                  'No open signals.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ] else ...[
              if (attentionItems.isNotEmpty) ...[
                const Text(
                  'NEEDS ATTENTION',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                const SizedBox(height: AppDesignTokens.spacing8),
                ...attentionItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                ),
              ],
              if (openSignalsCount != null && openSignalsCount! > 0) ...[
                const SizedBox(height: AppDesignTokens.spacing4),
                Text(
                  '$openSignalsCount open signal${openSignalsCount == 1 ? '' : 's'} require attention.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ],
            if (documentedDecisionsCount != null &&
                documentedDecisionsCount! > 0) ...[
              const SizedBox(height: AppDesignTokens.spacing4),
              Text(
                '$documentedDecisionsCount documented decision${documentedDecisionsCount == 1 ? '' : 's'}.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
