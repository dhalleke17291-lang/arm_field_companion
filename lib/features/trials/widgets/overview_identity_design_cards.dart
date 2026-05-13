part of '../trial_detail_screen.dart';

class TrialIdentitySummaryCard extends ConsumerWidget {
  const TrialIdentitySummaryCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTrial = ref.watch(trialProvider(trial.id)).valueOrNull ?? trial;
    final purposeAsync = ref.watch(trialPurposeProvider(trial.id));

    return OverviewDashboardCard(
      title: 'Trial Identity',
      child: purposeAsync.when(
        loading: () => const Text(
          'Loading identity...',
          style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
        ),
        error: (_, __) => const Text(
          'Identity unavailable.',
          style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
        ),
        data: (purpose) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _OverviewInfoRow('Trial', liveTrial.name),
            if (_hasText(liveTrial.crop))
              _OverviewInfoRow('Crop', liveTrial.crop!),
            if (_hasText(liveTrial.sponsor))
              _OverviewInfoRow('Sponsor', liveTrial.sponsor!),
            if (_hasText(liveTrial.studyType))
              _OverviewInfoRow('Trial type', liveTrial.studyType!),
            if (_hasText(liveTrial.workspaceType))
              _OverviewInfoRow('Workspace', liveTrial.workspaceType),
            const SizedBox(height: AppDesignTokens.spacing8),
            _IntentPreview(
              trial: liveTrial,
              purpose: purpose,
              onOpenIntent: () =>
                  showTrialIntentSheet(context, ref, trial: trial),
            ),
          ],
        ),
      ),
    );
  }
}

class TrialDesignSummaryCard extends ConsumerWidget {
  const TrialDesignSummaryCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final armAsync = ref.watch(armTrialMetadataStreamProvider(trial.id));

    return OverviewDashboardCard(
      title: 'Design Summary',
      child: treatmentsAsync.when(
        loading: () => const Text(
          'Loading design...',
          style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
        ),
        error: (_, __) => const Text(
          'Design unavailable.',
          style: TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
        ),
        data: (treatments) => plotsAsync.when(
          loading: () => const Text(
            'Loading design...',
            style:
                TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
          ),
          error: (_, __) => const Text(
            'Design unavailable.',
            style:
                TextStyle(fontSize: 12, color: AppDesignTokens.secondaryText),
          ),
          data: (plots) {
            final activeTreatments =
                treatments.where((t) => !t.isDeleted).toList();
            final activePlots =
                plots.where((p) => !p.isDeleted && !p.isGuardRow).toList();
            final reps = activePlots.map((p) => p.rep).whereType<int>().toSet();
            final isArmLinked = armAsync.valueOrNull?.isArmLinked ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _OverviewInfoRow('Treatments', '${activeTreatments.length}'),
                _OverviewInfoRow(
                  'Replications',
                  reps.isEmpty ? '-' : '${reps.length}',
                ),
                _OverviewInfoRow('Total plots', '${activePlots.length}'),
                if (_hasText(trial.experimentalDesign))
                  _OverviewInfoRow('Design type', trial.experimentalDesign!),
                if (isArmLinked) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  const _OverviewMiniChip(
                    label: 'ARM-linked',
                    bg: AppDesignTokens.softBlueAccent,
                    fg: AppDesignTokens.primary,
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

class _IntentPreview extends StatelessWidget {
  const _IntentPreview({
    required this.trial,
    required this.purpose,
    required this.onOpenIntent,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final VoidCallback onOpenIntent;

  @override
  Widget build(BuildContext context) {
    if (purpose.requiresConfirmation) {
      return _InferredIntentPreview(
        trial: trial,
        purpose: purpose,
        onOpenIntent: onOpenIntent,
      );
    }
    return _ConfirmedIntentPreview(
      trial: trial,
      purpose: purpose,
      onOpenIntent: onOpenIntent,
    );
  }
}

class _ConfirmedIntentPreview extends StatelessWidget {
  const _ConfirmedIntentPreview({
    required this.trial,
    required this.purpose,
    required this.onOpenIntent,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final VoidCallback onOpenIntent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _OverviewMiniChip(
          label: 'Intent confirmed',
          bg: AppDesignTokens.successBg,
          fg: AppDesignTokens.successFg,
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (_hasText(purpose.primaryEndpoint))
          _OverviewInfoRow('Primary endpoint', purpose.primaryEndpoint!),
        if (_hasText(trial.studyType))
          _OverviewInfoRow('Trial type', trial.studyType!),
        if (_hasText(purpose.regulatoryContext))
          _OverviewInfoRow(
            'Regulatory context',
            _regulatoryLabel(purpose.regulatoryContext!),
          ),
        if (_hasText(purpose.trialPurpose))
          _OverviewInfoRow('Purpose', purpose.trialPurpose!),
        _OverviewActionLink(label: 'Edit intent', onPressed: onOpenIntent),
      ],
    );
  }
}

class _InferredIntentPreview extends StatelessWidget {
  const _InferredIntentPreview({
    required this.trial,
    required this.purpose,
    required this.onOpenIntent,
  });

  final Trial trial;
  final TrialPurposeDto purpose;
  final VoidCallback onOpenIntent;

  @override
  Widget build(BuildContext context) {
    final inferred = purpose.inferredPurpose;
    final source = _sourceModeLabel(purpose.inferenceSource) ?? 'setup';
    final trialType = inferred?.trialType ?? trial.studyType;
    final primaryEndpoint =
        purpose.primaryEndpoint ?? inferred?.primaryEndpointAssessmentKey;
    final regulatoryContext =
        inferred?.regulatoryContext ?? purpose.regulatoryContext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _OverviewMiniChip(
          label: 'Intent inferred',
          bg: AppDesignTokens.partialBg,
          fg: AppDesignTokens.partialFg,
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        Text(
          'Intent inferred from $source. Confirm before export.',
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppDesignTokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppDesignTokens.spacing8),
        if (_hasText(primaryEndpoint))
          _OverviewInfoRow('Primary endpoint', primaryEndpoint!),
        if (_hasText(trialType)) _OverviewInfoRow('Trial type', trialType!),
        if (_hasText(regulatoryContext))
          _OverviewInfoRow(
            'Regulatory context',
            _regulatoryLabel(regulatoryContext!),
          ),
        if (inferred != null && inferred.treatmentRoles.isNotEmpty)
          _OverviewInfoRow(
            'Treatment roles',
            inferred.treatmentRoles
                .map((role) =>
                    '${role.treatmentName}=${role.inferredRole.replaceAll('_', ' ')}')
                .join(', '),
          ),
        _OverviewActionLink(label: 'Confirm intent', onPressed: onOpenIntent),
      ],
    );
  }
}

class _OverviewInfoRow extends StatelessWidget {
  const _OverviewInfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth =
            (constraints.maxWidth * 0.34).clamp(108.0, 150.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewMiniChip extends StatelessWidget {
  const _OverviewMiniChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _OverviewActionLink extends StatelessWidget {
  const _OverviewActionLink({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _sourceModeLabel(String? source) => switch (source) {
      'arm_structure' => 'ARM structure',
      'manual_revelation' => 'manual entry',
      'standalone_structure' => 'standalone setup',
      'protocol_document' => 'protocol document',
      'mixed' => 'mixed setup',
      _ => null,
    };

String _regulatoryLabel(String key) =>
    RegulatoryContextValue.labelFor(key) ?? _fallbackRegulatoryLabel(key);

String _fallbackRegulatoryLabel(String key) => switch (key) {
      'registration' => 'Regulatory registration',
      'internalResearch' => 'Internal research',
      'academic' => 'Academic / extension',
      'undetermined' => 'Not determined',
      _ => key,
    };
