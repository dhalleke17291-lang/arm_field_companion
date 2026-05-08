import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../../../domain/trial_cognition/trial_evidence_arc_dto.dart';
import '_overview_card.dart';

class Section5Endpoint extends ConsumerWidget {
  const Section5Endpoint({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final arcAsync = ref.watch(trialEvidenceArcProvider(trial.id));

    return OverviewSectionCard(
      number: 5,
      title: 'Primary Endpoint Evidence',
      child: ctqAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (ctqDto) => arcAsync.when(
          loading: () => const OverviewSectionLoading(),
          error: (_, __) => const OverviewSectionError(),
          data: (arcDto) => _EndpointBody(ctq: ctqDto, arc: arcDto),
        ),
      ),
    );
  }
}

class _EndpointBody extends StatelessWidget {
  const _EndpointBody({required this.ctq, required this.arc});

  final TrialCtqDto ctq;
  final TrialEvidenceArcDto arc;

  // Primary endpoint completeness factor key as defined in the CTQ evaluator.
  static const _kPrimaryEndpointKey = 'primary_endpoint_completeness';

  @override
  Widget build(BuildContext context) {
    final endpointItem = ctq.ctqItems
        .where((i) => i.factorKey == _kPrimaryEndpointKey)
        .firstOrNull;

    if (endpointItem == null) {
      final plotItem = ctq.ctqItems
          .where((i) => i.factorKey == 'plot_completeness')
          .firstOrNull;
      if (plotItem == null || plotItem.status == 'unknown') {
        return const Text(
          'Evaluates once analyzable plots and ratings are defined.',
          style: TextStyle(fontSize: 14, color: AppDesignTokens.secondaryText),
        );
      }
      final (proxyBg, proxyFg, proxyLabel) = switch (plotItem.status) {
        'satisfied' => (
            AppDesignTokens.successBg,
            AppDesignTokens.successFg,
            'Complete',
          ),
        'review_needed' => (
            AppDesignTokens.partialBg,
            AppDesignTokens.partialFg,
            'Partial',
          ),
        _ => (
            AppDesignTokens.warningBg,
            AppDesignTokens.warningFg,
            'Missing',
          ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverviewStatusChip(label: proxyLabel, bg: proxyBg, fg: proxyFg),
          const SizedBox(height: AppDesignTokens.spacing8),
          if (plotItem.evidenceSummary.isNotEmpty)
            OverviewDataRow('Ratings', plotItem.evidenceSummary),
          if (plotItem.reason.isNotEmpty)
            OverviewDataRow('Detail', plotItem.reason),
        ],
      );
    }

    final (chipBg, chipFg, chipLabel) = switch (endpointItem.status) {
      'satisfied' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Complete',
        ),
      'blocked' || 'missing' => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          'Incomplete',
        ),
      'review_needed' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Review needed',
        ),
      _ => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          'Unknown',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (endpointItem.evidenceSummary.isNotEmpty)
          OverviewDataRow('Evidence', endpointItem.evidenceSummary),
        if (endpointItem.reason.isNotEmpty)
          OverviewDataRow('Detail', endpointItem.reason),
        if (arc.missingEvidenceItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          const Text(
            'Missing evidence:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          ...arc.missingEvidenceItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
          ),
        ],
        // TODO(A5): surface per-treatment/per-rep missing ratings once
        // a granular missing-plot DTO is available from trialEvidenceArcProvider.
      ],
    );
  }
}
