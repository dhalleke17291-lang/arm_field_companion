import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/quick_note_templates.dart';

/// Shows a dialog to view and edit notes for a plot. Saves via [PlotRepository].
Future<void> showPlotNotesDialog(
  BuildContext context,
  WidgetRef ref,
  Plot plot,
  Trial trial, {
  List<Plot>? sameTrialPlots,
}) async {
  final controller = TextEditingController(text: plot.plotNotes ?? '');
  final displayLabel =
      getDisplayPlotLabel(plot, sameTrialPlots ?? [plot]);
  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plot Notes — Plot $displayLabel'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kQuickNoteTemplates.map((label) {
                  return ActionChip(
                    label: Text(label),
                    onPressed: () {
                      final before = controller.text.trim();
                      controller.text =
                          before.isEmpty ? label : '$before, $label';
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Add notes for this plot...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
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
