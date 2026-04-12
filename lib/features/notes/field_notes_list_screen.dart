import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/ui/field_note_timestamp_format.dart';
import 'field_note_editor_sheet.dart';

/// Full list of field notes for a trial.
class FieldNotesListScreen extends ConsumerWidget {
  const FieldNotesListScreen({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesForTrialProvider(trial.id));
    final plotsAsync = ref.watch(plotsForTrialProvider(trial.id));
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
        iconTheme: const IconThemeData(
          color: AppDesignTokens.onPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppDesignTokens.onPrimary,
          size: 24,
        ),
        title: Text(
          'Field Notes',
          style: AppDesignTokens.headerTitleStyle(
            fontSize: 18,
            color: AppDesignTokens.onPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: notesAsync.when(
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
          final plotIdByPk = {
            for (final p in plotsAsync.valueOrNull ?? <Plot>[])
              p.id: p.plotId,
          };
          final sessionIdToName = {
            for (final s in sessionsAsync.valueOrNull ?? <Session>[])
              s.id: s.name,
          };
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
              return Dismissible(
                key: ValueKey<int>(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppDesignTokens.spacing16),
                  color: Theme.of(ctx).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.onErrorContainer,
                  ),
                ),
                confirmDismiss: (_) async =>
                    await _showDeleteNoteDialog(ctx) ?? false,
                onDismissed: (_) {
                  unawaited(() async {
                    final byline = await _currentByline(ref);
                    if (!ctx.mounted) return;
                    await _deleteNoteAndShowUndo(ctx, ref, n, byline);
                  }());
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacing8,
                    vertical: 4,
                  ),
                  title: Text(
                    n.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _noteListSubtitle(n, plotIdByPk, sessionIdToName),
                  onTap: () => showFieldNoteEditorSheet(
                    ctx,
                    ref,
                    trial: trial,
                    existing: n,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        color: AppDesignTokens.primary,
                        onPressed: () => showFieldNoteEditorSheet(
                          ctx,
                          ref,
                          trial: trial,
                          existing: n,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        color: AppDesignTokens.secondaryText,
                        onPressed: () =>
                            _deleteNoteAfterConfirm(ctx, ref, n),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFieldNoteEditorSheet(context, ref, trial: trial),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: AppDesignTokens.primary,
        foregroundColor: AppDesignTokens.onPrimary,
      ),
    );
  }

  static Widget _noteListSubtitle(
    Note n,
    Map<int, String> plotIdByPk,
    Map<int, String> sessionIdToName,
  ) {
    const style = TextStyle(
      fontSize: 12,
      color: AppDesignTokens.secondaryText,
    );
    final meta = formatFieldNoteContextLine(
      n,
      plotIdByPk: plotIdByPk,
      sessionIdToName: sessionIdToName,
      includeSession: true,
    );
    if (meta.isEmpty) {
      return Text(formatFieldNoteTimestampLine(n), style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatFieldNoteTimestampLine(n), style: style),
        Text(meta, style: style),
      ],
    );
  }
}

Future<void> _deleteNoteAfterConfirm(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final ok = await _showDeleteNoteDialog(context);
  if (ok != true || !context.mounted) return;
  final byline = await _currentByline(ref);
  if (!context.mounted) return;
  await _deleteNoteAndShowUndo(context, ref, note, byline);
}

Future<bool?> _showDeleteNoteDialog(BuildContext context) {
  return showDialog<bool>(
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
}

Future<String> _currentByline(WidgetRef ref) async {
  final user = await ref.read(currentUserProvider.future);
  return user?.displayName ?? 'Unknown';
}

Future<void> _deleteNoteAndShowUndo(
  BuildContext context,
  WidgetRef ref,
  Note note,
  String byline,
) async {
  await ref.read(notesRepositoryProvider).deleteNote(note.id, byline);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Note deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          ref.read(notesRepositoryProvider).restoreNote(note.id, byline);
        },
      ),
    ),
  );
}
