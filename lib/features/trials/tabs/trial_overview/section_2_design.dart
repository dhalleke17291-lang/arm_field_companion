import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/design/app_design_tokens.dart';
import '../../../../core/providers.dart';
import '_overview_card.dart';

class Section2Design extends ConsumerWidget {
  const Section2Design({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsAsync = ref.watch(treatmentsForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final armAsync = ref.watch(armTrialMetadataStreamProvider(trial.id));

    return OverviewSectionCard(
      number: 2,
      title: 'Design Summary',
      child: treatmentsAsync.when(
        loading: () => const OverviewSectionLoading(),
        error: (_, __) => const OverviewSectionError(),
        data: (treatments) => plotsAsync.when(
          loading: () => const OverviewSectionLoading(),
          error: (_, __) => const OverviewSectionError(),
          data: (plots) {
            final activePlots =
                plots.where((p) => !p.isDeleted && !p.isGuardRow).toList();
            final reps = activePlots
                .map((p) => p.rep)
                .whereType<int>()
                .toSet();
            final isArmLinked =
                armAsync.valueOrNull?.isArmLinked ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverviewDataRow(
                  'Treatments',
                  '${treatments.where((t) => !t.isDeleted).length}',
                ),
                OverviewDataRow(
                  'Replications',
                  reps.isEmpty ? '—' : '${reps.length}',
                ),
                OverviewDataRow(
                  'Total plots',
                  '${activePlots.length}',
                ),
                if (trial.experimentalDesign != null)
                  OverviewDataRow(
                    'Design type',
                    trial.experimentalDesign!,
                  ),
                if (isArmLinked) ...[
                  const SizedBox(height: AppDesignTokens.spacing4),
                  const OverviewStatusChip(
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
