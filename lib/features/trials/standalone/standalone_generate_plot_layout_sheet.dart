import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import 'generate_standalone_plot_layout_usecase.dart';
import 'plot_generation_engine.dart';

/// Dialog: reps, plots per rep, optional guards, design (when missing), then
/// [GenerateStandalonePlotLayoutUseCase].
Future<void> showStandaloneGeneratePlotLayoutDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Trial trial,
}) async {
  final treatments = await ref
      .read(treatmentRepositoryProvider)
      .getTreatmentsForTrial(trial.id);
  if (treatments.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two treatments first')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  treatments.sort((a, b) => a.id.compareTo(b.id));
  final tCount = treatments.length;

  var reps = 4;
  var plotsPerRep = tCount;
  var design = trial.experimentalDesign?.trim().isNotEmpty == true
      ? trial.experimentalDesign!.trim()
      : PlotGenerationEngine.designRcbd;
  var guardEnabled = false;
  var guardsPerEnd = 1;

  final showDesignPicker =
      trial.experimentalDesign == null || trial.experimentalDesign!.trim().isEmpty;

  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        return AlertDialog(
          title: const Text('Generate Plot Layout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Reps',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Decrease reps',
                      onPressed: reps > 1 ? () => setLocal(() => reps--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$reps',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase reps',
                      onPressed: reps < 8 ? () => setLocal(() => reps++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plots per rep (min $tCount)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Decrease plots per rep',
                      onPressed: plotsPerRep > tCount
                          ? () => setLocal(() => plotsPerRep--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$plotsPerRep',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase plots per rep',
                      onPressed: plotsPerRep < 50
                          ? () => setLocal(() => plotsPerRep++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Add guard rows',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.primaryText,
                    ),
                  ),
                  value: guardEnabled,
                  onChanged: (v) => setLocal(() => guardEnabled = v),
                ),
                if (guardEnabled)
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Guards per rep end',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Decrease guards',
                        onPressed: guardsPerEnd > 1
                            ? () => setLocal(() => guardsPerEnd--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$guardsPerEnd',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppDesignTokens.primaryText,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase guards',
                        onPressed: guardsPerEnd < 3
                            ? () => setLocal(() => guardsPerEnd++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                if (showDesignPicker) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Study design',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          color: AppDesignTokens.primaryText,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PlotGenerationEngine.designRcbd,
                      PlotGenerationEngine.designCrd,
                      PlotGenerationEngine.designNonRandomized,
                    ]
                        .map(
                          (d) => ChoiceChip(
                            label: Text(d),
                            selected: design == d,
                            onSelected: (_) => setLocal(() => design = d),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate'),
            ),
          ],
        );
      },
    ),
  );

  if (ok != true || !context.mounted) return;

  final useCase = ref.read(generateStandalonePlotLayoutUseCaseProvider);
  final result = await useCase.execute(
    GenerateStandalonePlotLayoutInput(
      trialId: trial.id,
      repCount: reps,
      plotsPerRep: plotsPerRep,
      guardRowsPerRep: guardEnabled ? guardsPerEnd : 0,
      experimentalDesign: design,
    ),
  );

  if (!context.mounted) return;
  ref.invalidate(plotsForTrialProvider(trial.id));
  ref.invalidate(assignmentsForTrialProvider(trial.id));
  ref.invalidate(trialReadinessProvider(trial.id));
  if (result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plot layout generated')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.errorMessage ?? 'Generation failed'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
