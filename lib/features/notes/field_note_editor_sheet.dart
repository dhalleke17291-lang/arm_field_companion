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

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _FieldNoteEditorSheet(
      trial: trial,
      plots: plots,
      sessions: sessions,
      byline: byline,
      existing: existing,
      initialPlotPk: initialPlotPk,
      initialSessionId: initialSessionId,
    ),
  );

  if (!context.mounted) return;
  if (saved == true) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notesForTrialProvider(trial.id));
    });
  }
}

class _FieldNoteEditorSheet extends ConsumerStatefulWidget {
  const _FieldNoteEditorSheet({
    required this.trial,
    required this.plots,
    required this.sessions,
    required this.byline,
    this.existing,
    this.initialPlotPk,
    this.initialSessionId,
  });

  final Trial trial;
  final List<Plot> plots;
  final List<Session> sessions;
  final String byline;
  final Note? existing;
  final int? initialPlotPk;
  final int? initialSessionId;

  @override
  ConsumerState<_FieldNoteEditorSheet> createState() =>
      _FieldNoteEditorSheetState();
}

class _FieldNoteEditorSheetState extends ConsumerState<_FieldNoteEditorSheet> {
  late final TextEditingController _contentController;
  late int? _plotPk;
  late int? _sessionId;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.existing?.content ?? '');
    _plotPk = widget.existing?.plotPk ?? widget.initialPlotPk;
    _sessionId = widget.existing?.sessionId ?? widget.initialSessionId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext sheetContext) async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(notesRepositoryProvider);
    try {
      if (widget.existing == null) {
        await repo.createNote(
          trialId: widget.trial.id,
          plotPk: _plotPk,
          sessionId: _sessionId,
          content: text,
          createdBy: widget.byline,
        );
      } else {
        await repo.updateNote(
          widget.existing!.id,
          text,
          widget.byline,
        );
      }
      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext, true);
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
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
                  controller: _contentController,
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
                    value: _plotPk,
                    decoration: const InputDecoration(
                      labelText: 'Link to plot',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Entire trial'),
                      ),
                      ...widget.plots.map(
                        (p) => DropdownMenuItem<int?>(
                          value: p.id,
                          child: Text(p.plotId),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => _plotPk = v),
                  ),
                  const SizedBox(height: AppDesignTokens.spacing12),
                  DropdownButtonFormField<int?>(
                    value: _sessionId,
                    decoration: const InputDecoration(
                      labelText: 'Link to session',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...widget.sessions.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => _sessionId = v),
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
                      onPressed: () => _save(ctx),
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
  }
}
