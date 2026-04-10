import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import 'generate_standalone_plot_layout_usecase.dart';
import 'plot_generation_engine.dart';

/// Dialog: reps + design (when missing), then [GenerateStandalonePlotLayoutUseCase].
Future<void> showStandaloneGeneratePlotLayoutDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Trial trial,
}) async {
  var reps = 4;
  var design = trial.experimentalDesign?.trim().isNotEmpty == true
      ? trial.experimentalDesign!.trim()
      : PlotGenerationEngine.designRcbd;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final showDesignPicker =
            trial.experimentalDesign == null || trial.experimentalDesign!.trim().isEmpty;
        return AlertDialog(
          title: const Text('Generate Plot Layout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('Reps'),
                    const Spacer(),
                    IconButton(
                      onPressed: reps > 1 ? () => setLocal(() => reps--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$reps'),
                    IconButton(
                      onPressed: reps < 8 ? () => setLocal(() => reps++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (showDesignPicker) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Study design',
                    style: Theme.of(ctx).textTheme.labelLarge,
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
