import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import 'field_note_editor_sheet.dart';
import 'field_notes_list_screen.dart';

/// Trial hub: recent field notes + entry points.
class FieldNotesTrialSection extends ConsumerWidget {
  const FieldNotesTrialSection({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesForTrialProvider(trial.id));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: AppDesignTokens.spacing8,
      ),
      child: Card(
        elevation: 0,
        color: AppDesignTokens.sectionHeaderBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppDesignTokens.borderCrisp),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing12),
          child: async.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Notes unavailable: $e',
              style: const TextStyle(color: AppDesignTokens.secondaryText),
            ),
            data: (notes) {
              final preview = notes.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Field Notes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppDesignTokens.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => showFieldNoteEditorSheet(
                          context,
                          ref,
                          trial: trial,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (preview.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'No observations yet. Add a site note (optionally link a plot or session).',
                        style: TextStyle(
                          color: AppDesignTokens.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    for (final n in preview)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => showFieldNoteEditorSheet(
                            context,
                            ref,
                            trial: trial,
                            existing: n,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                size: 18,
                                color: AppDesignTokens.secondaryText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  n.content.length > 120
                                      ? '${n.content.substring(0, 120)}…'
                                      : n.content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppDesignTokens.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FieldNotesListScreen(trial: trial),
                          ),
                        );
                      },
                      child: const Text('View all'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
