import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

/// Shows a dialog to view and edit notes for a plot. Saves via [PlotRepository].
Future<void> showPlotNotesDialog(
  BuildContext context,
  WidgetRef ref,
  Plot plot,
  Trial trial,
) async {
  final controller = TextEditingController(text: plot.notes ?? '');
  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notes — Plot ${plot.plotId}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Add notes for this plot...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      final notes =
          controller.text.trim().isEmpty ? null : controller.text.trim();
      await ref.read(plotRepositoryProvider).updatePlotNotes(plot.id, notes);
      ref.invalidate(plotsForTrialProvider(trial.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')),
        );
      }
    }
  } finally {
    controller.dispose();
  }
}
