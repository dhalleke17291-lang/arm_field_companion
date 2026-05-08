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
      subtitle: 'Required evidence and quality factors',
      child: ctqAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _CtqBody(dto: dto, trialId: trial.id),
      ),
    );
  }
}

class _CtqBody extends StatefulWidget {
  const _CtqBody({required this.dto, required this.trialId});

  final TrialCtqDto dto;
  final int trialId;

  @override
  State<_CtqBody> createState() => _CtqBodyState();
}

class _CtqBodyState extends State<_CtqBody> {
  bool _showSatisfied = false;

  @override
  Widget build(BuildContext context) {
    final dto = widget.dto;

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
          'Not evaluated',
        ),
    };

    // Attention items: blocked, missing, unacknowledged review, acknowledged review.
    final attentionItems = dto.ctqItems
        .where((i) => i.isBlocked || i.status == 'missing' || i.needsReview)
        .toList();

    // Satisfied items: collapse by default.
    final satisfiedItems =
        dto.ctqItems.where((i) => i.status == 'satisfied').toList();

    // Unknown/not-evaluated items: omit from default view (not actionable).

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: headerLabel, bg: headerBg, fg: headerFg),
        if (attentionItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          ...attentionItems.map(
            (item) => _CtqItemRow(item: item, trialId: widget.trialId),
          ),
        ],
        if (satisfiedItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          GestureDetector(
            onTap: () => setState(() => _showSatisfied = !_showSatisfied),
            child: Row(
              children: [
                Text(
                  _showSatisfied
                      ? 'Hide satisfied checks'
                      : 'Show satisfied checks (${satisfiedItems.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showSatisfied
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppDesignTokens.primary,
                ),
              ],
            ),
          ),
          if (_showSatisfied) ...[
            const SizedBox(height: AppDesignTokens.spacing4),
            ...satisfiedItems.map(
              (item) => _CtqItemRow(item: item, trialId: widget.trialId),
            ),
          ],
        ],
        if (attentionItems.isEmpty && satisfiedItems.isEmpty)
          const Text(
            'No factors evaluated yet.',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          ),
      ],
    );
  }
}

class _CtqItemRow extends StatefulWidget {
  const _CtqItemRow({required this.item, required this.trialId});

  final TrialCtqItemDto item;
  final int trialId;

  @override
  State<_CtqItemRow> createState() => _CtqItemRowState();
}

class _CtqItemRowState extends State<_CtqItemRow> {
  bool _expanded = false;

  static String _requiredActionHint(TrialCtqItemDto item) {
    return switch (item.factorKey) {
      'plot_completeness' =>
        'Required: complete ratings for all analyzable plots.',
      'photo_evidence' => 'Required: add photo evidence.',
      'gps_evidence' => 'Required: enable GPS capture during rating sessions.',
      'treatment_identity' => 'Required: define treatments for this trial.',
      'application_timing' => 'Required: record application events.',
      'rating_window' => 'Required: record rating assessments.',
      'rater_consistency' =>
        'Required: resolve the open rater consistency signal.',
      _ => 'Required: address this factor before export.',
    };
  }

  static String _unknownLabel(TrialCtqItemDto item) {
    final r = item.reason.toLowerCase();
    if (r.contains('not applicable') || r.contains('n/a')) {
      return 'Not applicable yet';
    }
    if (r.contains('pending') || r.contains('await')) {
      return 'Pending data';
    }
    if (r.contains('evidence') || r.contains('missing')) {
      return 'Requires evidence';
    }
    return 'Not evaluated';
  }

  VoidCallback? _onTap(BuildContext context) {
    final item = widget.item;
    if (item.needsReview && !item.isAcknowledged) {
      return () => showCtqAcknowledgmentSheet(
            context,
            item: item,
            trialId: widget.trialId,
          );
    }
    if (item.isAcknowledged) {
      return () => setState(() => _expanded = !_expanded);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
          _unknownLabel(item),
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: InkWell(
        onTap: _onTap(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                if (item.isAcknowledged) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppDesignTokens.secondaryText,
                  ),
                ],
              ],
            ),
            if (item.reason.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppDesignTokens.secondaryText,
                  height: 1.4,
                ),
              ),
            ],
            if (item.status == 'missing' || item.isBlocked) ...[
              const SizedBox(height: AppDesignTokens.spacing4),
              Text(
                _requiredActionHint(item),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.warningFg,
                ),
              ),
            ],
            if (item.isAcknowledged &&
                item.latestAcknowledgment != null &&
                _expanded) ...[
              const SizedBox(height: 2),
              Text(
                'Acknowledged ${DateFormat('MMM d, y').format(item.latestAcknowledgment!.acknowledgedAt)}'
                '${item.latestAcknowledgment!.actorName != null ? ' by ${item.latestAcknowledgment!.actorName}' : ''}',
                style: const TextStyle(
                  fontSize: 15,
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
