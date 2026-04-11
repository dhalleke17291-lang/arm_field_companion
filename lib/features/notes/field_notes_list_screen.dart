import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import 'field_note_editor_sheet.dart';

/// Full list of field notes for a trial.
class FieldNotesListScreen extends ConsumerWidget {
  const FieldNotesListScreen({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        title: const Text('Field Notes'),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            child: Text(
              'Could not load notes: $e',
              style: const TextStyle(color: AppDesignTokens.secondaryText),
            ),
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                'No field notes yet.',
                style: TextStyle(color: AppDesignTokens.secondaryText),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDesignTokens.spacing16),
            itemCount: notes.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppDesignTokens.borderCrisp),
            itemBuilder: (ctx, i) {
              final n = notes[i];
              return ListTile(
                title: Text(
                  n.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _subtitle(n),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await showFieldNoteEditorSheet(
                        context,
                        ref,
                        trial: trial,
                        existing: n,
                      );
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete note'),
                          content: const Text(
                            'This note will be removed from export and the timeline.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        final user =
                            await ref.read(currentUserProvider.future);
                        final byline = user?.displayName ?? 'Unknown';
                        await ref
                            .read(notesRepositoryProvider)
                            .deleteNote(n.id, byline);
                        ref.invalidate(notesForTrialProvider(trial.id));
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showFieldNoteEditorSheet(context, ref, trial: trial);
        },
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add Note'),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
      ),
    );
  }

  static String _subtitle(Note n) {
    final parts = <String>[n.createdAt.toLocal().toString().split('.').first];
    if (n.plotPk != null) parts.add('Plot #${n.plotPk}');
    if (n.sessionId != null) parts.add('Session #${n.sessionId}');
    if (n.raterName != null && n.raterName!.trim().isNotEmpty) {
      parts.add(n.raterName!.trim());
    }
    return parts.join(' · ');
  }
}
