import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/signals/signal_providers.dart';
import '_overview_card.dart';

class Section9Decisions extends ConsumerWidget {
  const Section9Decisions({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(trialDecisionSummaryProvider(trial.id));
    final signalsAsync = ref.watch(openSignalsForTrialProvider(trial.id));

    return OverviewSectionCard(
      number: 9,
      title: 'Open Decisions and Unresolved Signals',
      child: decisionsAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (decisions) => signalsAsync.when(
          loading: () => const OverviewSectionLoading(),
          error: (_, __) => const OverviewSectionError(),
          data: (signals) {
            final hasContent = signals.isNotEmpty ||
                decisions.signalDecisions.isNotEmpty ||
                decisions.ctqAcknowledgments.isNotEmpty;

            if (!hasContent) {
              return const Text(
                'No open decisions or unresolved signals.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (signals.isNotEmpty) ...[
                  const Text(
                    'OPEN SIGNALS',
                    style: TextStyle(
                      fontSize: 10,
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
                      child: _SignalRow(signal: s),
                    ),
                  ),
                ],
                if (decisions.signalDecisions.isNotEmpty) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  const Text(
                    'RESEARCHER DECISIONS',
                    style: TextStyle(
                      fontSize: 10,
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
                      fontSize: 10,
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
                          fontSize: 12,
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

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final Signal signal;

  static String _severityLabel(String s) => switch (s) {
        'critical' => 'Critical',
        'review' => 'Review',
        'info' => 'Info',
        _ => s,
      };

  static (Color, Color) _severityColors(String s) => switch (s) {
        'critical' => (AppDesignTokens.warningBg, AppDesignTokens.warningFg),
        'review' => (AppDesignTokens.partialBg, AppDesignTokens.partialFg),
        _ => (AppDesignTokens.emptyBadgeBg, AppDesignTokens.emptyBadgeFg),
      };

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg) = _severityColors(signal.severity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            signal.consequenceText,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.primaryText,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OverviewStatusChip(
          label: _severityLabel(signal.severity),
          bg: chipBg,
          fg: chipFg,
        ),
      ],
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        if (note != null && note!.isNotEmpty)
          Text(
            note!.length > 120 ? '${note!.substring(0, 120)}…' : note!,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignTokens.primaryText,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
