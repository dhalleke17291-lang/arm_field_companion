import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_coherence_dto.dart';
import '_overview_card.dart';

class Section7Coherence extends ConsumerWidget {
  const Section7Coherence({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coherenceAsync = ref.watch(trialCoherenceProvider(trial.id));

    return OverviewSectionCard(
      number: 7,
      title: 'Deviations Affecting Interpretation',
      child: coherenceAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _CoherenceBody(dto: dto),
      ),
    );
  }
}

class _CoherenceBody extends StatelessWidget {
  const _CoherenceBody({required this.dto});

  final TrialCoherenceDto dto;

  @override
  Widget build(BuildContext context) {
    if (dto.checks.isEmpty) {
      return const Text(
        'No coherence concerns identified.',
        style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
      );
    }

    final concerns = dto.checks
        .where((c) => c.status == 'review_needed' || c.status == 'cannot_evaluate')
        .toList();
    final aligned = dto.checks.where((c) => c.status == 'aligned').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (concerns.isEmpty)
          const Text(
            'No coherence concerns identified.',
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
            ),
          )
        else ...[
          ...concerns.map((c) => _CoherenceCheckRow(check: c)),
        ],
        if (aligned.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          ...aligned.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 13,
                    color: AppDesignTokens.successFg,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText,
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

class _CoherenceCheckRow extends StatelessWidget {
  const _CoherenceCheckRow({required this.check});

  final TrialCoherenceCheckDto check;

  @override
  Widget build(BuildContext context) {
    final isCannotEval = check.status == 'cannot_evaluate';

    final (chipBg, chipFg, chipLabel) = isCannotEval
        ? (
            AppDesignTokens.emptyBadgeBg,
            AppDesignTokens.emptyBadgeFg,
            'Cannot evaluate',
          )
        : (
            AppDesignTokens.partialBg,
            AppDesignTokens.partialFg,
            'Review needed',
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  check.label,
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
          if (check.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              check.reason,
              style: const TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
