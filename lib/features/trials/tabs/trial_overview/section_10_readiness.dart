import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
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

    return OverviewSectionCard(
      number: 10,
      title: 'Trial Readiness Statement',
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
              final statement = computeTrialReadinessStatement(
                coherenceDto: coherence,
                riskDto: risk,
                ctqDto: ctq,
                trialState: trial.status,
              );
              return _ReadinessBody(statement: statement);
            },
          ),
        ),
      ),
    );
  }
}

class _ReadinessBody extends StatelessWidget {
  const _ReadinessBody({required this.statement});

  final TrialReadinessStatement statement;

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg, chipLabel) = statement.isReadyForExport
        ? (
            AppDesignTokens.successBg,
            AppDesignTokens.successFg,
            'Export ready',
          )
        : (
            AppDesignTokens.warningBg,
            AppDesignTokens.warningFg,
            'Not export-ready',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        Text(
          statement.narrative,
          style: const TextStyle(
            fontSize: 13,
            color: AppDesignTokens.primaryText,
            height: 1.5,
          ),
        ),
        if (statement.actionItems.isNotEmpty) ...[
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
          ...statement.actionItems.map(
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
          ),
        ],
      ],
    );
  }
}
