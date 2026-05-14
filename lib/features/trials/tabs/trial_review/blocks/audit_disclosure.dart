import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/design/app_design_tokens.dart';
import '../../../../../core/providers.dart';
import '../../../../../domain/trial_cognition/trial_coherence_dto.dart';
import '../../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../trial_overview/_overview_card.dart';

class AuditDisclosure extends ConsumerWidget {
  const AuditDisclosure({
    super.key,
    required this.trial,
  });

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final coherenceAsync = ref.watch(trialCoherenceProvider(trial.id));

    return ctqAsync.when(
      loading: () => const OverviewSectionLoading(),
      error: (_, __) => const OverviewSectionError(),
      data: (ctq) => coherenceAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (coherence) => AuditDisclosureBody(
          ctqItems: ctq.ctqItems,
          coherenceChecks: coherence.checks,
        ),
      ),
    );
  }
}

@visibleForTesting
class AuditDisclosureBody extends StatefulWidget {
  const AuditDisclosureBody({
    super.key,
    required this.ctqItems,
    required this.coherenceChecks,
  });

  final List<TrialCtqItemDto> ctqItems;
  final List<TrialCoherenceCheckDto> coherenceChecks;

  @override
  State<AuditDisclosureBody> createState() => _AuditDisclosureBodyState();
}

class _AuditDisclosureBodyState extends State<AuditDisclosureBody> {
  bool _expanded = false;

  int get _satisfiedCount {
    final ctqSatisfied =
        widget.ctqItems.where((item) => item.status == 'satisfied').length;
    final coherenceAligned = widget.coherenceChecks
        .where((check) => check.status == 'aligned')
        .length;
    return ctqSatisfied + coherenceAligned;
  }

  int get _pendingCount {
    return widget.ctqItems.length +
        widget.coherenceChecks.length -
        _satisfiedCount;
  }

  static const _headerStyle = TextStyle(
    fontSize: 14,
    color: AppDesignTokens.primary,
    fontWeight: FontWeight.w600,
  );

  Widget _buildCollapsedHeader() {
    if (_pendingCount == 0) {
      final label = _satisfiedCount == 0
          ? 'Show all checks (0 satisfied, 0 pending)'
          : 'All $_satisfiedCount checks satisfied';
      return Text(label, style: _headerStyle);
    }

    // Pending > 0: color just the pending count with the review-needed token.
    return RichText(
      text: TextSpan(
        style: _headerStyle,
        children: [
          const TextSpan(text: 'Review pending checks — '),
          TextSpan(
            text: '$_pendingCount pending',
            style: const TextStyle(color: AppDesignTokens.partialFg),
          ),
          TextSpan(text: ', $_satisfiedCount satisfied'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('audit-disclosure'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _expanded
                    ? const Text('Hide all checks', style: _headerStyle)
                    : _buildCollapsedHeader(),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: AppDesignTokens.primary,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          if (widget.ctqItems.isEmpty && widget.coherenceChecks.isEmpty)
            Text(
              'No checks evaluated yet.',
              style: AppDesignTokens.bodyStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ),
            )
          else ...[
            ...widget.ctqItems.map(_AuditCtqRow.new),
            ...widget.coherenceChecks.map(_AuditCoherenceRow.new),
          ],
        ],
      ],
    );
  }
}

class _AuditCtqRow extends StatelessWidget {
  const _AuditCtqRow(this.item);

  final TrialCtqItemDto item;

  @override
  Widget build(BuildContext context) {
    final status = _ctqStatus(item);
    return _AuditRow(
      label: item.label,
      reason: item.reason,
      status: status,
      acknowledged: item.isAcknowledged,
    );
  }
}

class _AuditCoherenceRow extends StatelessWidget {
  const _AuditCoherenceRow(this.check);

  final TrialCoherenceCheckDto check;

  @override
  Widget build(BuildContext context) {
    return _AuditRow(
      label: check.label,
      reason: check.reason,
      status: _coherenceStatus(check),
      acknowledged: false,
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.label,
    required this.reason,
    required this.status,
    required this.acknowledged,
  });

  final String label;
  final String reason;
  final _AuditStatus status;
  final bool acknowledged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppDesignTokens.headingStyle(
                    fontSize: 14,
                    color: AppDesignTokens.primaryText,
                  ).copyWith(height: 1.25),
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              OverviewStatusChip(
                label: status.label,
                bg: status.bg,
                fg: status.fg,
              ),
              if (acknowledged) ...[
                const SizedBox(width: AppDesignTokens.spacing4),
                const OverviewStatusChip(
                  label: 'Acknowledged',
                  bg: AppDesignTokens.emptyBadgeBg,
                  fg: AppDesignTokens.emptyBadgeFg,
                ),
              ],
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              reason,
              style: AppDesignTokens.bodyStyle(
                fontSize: 13,
                color: AppDesignTokens.secondaryText,
              ).copyWith(height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditStatus {
  const _AuditStatus({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;
}

_AuditStatus _ctqStatus(TrialCtqItemDto item) {
  return switch (item.status) {
    'satisfied' => const _AuditStatus(
        label: 'Satisfied',
        bg: AppDesignTokens.successBg,
        fg: AppDesignTokens.successFg,
      ),
    'blocked' => const _AuditStatus(
        label: 'Blocked',
        bg: AppDesignTokens.warningBg,
        fg: AppDesignTokens.warningFg,
      ),
    'review_needed' => const _AuditStatus(
        label: 'Review needed',
        bg: AppDesignTokens.partialBg,
        fg: AppDesignTokens.partialFg,
      ),
    'missing' => const _AuditStatus(
        label: 'Missing',
        bg: AppDesignTokens.warningBg,
        fg: AppDesignTokens.warningFg,
      ),
    _ => const _AuditStatus(
        label: 'Not evaluated',
        bg: AppDesignTokens.emptyBadgeBg,
        fg: AppDesignTokens.emptyBadgeFg,
      ),
  };
}

_AuditStatus _coherenceStatus(TrialCoherenceCheckDto check) {
  return switch (check.status) {
    'aligned' => const _AuditStatus(
        label: 'Aligned',
        bg: AppDesignTokens.successBg,
        fg: AppDesignTokens.successFg,
      ),
    'review_needed' => const _AuditStatus(
        label: 'Review needed',
        bg: AppDesignTokens.partialBg,
        fg: AppDesignTokens.partialFg,
      ),
    'cannot_evaluate' => const _AuditStatus(
        label: 'Cannot evaluate',
        bg: AppDesignTokens.emptyBadgeBg,
        fg: AppDesignTokens.emptyBadgeFg,
      ),
    _ => const _AuditStatus(
        label: 'Not evaluated',
        bg: AppDesignTokens.emptyBadgeBg,
        fg: AppDesignTokens.emptyBadgeFg,
      ),
  };
}
