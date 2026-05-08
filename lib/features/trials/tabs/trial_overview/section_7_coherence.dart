import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/interpretation_factors_codec.dart';
import '../../../../domain/trial_cognition/trial_coherence_dto.dart';
import '_overview_card.dart';

class Section7Coherence extends ConsumerWidget {
  const Section7Coherence({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coherenceAsync = ref.watch(trialCoherenceProvider(trial.id));
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));

    return OverviewSectionCard(
      number: 7,
      title: 'Deviations Affecting Interpretation',
      subtitle: 'Execution alignment with stated trial intent',
      child: coherenceAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _CoherenceBody(
          dto: dto,
          knownFactorsJson:
              purposeAsync.valueOrNull?.knownInterpretationFactors,
        ),
      ),
    );
  }
}

class _CoherenceBody extends StatefulWidget {
  const _CoherenceBody({required this.dto, this.knownFactorsJson});

  final TrialCoherenceDto dto;
  final String? knownFactorsJson;

  @override
  State<_CoherenceBody> createState() => _CoherenceBodyState();
}

class _CoherenceBodyState extends State<_CoherenceBody> {
  bool _showAligned = false;

  @override
  Widget build(BuildContext context) {
    final dto = widget.dto;

    if (dto.checks.isEmpty) {
      return const Text(
        'No coherence concerns identified.',
        style: TextStyle(fontSize: 14, color: AppDesignTokens.secondaryText),
      );
    }

    final concerns = dto.checks
        .where(
          (c) => c.status == 'review_needed' || c.status == 'cannot_evaluate',
        )
        .toList();
    final aligned = dto.checks.where((c) => c.status == 'aligned').toList();

    final total = dto.checks.length;
    final reviewCount =
        dto.checks.where((c) => c.status == 'review_needed').length;
    final cannotCount =
        dto.checks.where((c) => c.status == 'cannot_evaluate').length;

    final parsed = InterpretationFactorsCodec.parse(widget.knownFactorsJson);

    final String summaryLine;
    if (concerns.isEmpty) {
      summaryLine = '$total of $total checks aligned.';
    } else {
      final parts = <String>[];
      if (reviewCount > 0) {
        parts.add('$reviewCount ${reviewCount == 1 ? 'needs' : 'need'} review');
      }
      if (cannotCount > 0) {
        parts.add('$cannotCount cannot evaluate');
      }
      summaryLine =
          '${aligned.length} of $total checks aligned. ${parts.join(', ')}.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: aligned.isNotEmpty && !_showAligned
              ? () => setState(() => _showAligned = true)
              : null,
          child: Text(
            summaryLine,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (concerns.isEmpty)
          const Text(
            'No coherence concerns identified.',
            style: TextStyle(
              fontSize: 14,
              color: AppDesignTokens.secondaryText,
            ),
          )
        else
          ...concerns.map((c) => _CoherenceCheckRow(check: c)),
        if (aligned.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing8),
          GestureDetector(
            onTap: () => setState(() => _showAligned = !_showAligned),
            child: Row(
              children: [
                Text(
                  _showAligned
                      ? 'Hide aligned checks'
                      : 'Show aligned checks (${aligned.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showAligned
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: AppDesignTokens.primary,
                ),
              ],
            ),
          ),
          if (_showAligned) ...[
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
                          fontSize: 14,
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
        if (parsed != null && !parsed.noneSelected) ...[
          const SizedBox(height: AppDesignTokens.spacing12),
          _KnownFactorsRow(parsed: parsed),
        ],
      ],
    );
  }
}

class _KnownFactorsRow extends StatelessWidget {
  const _KnownFactorsRow({required this.parsed});

  final InterpretationFactorsResult parsed;

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (final k in parsed.selectedKeys) kInterpretationFactorLabels[k] ?? k,
      if (parsed.otherText != null) parsed.otherText!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SITE / SEASON CONDITIONS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: labels
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.emptyBadgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppDesignTokens.emptyBadgeFg,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CoherenceCheckRow extends StatefulWidget {
  const _CoherenceCheckRow({required this.check});

  final TrialCoherenceCheckDto check;

  @override
  State<_CoherenceCheckRow> createState() => _CoherenceCheckRowState();
}

class _CoherenceCheckRowState extends State<_CoherenceCheckRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    final isCannotEval = check.status == 'cannot_evaluate';
    final hasReason = check.reason.isNotEmpty;

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
          InkWell(
            onTap: hasReason ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    check.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
                if (hasReason) ...[
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
          ),
          if (_expanded && hasReason) ...[
            const SizedBox(height: 2),
            Text(
              check.reason,
              style: const TextStyle(
                fontSize: 15,
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
