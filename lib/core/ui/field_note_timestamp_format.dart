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
///
/// [sessionIdToName] maps session PK → [Session.name] (e.g. "SESSION 1").
/// If a linked session id is missing from the map, falls back to `Session #id`.
String formatFieldNoteContextLine(
  Note note, {
  required Map<int, String> plotIdByPk,
  Map<int, String> sessionIdToName = const {},
  bool includeSession = true,
}) {
  final parts = <String>[];
  if (note.plotPk != null) {
    final id = plotIdByPk[note.plotPk!];
    parts.add(id != null ? 'Plot $id' : 'Plot #${note.plotPk}');
  }
  if (includeSession && note.sessionId != null) {
    final sid = note.sessionId!;
    final name = sessionIdToName[sid]?.trim();
    parts.add(
      name != null && name.isNotEmpty ? name : 'Session #$sid',
    );
  }
  if (note.raterName != null && note.raterName!.trim().isNotEmpty) {
    parts.add(note.raterName!.trim());
  }
  return parts.join(' · ');
}

/// Same as [formatFieldNoteContextLine] using trial [plots] and optional [sessions].
String formatFieldNoteContextLineWithPlots(
  Note note,
  List<Plot> plots, {
  List<Session> sessions = const [],
  bool includeSession = true,
}) {
  final plotMap = {for (final p in plots) p.id: p.plotId};
  final sessionMap = {for (final s in sessions) s.id: s.name};
  return formatFieldNoteContextLine(
    note,
    plotIdByPk: plotMap,
    sessionIdToName: sessionMap,
    includeSession: includeSession,
  );
}
