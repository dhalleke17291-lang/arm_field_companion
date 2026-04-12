import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Field observations ([Note] rows), auditable and exportable.
class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  String _auditDescription(String content, {int maxLen = 120}) {
    final t = content.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen)}…';
  }

  Future<int> createNote({
    required int trialId,
    int? plotPk,
    int? sessionId,
    required String content,
    required String createdBy,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('content must not be empty');
    }
    return _db.transaction(() async {
      final id = await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              trialId: trialId,
              plotPk: Value(plotPk),
              sessionId: Value(sessionId),
              content: trimmed,
              raterName: Value(createdBy),
            ),
          );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              plotPk: Value(plotPk),
              eventType: 'NOTE_CREATED',
              description: _auditDescription(trimmed),
              performedBy: Value(createdBy),
              metadata: Value(jsonEncode({'note_id': id})),
            ),
          );
      return id;
    });
  }

  Future<List<Note>> getNotesForTrial(int trialId) {
    return (_db.select(_db.notes)
          ..where((n) =>
              n.trialId.equals(trialId) & n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .get();
  }

  Stream<List<Note>> watchNotesForTrial(int trialId) {
    return (_db.select(_db.notes)
          ..where((n) =>
              n.trialId.equals(trialId) & n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }

  Future<List<Note>> getNotesForPlot(int trialId, int plotPk) {
    return (_db.select(_db.notes)
          ..where((n) =>
              n.trialId.equals(trialId) &
              n.plotPk.equals(plotPk) &
              n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .get();
  }

  Future<List<Note>> getNotesForSession(int trialId, int sessionId) {
    return (_db.select(_db.notes)
          ..where((n) =>
              n.trialId.equals(trialId) &
              n.sessionId.equals(sessionId) &
              n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .get();
  }

  Future<void> updateNote(int id, String content, String editedBy) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('content must not be empty');
    }
    final existing = await (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
    if (existing == null || existing.isDeleted) return;

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          content: Value(trimmed),
          updatedAt: Value(DateTime.now().toUtc()),
          updatedBy: Value(editedBy),
        ),
      );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              sessionId: Value(existing.sessionId),
              plotPk: Value(existing.plotPk),
              eventType: 'NOTE_UPDATED',
              description: _auditDescription(trimmed),
              performedBy: Value(editedBy),
              metadata: Value(jsonEncode({
                'note_id': id,
                'old_content': existing.content,
              })),
            ),
          );
    });
  }

  Future<void> deleteNote(int id, String deletedBy) async {
    final existing = await (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
    if (existing == null || existing.isDeleted) return;
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              sessionId: Value(existing.sessionId),
              plotPk: Value(existing.plotPk),
              eventType: 'NOTE_DELETED',
              description: 'Note $id deleted',
              performedBy: Value(deletedBy),
              metadata: Value(jsonEncode({
                'note_id': id,
                'content_preview': _auditDescription(existing.content, maxLen: 200),
              })),
            ),
          );
    });
  }

  /// Clears soft-delete so the note appears again in trial/plot/session lists and export.
  Future<void> restoreNote(int id, String restoredBy) async {
    final existing = await (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
    if (existing == null || !existing.isDeleted) return;

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              sessionId: Value(existing.sessionId),
              plotPk: Value(existing.plotPk),
              eventType: 'NOTE_RESTORED',
              description: 'Note $id restored',
              performedBy: Value(restoredBy),
              metadata: Value(jsonEncode({'note_id': id})),
            ),
          );
    });
  }
}
