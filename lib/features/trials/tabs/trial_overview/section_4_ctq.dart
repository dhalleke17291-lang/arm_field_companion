import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../widgets/ctq_acknowledgment_sheet.dart';
import '_overview_card.dart';

class Section4Ctq extends ConsumerWidget {
  const Section4Ctq({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));

    return OverviewSectionCard(
      number: 4,
      title: 'Critical-to-Quality Status',
      child: ctqAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _CtqBody(dto: dto, trialId: trial.id),
      ),
    );
  }
}

class _CtqBody extends StatelessWidget {
  const _CtqBody({required this.dto, required this.trialId});

  final TrialCtqDto dto;
  final int trialId;

  @override
  Widget build(BuildContext context) {
    final (headerBg, headerFg, headerLabel) = switch (dto.overallStatus) {
      'ready_for_review' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Ready for review',
        ),
      'review_needed' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Review needed',
        ),
      'incomplete' => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          'Incomplete',
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
        OverviewStatusChip(label: headerLabel, bg: headerBg, fg: headerFg),
        if (dto.ctqItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          ...dto.ctqItems.map(
            (item) => _CtqItemRow(item: item, trialId: trialId),
          ),
        ],
      ],
    );
  }
}

class _CtqItemRow extends StatelessWidget {
  const _CtqItemRow({required this.item, required this.trialId});

  final TrialCtqItemDto item;
  final int trialId;

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg, chipLabel) = switch (item.status) {
      'satisfied' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Satisfied',
        ),
      'blocked' => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          'Blocked',
        ),
      'review_needed' when item.isAcknowledged => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          'Acknowledged',
        ),
      'review_needed' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Review needed',
        ),
      'missing' => (
          AppDesignTokens.warningBg,
          AppDesignTokens.warningFg,
          'Missing',
        ),
      _ => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          item.status,
        ),
    };

    final showAckAction =
        (item.isBlocked || item.needsReview) && !item.isAcknowledged;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
            ],
          ),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.reason,
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
                height: 1.4,
              ),
            ),
          ],
          if (item.isAcknowledged && item.latestAcknowledgment != null) ...[
            const SizedBox(height: 2),
            Text(
              'Acknowledged ${DateFormat('MMM d, y').format(item.latestAcknowledgment!.acknowledgedAt)}'
              '${item.latestAcknowledgment!.actorName != null ? ' by ${item.latestAcknowledgment!.actorName}' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ],
          if (showAckAction) ...[
            const SizedBox(height: AppDesignTokens.spacing4),
            GestureDetector(
              onTap: () => showCtqAcknowledgmentSheet(
                context,
                item: item,
                trialId: trialId,
              ),
              child: const Text(
                'Acknowledge →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
