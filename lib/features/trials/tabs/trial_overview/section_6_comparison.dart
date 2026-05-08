import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '_overview_card.dart';

class Section6Comparison extends ConsumerWidget {
  const Section6Comparison({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));

    return OverviewSectionCard(
      number: 6,
      title: 'Comparison Readiness',
      child: ctqAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _ComparisonBody(dto: dto),
      ),
    );
  }
}

class _ComparisonBody extends StatelessWidget {
  const _ComparisonBody({required this.dto});

  final TrialCtqDto dto;

  static const _kCheckKey = 'comparison_structure';

  @override
  Widget build(BuildContext context) {
    final item =
        dto.ctqItems.where((i) => i.factorKey == _kCheckKey).firstOrNull;

    if (item == null) {
      final treatmentItem = dto.ctqItems
          .where((i) => i.factorKey == 'treatment_identity')
          .firstOrNull;
      if (treatmentItem == null || treatmentItem.status == 'unknown') {
        return const Text(
          'Evaluates once treatments are defined.',
          style: TextStyle(fontSize: 14, color: AppDesignTokens.secondaryText),
        );
      }
      final (proxyBg, proxyFg, proxyLabel) = switch (treatmentItem.status) {
        'satisfied' => (
            AppDesignTokens.successBg,
            AppDesignTokens.successFg,
            'Treatments defined',
          ),
        _ => (
            AppDesignTokens.warningBg,
            AppDesignTokens.warningFg,
            'No treatments',
          ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverviewStatusChip(label: proxyLabel, bg: proxyBg, fg: proxyFg),
          const SizedBox(height: AppDesignTokens.spacing8),
          if (treatmentItem.evidenceSummary.isNotEmpty)
            OverviewDataRow('Treatments', treatmentItem.evidenceSummary),
        ],
      );
    }

    final (chipBg, chipFg, chipLabel) = switch (item.status) {
      'satisfied' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Structure present',
        ),
      'blocked' || 'missing' => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          'Missing',
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
        if (item.evidenceSummary.isNotEmpty)
          OverviewDataRow('Structure', item.evidenceSummary),
        if (item.reason.isNotEmpty)
          Text(
            item.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
