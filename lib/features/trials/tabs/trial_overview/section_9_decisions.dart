import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/signals/signal_providers.dart';
import '../../../../domain/signals/signal_review_projection.dart';
import '../../widgets/signal_action_sheet.dart';
import '_overview_card.dart';

class Section9Decisions extends ConsumerWidget {
  const Section9Decisions({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(trialDecisionSummaryProvider(trial.id));
    final signalsAsync =
        ref.watch(projectedOpenSignalGroupsForTrialProvider(trial.id));
    final rawSignalsAsync = ref.watch(openSignalsForTrialProvider(trial.id));

    return OverviewSectionCard(
      number: 9,
      title: 'Review Items and Decisions',
      child: decisionsAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (decisions) => signalsAsync.when(
          loading: () => const OverviewSectionLoading(),
          error: (_, __) => const OverviewSectionError(),
          data: (signals) {
            final rawSignalsById = {
              for (final signal
                  in rawSignalsAsync.valueOrNull ?? const <Signal>[])
                signal.id: signal,
            };
            final hasContent = signals.isNotEmpty ||
                decisions.signalDecisions.isNotEmpty ||
                decisions.ctqAcknowledgments.isNotEmpty;

            if (!hasContent) {
              return const Text(
                'No review items or documented decisions.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.secondaryText,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (signals.isNotEmpty) ...[
                  const Text(
                    'NEEDS REVIEW',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing4),
                  ...signals.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDesignTokens.spacing8,
                      ),
                      child: _SignalGroupRow(
                        group: s,
                        trialId: trial.id,
                        rawSignalsById: rawSignalsById,
                      ),
                    ),
                  ),
                ],
                if (decisions.signalDecisions.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  const Text(
                    'RESEARCHER DECISIONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing4),
                  ...decisions.signalDecisions.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _DecisionRow(
                        eventType: d.eventType,
                        note: d.note,
                        actorName: d.actorName,
                        occurredAt: d.occurredAt,
                      ),
                    ),
                  ),
                ],
                if (decisions.ctqAcknowledgments.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  const Text(
                    'CTQ ACKNOWLEDGMENTS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppDesignTokens.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing4),
                  ...decisions.ctqAcknowledgments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${a.factorKey.replaceAll('_', ' ')}: '
                        '${a.reason.length > 80 ? '${a.reason.substring(0, 80)}…' : a.reason}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppDesignTokens.primaryText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SignalGroupRow extends StatefulWidget {
  const _SignalGroupRow({
    required this.group,
    required this.trialId,
    required this.rawSignalsById,
  });

  final SignalReviewGroupProjection group;
  final int trialId;
  final Map<int, Signal> rawSignalsById;

  @override
  State<_SignalGroupRow> createState() => _SignalGroupRowState();
}

class _SignalGroupRowState extends State<_SignalGroupRow> {
  bool _expanded = false;

  static (Color, Color) _severityColors(SignalReviewGroupProjection group) {
    final hasExportBlock = group.memberSignals.any((s) => s.blocksExport);
    final hasCritical =
        group.memberSignals.any((s) => s.severity == 'critical');
    final hasReview = group.memberSignals.any((s) => s.severity == 'review');

    return switch ((hasCritical, hasReview, hasExportBlock)) {
      (true, _, true) => (AppDesignTokens.warningBg, AppDesignTokens.warningFg),
      (true, _, false) => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg
        ),
      (_, true, _) => (AppDesignTokens.partialBg, AppDesignTokens.partialFg),
      _ => (AppDesignTokens.emptyBadgeBg, AppDesignTokens.emptyBadgeFg),
    };
  }

  String? get _affectedSummary {
    final group = widget.group;
    final parts = <String>[
      if (group.affectedAssessmentIds.isNotEmpty)
        '${group.affectedAssessmentIds.length} assessment${group.affectedAssessmentIds.length == 1 ? '' : 's'}',
      if (group.affectedSessionIds.isNotEmpty)
        '${group.affectedSessionIds.length} session${group.affectedSessionIds.length == 1 ? '' : 's'}',
      if (group.affectedPlotIds.isNotEmpty)
        '${group.affectedPlotIds.length} plot${group.affectedPlotIds.length == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Signal? _rawSignalFor(SignalReviewProjection member) =>
      widget.rawSignalsById[member.signalId];

  void _openSignal(BuildContext context, SignalReviewProjection member) {
    final rawSignal = _rawSignalFor(member);
    if (rawSignal == null) return;
    showSignalActionSheet(
      context,
      signal: rawSignal,
      trialId: widget.trialId,
    );
  }

  void _handleTap(BuildContext context) {
    if (widget.group.memberSignals.length == 1) {
      _openSignal(context, widget.group.memberSignals.single);
    } else {
      setState(() => _expanded = !_expanded);
    }
  }

  Widget _interpretationDetails(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        title: const Text(
          'Review context',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        children: [
          _InterpretationLine(
            label: 'Why this matters',
            value: widget.group.familyScientificRole,
          ),
          _InterpretationLine(
            label: 'Effect on results',
            value: widget.group.familyInterpretationImpact,
          ),
          _InterpretationLine(
            label: 'Question to resolve',
            value: widget.group.reviewQuestion,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final (chipBg, chipFg) = _severityColors(group);
    final affectedSummary = _affectedSummary;
    final isMulti = group.memberSignals.length > 1;
    final title = _displayTitle(group);

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppDesignTokens.spacing8),
        decoration: BoxDecoration(
          color: AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.primaryText,
                          height: 1.35,
                        ),
                      ),
                      if (group.signalCount > 1)
                        OverviewStatusChip(
                          label: '${group.signalCount} signals',
                          bg: AppDesignTokens.emptyBadgeBg,
                          fg: AppDesignTokens.emptyBadgeFg,
                        ),
                    ],
                  ),
                  if (group.groupingBasis.isNotEmpty &&
                      group.groupingBasis.contains('assessment')) ...[
                    const SizedBox(height: 2),
                    Text(
                      group.groupingBasis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesignTokens.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  OverviewStatusChip(
                    label: group.severityLabel,
                    bg: chipBg,
                    fg: chipFg,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.shortSummary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppDesignTokens.primaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.statusLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppDesignTokens.secondaryText,
                      height: 1.35,
                    ),
                  ),
                  if (affectedSummary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      affectedSummary,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppDesignTokens.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                  _interpretationDetails(context),
                  if (isMulti && _expanded) ...[
                    const SizedBox(height: AppDesignTokens.spacing4),
                    ...group.memberSignals.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: _rawSignalFor(member) != null
                              ? () => _openSignal(context, member)
                              : null,
                          child: Text(
                            member.displayTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppDesignTokens.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isMulti) ...[
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: AppDesignTokens.secondaryText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _displayTitle(SignalReviewGroupProjection group) {
    if (group.groupType != 'aov_prediction' ||
        group.affectedAssessmentIds.isEmpty) {
      return group.displayTitle;
    }
    final ids = group.affectedAssessmentIds.join(', ');
    return '${group.displayTitle} — assessment $ids';
  }
}

class _InterpretationLine extends StatelessWidget {
  const _InterpretationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: AppDesignTokens.primaryText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.eventType,
    required this.note,
    required this.actorName,
    required this.occurredAt,
  });

  final String eventType;
  final String? note;
  final String? actorName;
  final int occurredAt;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(
      DateTime.fromMillisecondsSinceEpoch(occurredAt, isUtc: true).toLocal(),
    );
    final byStr = actorName != null ? ' · $actorName' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${eventType.replaceAll('_', ' ')} — $dateStr$byStr',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        if (note != null && note!.isNotEmpty)
          Text(
            note!.length > 120 ? '${note!.substring(0, 120)}…' : note!,
            style: const TextStyle(
              fontSize: 14,
              color: AppDesignTokens.primaryText,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
