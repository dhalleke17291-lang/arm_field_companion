import 'package:intl/intl.dart';

import '../database/app_database.dart';

final _fieldNoteDateTime = DateFormat('MMM d, yyyy · h:mm a');

/// Local date and time for field note rows (e.g. Apr 10, 2026 · 8:43 PM).
String formatFieldNoteDateTimeLocal(DateTime at) =>
    _fieldNoteDateTime.format(at.toLocal());

/// True when the note body was edited after creation ([Note.updatedAt] set).
bool fieldNoteWasEdited(Note note) => note.updatedAt != null;

/// Timestamp line with optional trailing ` (edited)`.
String formatFieldNoteTimestampLine(Note note) {
  final base = formatFieldNoteDateTimeLocal(note.createdAt);
  return fieldNoteWasEdited(note) ? '$base (edited)' : base;
}

/// Plot / session / author labels without the clock line.
String formatFieldNoteContextLine(
  Note note, {
  required Map<int, String> plotIdByPk,
  bool includeSession = true,
}) {
  final parts = <String>[];
  if (note.plotPk != null) {
    final id = plotIdByPk[note.plotPk!];
    parts.add(id != null ? 'Plot $id' : 'Plot #${note.plotPk}');
  }
  if (includeSession && note.sessionId != null) {
    parts.add('Session #${note.sessionId}');
  }
  if (note.raterName != null && note.raterName!.trim().isNotEmpty) {
    parts.add(note.raterName!.trim());
  }
  return parts.join(' · ');
}

/// Same as [formatFieldNoteContextLine] using trial [plots] for display ids.
String formatFieldNoteContextLineWithPlots(
  Note note,
  List<Plot> plots, {
  bool includeSession = true,
}) {
  final map = {for (final p in plots) p.id: p.plotId};
  return formatFieldNoteContextLine(
    note,
    plotIdByPk: map,
    includeSession: includeSession,
  );
}
