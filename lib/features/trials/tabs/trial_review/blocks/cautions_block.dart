import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/design/app_design_tokens.dart';
import '../../../../../core/providers.dart';
import '../../../../../domain/signals/signal_providers.dart';
import '../../../../../domain/signals/signal_review_projection.dart';
import '../../../../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../../../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../../../../domain/trial_cognition/trial_interpretation_risk_dto.dart';
import '../../../../../domain/trial_cognition/trial_readiness_statement.dart';
import '../../../widgets/signal_action_sheet.dart';
import '../../trial_overview/_overview_card.dart';

class CautionsBlock extends ConsumerWidget {
  const CautionsBlock({
    super.key,
    required this.trial,
  });

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statementAsync = ref.watch(trialReadinessStatementProvider((
      trialId: trial.id,
      trialState: trial.status,
    )));
    final riskAsync = ref.watch(trialInterpretationRiskProvider(trial.id));
    final signalGroupsAsync =
        ref.watch(projectedOpenSignalGroupsForTrialProvider(trial.id));
    final rawSignalsAsync = ref.watch(openSignalsForTrialProvider(trial.id));
    final environmentalSummaryAsync =
        ref.watch(trialEnvironmentalSummaryProvider(trial.id));
    final environmentalProvenanceAsync =
        ref.watch(trialEnvironmentalProvenanceProvider(trial.id));
    final ctqAsync = ref.watch(trialCriticalToQualityProvider(trial.id));
    final assessmentDefinitionsAsync = ref.watch(assessmentDefinitionsProvider);

    if (_hasBlockingError(statementAsync) ||
        _hasBlockingError(riskAsync) ||
        _hasBlockingError(signalGroupsAsync) ||
        _hasBlockingError(rawSignalsAsync) ||
        _hasBlockingError(environmentalSummaryAsync) ||
        _hasBlockingError(environmentalProvenanceAsync) ||
        _hasBlockingError(ctqAsync) ||
        _hasBlockingError(assessmentDefinitionsAsync)) {
      return const OverviewSectionError();
    }

    if (_isWaiting(statementAsync) ||
        _isWaiting(riskAsync) ||
        _isWaiting(signalGroupsAsync) ||
        _isWaiting(rawSignalsAsync) ||
        _isWaiting(environmentalSummaryAsync) ||
        _isWaiting(environmentalProvenanceAsync) ||
        _isWaiting(ctqAsync) ||
        _isWaiting(assessmentDefinitionsAsync)) {
      return const OverviewSectionLoading();
    }

    return CautionsBlockBody(
      trial: trial,
      statement: statementAsync.requireValue,
      risk: riskAsync.requireValue,
      signalGroups: signalGroupsAsync.requireValue,
      rawSignals: rawSignalsAsync.requireValue,
      environmentalSummary: environmentalSummaryAsync.requireValue,
      ctq: ctqAsync.requireValue,
      assessmentDefinitions: assessmentDefinitionsAsync.requireValue,
    );
  }

  bool _isWaiting(AsyncValue<dynamic> value) =>
      value.isLoading && !value.hasValue;

  bool _hasBlockingError(AsyncValue<dynamic> value) =>
      value.hasError && !value.hasValue;
}

@visibleForTesting
class CautionsBlockBody extends StatelessWidget {
  const CautionsBlockBody({
    super.key,
    required this.trial,
    required this.statement,
    required this.risk,
    required this.signalGroups,
    required this.rawSignals,
    required this.environmentalSummary,
    required this.ctq,
    required this.assessmentDefinitions,
    this.onOpenSignalAction,
  });

  final Trial trial;
  final TrialReadinessStatement statement;
  final TrialInterpretationRiskDto risk;
  final List<SignalReviewGroupProjection> signalGroups;
  final List<Signal> rawSignals;
  final EnvironmentalSeasonSummaryDto environmentalSummary;
  final TrialCtqDto ctq;
  final List<AssessmentDefinition> assessmentDefinitions;
  final void Function(Signal signal)? onOpenSignalAction;

  @override
  Widget build(BuildContext context) {
    final assessmentNameById = {
      for (final definition in assessmentDefinitions)
        definition.id: definition.name,
    };
    final rawSignalsById = {for (final signal in rawSignals) signal.id: signal};
    final items = _buildCautionItems(
      assessmentNameById: assessmentNameById,
      rawSignalsById: rawSignalsById,
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('cautions-block-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDesignTokens.spacing8),
          _CautionCard(
            item: items[i],
            onTap: _onTapFor(context, items[i]),
          ),
        ],
      ],
    );
  }

  List<_CautionItem> _buildCautionItems({
    required Map<int, String> assessmentNameById,
    required Map<int, Signal> rawSignalsById,
  }) {
    final riskFactors = risk.factors
        .where((factor) =>
            factor.severity == 'moderate' || factor.severity == 'high')
        .toList();
    final items = <_CautionItem>[
      ..._dedupedCautionStrings(statement.cautions, riskFactors)
          .map(_CautionItem.statement),
      ...riskFactors.map((factor) => _CautionItem.risk(
            factor,
            suppressReason: false,
          )),
      ..._signalCautions(
        signalGroups,
        rawSignalsById: rawSignalsById,
        assessmentNameById: assessmentNameById,
      ),
    ];

    final environmental = _environmentalCaution(environmentalSummary, trial);
    if (environmental != null) items.add(environmental);

    items.addAll(ctq.ctqItems
        .where((item) => item.needsReview && item.isAcknowledged)
        .map(_CautionItem.ctqAcknowledged));

    return items;
  }

  VoidCallback? _onTapFor(BuildContext context, _CautionItem item) {
    final signal = item.signal;
    if (signal == null) return null;
    return () {
      if (onOpenSignalAction != null) {
        onOpenSignalAction!(signal);
        return;
      }
      showSignalActionSheet(context, signal: signal, trialId: trial.id);
    };
  }
}

List<String> _dedupedCautionStrings(
  List<String> cautions,
  List<TrialRiskFactorDto> riskFactors,
) {
  return cautions
      .where((caution) => !riskFactors.any(
            (factor) => _riskReasonIsCoveredByCaution(factor, [caution]),
          ))
      .toList(growable: false);
}

bool _riskReasonIsCoveredByCaution(
  TrialRiskFactorDto factor,
  List<String> cautions,
) {
  final reason = factor.reason.trim();
  if (reason.isEmpty) return false;
  return cautions.any((caution) => caution.contains(reason));
}

List<_CautionItem> _signalCautions(
  List<SignalReviewGroupProjection> groups, {
  required Map<int, Signal> rawSignalsById,
  required Map<int, String> assessmentNameById,
}) {
  final nonBlocking = groups
      .where((group) =>
          group.memberSignals.every((signal) => !signal.blocksExport))
      .toList();
  final grouped = <String, List<SignalReviewGroupProjection>>{};
  final items = <_CautionItem>[];

  for (final group in nonBlocking) {
    if (group.familyKey == SignalFamilyKey.untreatedCheckVariance &&
        group.affectedSessionIds.length == 1) {
      final sessionId = group.affectedSessionIds.single;
      grouped.putIfAbsent('untreated:$sessionId', () => []).add(group);
    } else {
      items.add(_CautionItem.signal(
        group: group,
        rawSignalsById: rawSignalsById,
        assessmentNameById: assessmentNameById,
      ));
    }
  }

  for (final entry in grouped.entries) {
    final sameSessionGroups = entry.value;
    if (sameSessionGroups.length == 1) {
      items.add(_CautionItem.signal(
        group: sameSessionGroups.single,
        rawSignalsById: rawSignalsById,
        assessmentNameById: assessmentNameById,
      ));
    } else {
      items.add(_CautionItem.collapsedSignalGroup(
        groups: sameSessionGroups,
        rawSignalsById: rawSignalsById,
        assessmentNameById: assessmentNameById,
      ));
    }
  }

  return items;
}

_CautionItem? _environmentalCaution(
  EnvironmentalSeasonSummaryDto summary,
  Trial trial,
) {
  if (trial.latitude == null || trial.longitude == null) {
    return const _CautionItem._(
      kind: _CautionItemKind.environmental,
      title: 'Environmental evidence not available yet.',
      reason:
          'Trial site coordinates are required for environmental evidence. Rating/session GPS may exist for provenance, but it is not currently linked as the trial site reference.',
      chipLabel: 'Unavailable',
      chipTone: _ChipTone.neutral,
    );
  }

  return switch (summary.overallConfidence) {
    'estimated' => const _CautionItem._(
        kind: _CautionItemKind.environmental,
        title: 'Environmental evidence is estimated.',
        reason:
            'Some environmental records are estimated. Review conditions before interpreting results.',
        chipLabel: 'Estimated',
        chipTone: _ChipTone.moderate,
      ),
    'unavailable' => const _CautionItem._(
        kind: _CautionItemKind.environmental,
        title: 'Environmental evidence not available yet.',
        reason: 'No environmental records have been fetched yet.',
        chipLabel: 'Unavailable',
        chipTone: _ChipTone.neutral,
      ),
    _ => null,
  };
}

enum _CautionItemKind {
  statement,
  risk,
  signal,
  environmental,
  ctqAcknowledged,
}

enum _ChipTone {
  high,
  moderate,
  neutral,
}

class _CautionItem {
  const _CautionItem._({
    required this.kind,
    required this.title,
    required this.reason,
    this.chipLabel,
    this.chipTone = _ChipTone.neutral,
    this.secondaryChips = const [],
    this.signal,
    this.acknowledgmentText,
  });

  factory _CautionItem.statement(String caution) {
    return _CautionItem._(
      kind: _CautionItemKind.statement,
      title: 'Caution',
      reason: caution,
    );
  }

  factory _CautionItem.risk(
    TrialRiskFactorDto factor, {
    required bool suppressReason,
  }) {
    final isHigh = factor.severity == 'high';
    return _CautionItem._(
      kind: _CautionItemKind.risk,
      title: factor.label,
      reason: suppressReason ? '' : factor.reason,
      chipLabel: isHigh ? 'HIGH' : 'MODERATE',
      chipTone: isHigh ? _ChipTone.high : _ChipTone.moderate,
    );
  }

  factory _CautionItem.signal({
    required SignalReviewGroupProjection group,
    required Map<int, Signal> rawSignalsById,
    required Map<int, String> assessmentNameById,
  }) {
    final rawSignal = _firstRawSignal(group, rawSignalsById);
    final chips =
        _assessmentNames(group.affectedAssessmentIds, assessmentNameById);
    return _CautionItem._(
      kind: _CautionItemKind.signal,
      title: chips.length == 1 ? chips.single : group.displayTitle,
      reason: rawSignal?.consequenceText ?? group.shortSummary,
      chipLabel: group.severityLabel,
      chipTone: _signalTone(group),
      secondaryChips: chips.length > 1 ? chips : const [],
      signal: rawSignal,
    );
  }

  factory _CautionItem.collapsedSignalGroup({
    required List<SignalReviewGroupProjection> groups,
    required Map<int, Signal> rawSignalsById,
    required Map<int, String> assessmentNameById,
  }) {
    final firstGroup = groups.first;
    final rawSignal = _firstRawSignal(firstGroup, rawSignalsById);
    final chips = <String>{
      for (final group in groups)
        ..._assessmentNames(group.affectedAssessmentIds, assessmentNameById),
    }.toList();
    return _CautionItem._(
      kind: _CautionItemKind.signal,
      title: 'Untreated check reliability may need review',
      reason: rawSignal?.consequenceText ?? firstGroup.shortSummary,
      chipLabel: firstGroup.severityLabel,
      chipTone: _signalTone(firstGroup),
      secondaryChips: chips,
      signal: rawSignal,
    );
  }

  factory _CautionItem.ctqAcknowledged(TrialCtqItemDto item) {
    final ack = item.latestAcknowledgment;
    final acknowledgmentText = ack == null
        ? null
        : 'Acknowledged ${DateFormat('MMM d, y').format(ack.acknowledgedAt)}'
            '${ack.actorName != null ? ' by ${ack.actorName}' : ''}';
    return _CautionItem._(
      kind: _CautionItemKind.ctqAcknowledged,
      title: item.label,
      reason: item.reason,
      chipLabel: 'Acknowledged',
      chipTone: _ChipTone.neutral,
      acknowledgmentText: acknowledgmentText,
    );
  }

  final _CautionItemKind kind;
  final String title;
  final String reason;
  final String? chipLabel;
  final _ChipTone chipTone;
  final List<String> secondaryChips;
  final Signal? signal;
  final String? acknowledgmentText;
}

Signal? _firstRawSignal(
  SignalReviewGroupProjection group,
  Map<int, Signal> rawSignalsById,
) {
  for (final member in group.memberSignals) {
    final signal = rawSignalsById[member.signalId];
    if (signal != null) return signal;
  }
  return null;
}

List<String> _assessmentNames(
  List<int> assessmentIds,
  Map<int, String> assessmentNameById,
) {
  return [
    for (final id in assessmentIds) assessmentNameById[id] ?? 'Assessment $id',
  ];
}

_ChipTone _signalTone(SignalReviewGroupProjection group) {
  final hasHigh =
      group.memberSignals.any((signal) => signal.severity == 'critical');
  final hasModerate =
      group.memberSignals.any((signal) => signal.severity == 'review');
  if (hasHigh) return _ChipTone.high;
  if (hasModerate) return _ChipTone.moderate;
  return _ChipTone.neutral;
}

class _CautionCard extends StatelessWidget {
  const _CautionCard({
    required this.item,
    required this.onTap,
  });

  final _CautionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      child: Container(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: AppDesignTokens.headingStyle(
                      fontSize: 14,
                      color: AppDesignTokens.primaryText,
                    ).copyWith(height: 1.25),
                  ),
                ),
                if (item.chipLabel != null) ...[
                  const SizedBox(width: AppDesignTokens.spacing8),
                  _ToneChip(label: item.chipLabel!, tone: item.chipTone),
                ],
              ],
            ),
            if (item.secondaryChips.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.spacing8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final chip in item.secondaryChips)
                    _ToneChip(label: chip, tone: _ChipTone.neutral),
                ],
              ),
            ],
            if (item.reason.isNotEmpty) ...[
              const SizedBox(height: AppDesignTokens.spacing4),
              Text(
                item.reason,
                style: AppDesignTokens.bodyStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                ).copyWith(height: 1.35),
              ),
            ],
            if (item.acknowledgmentText != null) ...[
              const SizedBox(height: AppDesignTokens.spacing4),
              Text(
                item.acknowledgmentText!,
                style: AppDesignTokens.compactActionLabelStyle.copyWith(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: AppDesignTokens.spacing4),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppDesignTokens.secondaryText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _ChipTone.high => (AppDesignTokens.warningBg, AppDesignTokens.warningFg),
      _ChipTone.moderate => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg
        ),
      _ChipTone.neutral => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
        ),
    };
    return OverviewStatusChip(label: label, bg: bg, fg: fg);
  }
}
