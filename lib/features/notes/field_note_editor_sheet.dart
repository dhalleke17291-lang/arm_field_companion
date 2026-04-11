import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';

/// Add or edit a field observation ([Note]).
Future<void> showFieldNoteEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  required Trial trial,
  int? initialPlotPk,
  int? initialSessionId,
  Note? existing,
}) async {
  final plots = await ref.read(plotsForTrialProvider(trial.id).future);
  final sessions = await ref.read(sessionsForTrialProvider(trial.id).future);
  final user = await ref.read(currentUserProvider.future);
  final byline = user?.displayName ?? 'Unknown';

  if (!context.mounted) return;

  final contentController = TextEditingController(text: existing?.content ?? '');
  int? plotPk = existing?.plotPk ?? initialPlotPk;
  int? sessionId = existing?.sessionId ?? initialSessionId;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDesignTokens.spacing16,
                AppDesignTokens.spacing16,
                AppDesignTokens.spacing16,
                AppDesignTokens.spacing24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null ? 'Add Field Note' : 'Edit Field Note',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          color: AppDesignTokens.primaryText,
                        ),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing12),
                  TextField(
                    controller: contentController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (existing == null) ...[
                    const SizedBox(height: AppDesignTokens.spacing12),
                    DropdownButtonFormField<int?>(
                      value: plotPk,
                      decoration: const InputDecoration(
                        labelText: 'Link to plot',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Entire trial'),
                        ),
                        ...plots.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.plotId),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => plotPk = v),
                    ),
                    const SizedBox(height: AppDesignTokens.spacing12),
                    DropdownButtonFormField<int?>(
                      value: sessionId,
                      decoration: const InputDecoration(
                        labelText: 'Link to session',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...sessions.map(
                          (s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => sessionId = v),
                    ),
                  ],
                  const SizedBox(height: AppDesignTokens.spacing16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final text = contentController.text.trim();
                          if (text.isEmpty) return;
                          final repo = ref.read(notesRepositoryProvider);
                          try {
                            if (existing == null) {
                              await repo.createNote(
                                trialId: trial.id,
                                plotPk: plotPk,
                                sessionId: sessionId,
                                content: text,
                                createdBy: byline,
                              );
                            } else {
                              await repo.updateNote(
                                existing.id,
                                text,
                                byline,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  contentController.dispose();
  if (saved == true) {
    // Defer until after the modal route finishes tearing down so we do not
    // invalidate while dependents are still deactivating (debug assert).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notesForTrialProvider(trial.id));
    });
  }
}
