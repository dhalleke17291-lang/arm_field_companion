import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/design/app_design_tokens.dart';
import '../../../../../core/providers.dart';
import '../../../../../core/workspace/workspace_config.dart';
import '../../../../../domain/signals/signal_providers.dart';
import '../../../../../domain/signals/signal_review_projection.dart';
import '../../../../../domain/trial_cognition/trial_coherence_dto.dart';
import '../../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../../../../domain/trial_cognition/trial_purpose_dto.dart';
import '../../../../../domain/trial_cognition/trial_readiness_statement.dart';
import '../../../trial_data_screen.dart';
import '../../../widgets/ctq_acknowledgment_sheet.dart';
import '../../../widgets/signal_action_sheet.dart';
import '../../trial_intent_sheet.dart';
import '../../trial_overview/_overview_card.dart';

class RequiredBlock extends ConsumerWidget {
  const RequiredBlock({
    super.key,
    required this.trial,
    required this.onSwitchTab,
  });

  final Trial trial;
  final void Function(TrialTab tab) onSwitchTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementAsync = ref.watch(trialReadinessStatementProvider((
      trialId: trial.id,
      trialState: trial.status,
    )));
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final coherenceAsync = ref.watch(trialCoherenceProvider(trial.id));
    final signalGroupsAsync =
        ref.watch(projectedOpenSignalGroupsForTrialProvider(trial.id));
    final rawSignalsAsync = ref.watch(openSignalsForTrialProvider(trial.id));
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));

    if (_hasBlockingError(statementAsync) ||
        _hasBlockingError(ctqAsync) ||
        _hasBlockingError(coherenceAsync) ||
        _hasBlockingError(signalGroupsAsync) ||
        _hasBlockingError(rawSignalsAsync) ||
        _hasBlockingError(purposeAsync)) {
      return const OverviewSectionError();
    }

    if (_isWaiting(statementAsync) ||
        _isWaiting(ctqAsync) ||
        _isWaiting(coherenceAsync) ||
        _isWaiting(signalGroupsAsync) ||
        _isWaiting(rawSignalsAsync) ||
        _isWaiting(purposeAsync)) {
      return const OverviewSectionLoading();
    }

    return RequiredBlockBody(
      trial: trial,
      statement: statementAsync.requireValue,
      ctq: ctqAsync.requireValue,
      coherence: coherenceAsync.requireValue,
      signalGroups: signalGroupsAsync.requireValue,
      rawSignals: rawSignalsAsync.requireValue,
      purpose: purposeAsync.requireValue,
      onSwitchTab: onSwitchTab,
    );
  }

  bool _isWaiting(AsyncValue<dynamic> value) =>
      value.isLoading && !value.hasValue;

  bool _hasBlockingError(AsyncValue<dynamic> value) =>
      value.hasError && !value.hasValue;
}

@visibleForTesting
class RequiredBlockBody extends ConsumerWidget {
  const RequiredBlockBody({
    super.key,
    required this.trial,
    required this.statement,
    required this.ctq,
    required this.coherence,
    required this.signalGroups,
    required this.rawSignals,
    required this.purpose,
    required this.onSwitchTab,
    this.onOpenCtqAcknowledgment,
    this.onOpenSignalAction,
    this.onOpenIntent,
  });

  final Trial trial;
  final TrialReadinessStatement statement;
  final TrialCtqDto ctq;
  final TrialCoherenceDto coherence;
  final List<SignalReviewGroupProjection> signalGroups;
  final List<Signal> rawSignals;
  final TrialPurposeDto purpose;
  final void Function(TrialTab tab) onSwitchTab;
  final void Function(TrialCtqItemDto item)? onOpenCtqAcknowledgment;
  final void Function(Signal signal)? onOpenSignalAction;
  final VoidCallback? onOpenIntent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawSignalsById = {for (final signal in rawSignals) signal.id: signal};
    final items = _buildRequiredItems(
      statement: statement,
      ctq: ctq,
      coherence: coherence,
      signalGroups: signalGroups,
      rawSignalsById: rawSignalsById,
      purpose: purpose,
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('required-block-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RequiredBlockHeader(),
        const SizedBox(height: AppDesignTokens.spacing8),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDesignTokens.spacing8),
          _RequiredItemCard(
            item: items[i],
            onPressed: _actionFor(context, ref, items[i]),
          ),
        ],
      ],
    );
  }

  // Required items come from two paths:
  //   1. CTQ and coherence items that produced strings in
  //      statement.actionItems (we walk the source DTOs because
  //      the strings aren't structured for routing).
  //   2. Signal-blocked groups and unconfirmed intent (not in
  //      actionItems today - read directly from their providers).
  // If the readiness function ever surfaces signal/intent in
  // actionItems, the widget logic remains correct.
  List<_RequiredItem> _buildRequiredItems({
    required TrialReadinessStatement statement,
    required TrialCtqDto ctq,
    required TrialCoherenceDto coherence,
    required List<SignalReviewGroupProjection> signalGroups,
    required Map<int, Signal> rawSignalsById,
    required TrialPurposeDto purpose,
  }) {
    final actionItems = statement.actionItems.toSet();
    final items = <_RequiredItem>[
      ..._ctqItems(ctq.ctqItems, actionItems),
      ..._coherenceItems(coherence.checks, actionItems),
      ..._signalItems(signalGroups, rawSignalsById),
    ];

    if (purpose.requiresConfirmation) {
      items.add(_RequiredItem.intent());
    }

    return items;
  }

  List<_RequiredItem> _ctqItems(
    List<TrialCtqItemDto> ctqItems,
    Set<String> actionItems,
  ) {
    final items = <_RequiredItem>[];

    for (final item in ctqItems.where((item) => item.isBlocked)) {
      if (actionItems.contains('Resolve: ${item.label}')) {
        items.add(_RequiredItem.ctq(item));
      }
    }

    for (final item in ctqItems.where((item) => item.status == 'missing')) {
      final action = _missingActionStrings[item.factorKey];
      if (action != null && actionItems.contains(action)) {
        items.add(_RequiredItem.ctq(item));
      }
    }

    for (final item
        in ctqItems.where((item) => item.needsReview && !item.isAcknowledged)) {
      if (actionItems.contains('Review: ${item.label}')) {
        items.add(_RequiredItem.ctq(item));
      }
    }

    return items;
  }

  List<_RequiredItem> _coherenceItems(
    List<TrialCoherenceCheckDto> checks,
    Set<String> actionItems,
  ) {
    final items = <_RequiredItem>[];

    for (final check in checks.where((c) => c.status == 'review_needed')) {
      if (actionItems.contains('Review deviation: ${check.label}')) {
        items.add(_RequiredItem.coherence(check));
      }
    }

    for (final check in checks.where((c) => c.status == 'cannot_evaluate')) {
      if (actionItems.contains('Provide missing input for: ${check.label}')) {
        items.add(_RequiredItem.coherence(check));
      }
    }

    return items;
  }

  List<_RequiredItem> _signalItems(
    List<SignalReviewGroupProjection> groups,
    Map<int, Signal> rawSignalsById,
  ) {
    final items = <_RequiredItem>[];

    for (final group in groups) {
      SignalReviewProjection? firstBlocking;
      for (final member in group.memberSignals) {
        if (member.blocksExport) {
          firstBlocking = member;
          break;
        }
      }
      if (firstBlocking == null) continue;

      // Opens sheet for the first blocking raw signal. Matches existing
      // Section 9 convention. If a group contains multiple blocking
      // signals, the others are addressable from the sheet itself.
      items.add(_RequiredItem.signalGroup(
        group: group,
        blockingMember: firstBlocking,
        rawSignal: rawSignalsById[firstBlocking.signalId],
      ));
    }

    return items;
  }

  VoidCallback? _actionFor(
    BuildContext context,
    WidgetRef ref,
    _RequiredItem item,
  ) {
    switch (item.kind) {
      case _RequiredItemKind.ctq:
        final ctq = item.ctqItem!;
        if (ctq.factorKey == 'rater_consistency' && ctq.isBlocked) {
          final rawSignal = _firstRaterSignal(rawSignals);
          if (rawSignal == null) return null;
          return () => _openSignal(context, rawSignal);
        }
        if (ctq.needsReview && !ctq.isAcknowledged) {
          return () => _openCtqAcknowledgment(context, ctq);
        }
        return _ctqRoute(context, ctq.factorKey);
      case _RequiredItemKind.coherence:
        return null;
      case _RequiredItemKind.signalGroup:
        final rawSignal = item.rawSignal;
        if (rawSignal == null) return null;
        return () => _openSignal(context, rawSignal);
      case _RequiredItemKind.intent:
        return () {
          if (onOpenIntent != null) {
            onOpenIntent!();
            return;
          }
          showTrialIntentSheet(context, ref, trial: trial);
        };
    }
  }

  VoidCallback? _ctqRoute(BuildContext context, String factorKey) {
    return switch (factorKey) {
      'plot_completeness' => () => onSwitchTab(TrialTab.plots),
      'treatment_identity' => () => onSwitchTab(TrialTab.treatments),
      'photo_evidence' => () => onSwitchTab(TrialTab.photos),
      'gps_evidence' => () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TrialDataScreen(trial: trial),
            ),
          ),
      'application_timing' => () => onSwitchTab(TrialTab.applications),
      'rating_window' => () => onSwitchTab(TrialTab.assessments),
      _ => null,
    };
  }

  void _openCtqAcknowledgment(BuildContext context, TrialCtqItemDto item) {
    if (onOpenCtqAcknowledgment != null) {
      onOpenCtqAcknowledgment!(item);
      return;
    }
    showCtqAcknowledgmentSheet(context, item: item, trialId: trial.id);
  }

  void _openSignal(BuildContext context, Signal signal) {
    if (onOpenSignalAction != null) {
      onOpenSignalAction!(signal);
      return;
    }
    showSignalActionSheet(context, signal: signal, trialId: trial.id);
  }
}

class _RequiredBlockHeader extends StatelessWidget {
  const _RequiredBlockHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required before export',
          style: TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppDesignTokens.primaryText,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Complete these cards to clear Trial Review readiness.',
          style: TextStyle(
            fontSize: 12,
            height: 1.25,
            color: AppDesignTokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

const _missingActionStrings = <String, String>{
  'plot_completeness': 'Complete: Plot Completeness',
  'photo_evidence': 'Add: Photo Evidence',
  'gps_evidence': 'Enable: GPS Evidence',
  'treatment_identity': 'Define: Treatment Identity',
  'application_timing': 'Record: Application Timing',
  'rating_window': 'Record: Rating Window',
};

Signal? _firstRaterSignal(List<Signal> signals) {
  for (final signal in signals) {
    if (signal.signalType == 'rater_drift' ||
        signal.signalType == 'between_rater_divergence') {
      return signal;
    }
  }
  return null;
}

enum _RequiredItemKind {
  ctq,
  coherence,
  signalGroup,
  intent,
}

class _RequiredItem {
  const _RequiredItem._({
    required this.kind,
    required this.title,
    required this.reason,
    required this.actionLabel,
    this.disabledTooltip,
    this.ctqItem,
    this.rawSignal,
  });

  factory _RequiredItem.ctq(TrialCtqItemDto item) {
    final (actionLabel, disabledTooltip) =
        item.factorKey == 'rater_consistency' && item.isBlocked
            ? ('Review signal', 'No matching rater signal available.')
            : (_ctqActionLabel(item), null);
    return _RequiredItem._(
      kind: _RequiredItemKind.ctq,
      title: item.label,
      reason: item.reason,
      actionLabel: actionLabel,
      disabledTooltip: disabledTooltip,
      ctqItem: item,
    );
  }

  factory _RequiredItem.coherence(TrialCoherenceCheckDto check) {
    return _RequiredItem._(
      kind: _RequiredItemKind.coherence,
      title: check.label,
      reason: check.reason,
      actionLabel: null,
    );
  }

  factory _RequiredItem.signalGroup({
    required SignalReviewGroupProjection group,
    required SignalReviewProjection blockingMember,
    required Signal? rawSignal,
  }) {
    return _RequiredItem._(
      kind: _RequiredItemKind.signalGroup,
      title: group.displayTitle,
      reason: blockingMember.blocksExportReason ?? group.shortSummary,
      actionLabel: 'Review signal',
      disabledTooltip:
          rawSignal == null ? 'No matching signal available.' : null,
      rawSignal: rawSignal,
    );
  }

  factory _RequiredItem.intent() {
    return const _RequiredItem._(
      kind: _RequiredItemKind.intent,
      title: 'Intent — not yet confirmed',
      reason: 'Trial intent was inferred and needs researcher confirmation.',
      actionLabel: 'Confirm intent',
    );
  }

  final _RequiredItemKind kind;
  final String title;
  final String reason;
  final String? actionLabel;
  final String? disabledTooltip;
  final TrialCtqItemDto? ctqItem;
  final Signal? rawSignal;
}

String? _ctqActionLabel(TrialCtqItemDto item) {
  if (item.needsReview && !item.isAcknowledged) return 'Review';
  return switch (item.factorKey) {
    'plot_completeness' => 'Open Plots',
    'treatment_identity' => 'Open Treatments',
    'photo_evidence' => 'Open Photos',
    'gps_evidence' => 'View Data',
    'application_timing' => 'Open Applications',
    'rating_window' => 'Open Assessments',
    _ => null,
  };
}

class _RequiredItemCard extends StatelessWidget {
  const _RequiredItemCard({
    required this.item,
    required this.onPressed,
  });

  final _RequiredItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      decoration: BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            style: AppDesignTokens.headingStyle(
              fontSize: 14,
              color: AppDesignTokens.primaryText,
            ).copyWith(height: 1.25),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          Text(
            item.reason,
            style: AppDesignTokens.bodyStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ).copyWith(height: 1.35),
          ),
          if (item.actionLabel != null) ...[
            const SizedBox(height: AppDesignTokens.spacing8),
            _ActionButton(
              label: item.actionLabel!,
              onPressed: onPressed,
              disabledTooltip: onPressed == null ? item.disabledTooltip : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.disabledTooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? disabledTooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      key: ValueKey('required-action-$label'),
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    if (onPressed == null &&
        disabledTooltip != null &&
        disabledTooltip!.isNotEmpty) {
      return Tooltip(message: disabledTooltip!, child: button);
    }
    return button;
  }
}
