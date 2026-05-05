import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '../../../../domain/trial_cognition/trial_intent_inferrer.dart';
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
          onConfirmIntent: () async {
            final purposeRepo = ref.read(trialPurposeRepositoryProvider);
            final existing =
                await purposeRepo.getCurrentTrialPurpose(trial.id);
            if (existing != null) {
              await purposeRepo.confirmTrialPurpose(existing.id);
              ref.invalidate(trialPurposeProvider(trial.id));
              ref.invalidate(trialCriticalToQualityProvider(trial.id));
            }
          },
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
    required this.onConfirmIntent,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final VoidCallback onIntent;
  final VoidCallback onConfirmIntent;

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
        if (purpose.requiresConfirmation)
          _InferenceBanner(
            purpose: purpose,
            onConfirm: onConfirmIntent,
            onEdit: onIntent,
          )
        else
          _PurposeSection(purpose: purpose, onIntent: onIntent),
      ],
    );
  }
}

// ── Inferred-pending-confirmation banner ─────────────────────────────────────

class _InferenceBanner extends StatelessWidget {
  const _InferenceBanner({
    required this.purpose,
    required this.onConfirm,
    required this.onEdit,
  });

  final TrialPurposeDto purpose;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inferred = purpose.inferredPurpose;
    final sourceLabel = (purpose.inferenceSource ?? '')
        .replaceAll('_', ' ')
        .replaceAll('structure', '')
        .trim();

    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppDesignTokens.warningFg.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(AppDesignTokens.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppDesignTokens.warningFg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Intent inferred from $sourceLabel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppDesignTokens.warningFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.spacing8),
          if (inferred != null) ...[
            if (purpose.primaryEndpoint != null)
              _InferredField(
                label: 'Primary endpoint',
                value: purpose.primaryEndpoint!,
                confidence: inferred.primaryEndpointConfidence,
              ),
            if (inferred.trialType != null)
              _InferredField(
                label: 'Trial type',
                value: inferred.trialType!,
                confidence: inferred.trialTypeConfidence,
              ),
            if (inferred.treatmentRoles.isNotEmpty)
              _InferredField(
                label: 'Treatment roles',
                value: inferred.treatmentRoles
                    .map((r) =>
                        '${r.treatmentName}=${r.inferredRole.replaceAll('_', ' ')}')
                    .join(', '),
                confidence: inferred.treatmentRoles
                    .map((r) => r.confidence)
                    .fold(
                      FieldConfidence.high,
                      (a, b) => a.index > b.index ? a : b,
                    ),
              ),
            if (purpose.claimBeingTested != null)
              _InferredField(
                label: 'Claim',
                value: purpose.claimBeingTested!,
                confidence: inferred.claimConfidence,
              ),
          ] else if (purpose.claimBeingTested != null ||
              purpose.primaryEndpoint != null) ...[
            if (purpose.primaryEndpoint != null)
              OverviewDataRow('Primary endpoint', purpose.primaryEndpoint!),
            if (purpose.claimBeingTested != null)
              OverviewDataRow('Claim', purpose.claimBeingTested!),
          ],
          const SizedBox(height: AppDesignTokens.spacing12),
          Row(
            children: [
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.warningFg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Confirm intent'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.warningFg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InferredField extends StatelessWidget {
  const _InferredField({
    required this.label,
    required this.value,
    required this.confidence,
  });

  final String label;
  final String value;
  final FieldConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confLabel = switch (confidence) {
      FieldConfidence.high => 'high confidence',
      FieldConfidence.moderate => 'moderate confidence',
      FieldConfidence.low => 'low confidence',
      FieldConfidence.cannotInfer => 'cannot infer',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppDesignTokens.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppDesignTokens.primaryText),
            ),
            TextSpan(
              text: '  ($confLabel)',
              style: TextStyle(
                color: AppDesignTokens.secondaryText.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirmed / manual purpose section ───────────────────────────────────────

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
