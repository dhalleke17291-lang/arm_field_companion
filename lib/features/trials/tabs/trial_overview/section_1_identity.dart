import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_purpose_dto.dart';
import '../trial_intent_sheet.dart';
import '_overview_card.dart';

class Section1Identity extends ConsumerWidget {
  const Section1Identity({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));

    return OverviewSectionCard(
      number: 1,
      title: 'Trial Identity and Purpose',
      child: purposeAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (dto) => _IdentityBody(
          trial: trial,
          purpose: dto,
          onIntent: () => showTrialIntentSheet(context, ref, trial: trial),
        ),
      ),
    );
  }
}

class _IdentityBody extends StatelessWidget {
  const _IdentityBody({
    required this.trial,
    required this.purpose,
    required this.onIntent,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final VoidCallback onIntent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewDataRow('Trial', trial.name),
        if (trial.crop != null) OverviewDataRow('Crop', trial.crop!),
        if (trial.sponsor != null) OverviewDataRow('Sponsor', trial.sponsor!),
        if (trial.studyType != null)
          OverviewDataRow('Trial type', trial.studyType!),
        if (trial.workspaceType.isNotEmpty)
          OverviewDataRow('Workspace', trial.workspaceType),
        const SizedBox(height: AppDesignTokens.spacing8),
        _PurposeSection(purpose: purpose, onIntent: onIntent),
      ],
    );
  }
}

class _PurposeSection extends StatelessWidget {
  const _PurposeSection({
    required this.purpose,
    required this.onIntent,
  });

  final TrialPurposeDto purpose;
  final VoidCallback onIntent;

  @override
  Widget build(BuildContext context) {
    if (purpose.isUnknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Intent not yet captured.',
            style: TextStyle(
              fontSize: 13,
              color: AppDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.spacing4),
          GestureDetector(
            onTap: onIntent,
            child: const Text(
              'Capture intent →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primary,
              ),
            ),
          ),
        ],
      );
    }

    final (chipBg, chipFg, chipLabel) = switch (purpose.purposeStatus) {
      'confirmed' => (
          AppDesignTokens.successBg,
          AppDesignTokens.successFg,
          'Confirmed',
        ),
      'partial' => (
          AppDesignTokens.partialBg,
          AppDesignTokens.partialFg,
          'Partial',
        ),
      _ => (
          AppDesignTokens.emptyBadgeBg,
          AppDesignTokens.emptyBadgeFg,
          'Draft',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverviewStatusChip(label: chipLabel, bg: chipBg, fg: chipFg),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (purpose.claimBeingTested != null)
          OverviewDataRow('Claim being tested', purpose.claimBeingTested!),
        if (purpose.primaryEndpoint != null)
          OverviewDataRow('Primary endpoint', purpose.primaryEndpoint!),
        if (purpose.regulatoryContext != null)
          OverviewDataRow('Regulatory context', purpose.regulatoryContext!),
        if (purpose.provenanceSummary.isNotEmpty)
          OverviewDataRow('Provenance', purpose.provenanceSummary),
        if (!purpose.isConfirmed) ...[
          const SizedBox(height: AppDesignTokens.spacing4),
          GestureDetector(
            onTap: onIntent,
            child: const Text(
              'Update intent →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
