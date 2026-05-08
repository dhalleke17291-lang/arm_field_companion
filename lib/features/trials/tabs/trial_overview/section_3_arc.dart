import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_evidence_arc_dto.dart';
import '_overview_card.dart';

class Section3Arc extends ConsumerWidget {
  const Section3Arc({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arcAsync = ref.watch(trialEvidenceArcProvider(trial.id));

    return OverviewSectionCard(
      number: 3,
      title: 'Execution Arc',
      child: arcAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _ArcBody(dto: dto),
      ),
    );
  }
}

class _ArcBody extends StatelessWidget {
  const _ArcBody({required this.dto});

  final TrialEvidenceArcDto dto;

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipFg, chipLabel) = switch (dto.evidenceState) {
      'export_ready_candidate' || 'sufficient_for_review' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Sufficient',
        ),
      'partial' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Partial',
        ),
      'started' => (
          AppDesignTokens.plannedBg,
          AppDesignTokens.plannedFg,
          'Started',
        ),
      _ => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          'No evidence',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (dto.plannedEvidenceSummary.isNotEmpty)
          OverviewDataRow('Planned', dto.plannedEvidenceSummary),
        if (dto.actualEvidenceSummary.isNotEmpty)
          OverviewDataRow('Actual', dto.actualEvidenceSummary),
        if (dto.missingEvidenceItems.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          const Text(
            'Not yet recorded:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          ...dto.missingEvidenceItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.primaryText,
                ),
              ),
            ),
          ),
        ],
        if (dto.riskFlags.isNotEmpty) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          ...dto.riskFlags.map(
            (flag) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '⚠ $flag',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppDesignTokens.warningFg,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
