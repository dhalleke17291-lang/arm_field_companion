import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  /// Open sessions for [trialId] (not unique in DB); returns most recently started.
  Future<Session?> getOpenSession(int trialId) async {
    final rows = await (_db.select(_db.sessions)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.endedAt.isNull() &
              s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Same semantics as [getOpenSession]; does not assume at most one open row.
  Stream<Session?> watchOpenSession(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.endedAt.isNull() &
              s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<List<Session>> getSessionsForTrial(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
  }

  /// Sessions for a given local date (yyyy-MM-dd). Optionally filter by createdByUserId.
  Future<List<Session>> getSessionsForDate(String dateLocal,
      {int? createdByUserId}) {
    var query = _db.select(_db.sessions)
      ..where((s) {
        var pred =
            s.sessionDateLocal.equals(dateLocal) & s.isDeleted.equals(false);
        if (createdByUserId != null) {
          pred = pred & s.createdByUserId.equals(createdByUserId);
        }
        return pred;
      })
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    return query.get();
  }

  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async {
    await deduplicateSessionAssessmentsForTrial(trialId);

    final existing = await getOpenSession(trialId);
    if (existing != null) {
      throw OpenSessionExistsException(trialId);
    }

    return _db.transaction(() async {
      final sessionId = await _db.into(_db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: name,
              sessionDateLocal: sessionDateLocal,
              raterName: Value(raterName),
              createdByUserId: Value(createdByUserId),
            ),
          );

      for (var i = 0; i < assessmentIds.length; i++) {
        await _db.into(_db.sessionAssessments).insert(
              SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: assessmentIds[i],
                sortOrder: Value(i),
              ),
            );
      }

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              eventType: 'SESSION_STARTED',
              description: 'Session "$name" started',
              performedBy: Value(raterName),
              performedByUserId: Value(createdByUserId),
            ),
          );

      return await (_db.select(_db.sessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingle();
    });
  }

  Future<void> closeSession(
    int sessionId, {
    String? raterName,
    int? closedByUserId,
  }) async {
    final sessionRow = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    final trialIdForAudit = sessionRow?.trialId;

    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      endedAt: Value(DateTime.now()),
      status: const Value('closed'),
    ));

    await _db.into(_db.auditEvents).insert(
          AuditEventsCompanion.insert(
            trialId: trialIdForAudit != null
                ? Value(trialIdForAudit)
                : const Value.absent(),
            sessionId: Value(sessionId),
            eventType: 'SESSION_CLOSED',
            description: 'Session closed',
            performedBy: Value(raterName),
            performedByUserId: Value(closedByUserId),
          ),
        );
  }

  Future<List<Assessment>> getSessionAssessments(int sessionId) async {
    await deduplicateSessionAssessments(sessionId);

    final sessionAssessmentRows = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId))
          ..orderBy([
            (sa) => OrderingTerm.asc(sa.sortOrder),
            (sa) => OrderingTerm.asc(sa.id)
          ]))
        .get();

    final assessmentIds =
        sessionAssessmentRows.map((sa) => sa.assessmentId).toList();
    if (assessmentIds.isEmpty) return [];

    final assessments = await (_db.select(_db.assessments)
          ..where((a) => a.id.isIn(assessmentIds)))
        .get();
    final byId = {for (final a in assessments) a.id: a};
    return [for (final id in assessmentIds) byId[id]!];
  }

  /// Whether [assessmentId] is linked to [sessionId] in [session_assessments].
  ///
  /// Existence-only: does not assume at most one row per (session, assessment).
  Future<bool> isAssessmentInSession(int assessmentId, int sessionId) async {
    final rows = await (_db.select(_db.sessionAssessments)
          ..where((sa) =>
              sa.sessionId.equals(sessionId) &
              sa.assessmentId.equals(assessmentId)))
        .get();
    return rows.isNotEmpty;
  }

  /// Removes duplicate [session_assessments] rows for [sessionId], keeping the
  /// lowest row [id] per (session_id, assessment_id).
  ///
  /// Returns the number of rows deleted. Safe to call repeatedly.
  Future<int> deduplicateSessionAssessments(int sessionId) async {
    return _db.transaction(() async {
      final rows = await (_db.select(_db.sessionAssessments)
            ..where((sa) => sa.sessionId.equals(sessionId))
            ..orderBy([(sa) => OrderingTerm.asc(sa.id)]))
          .get();
      if (rows.length <= 1) return 0;

      final byAssessment = <int, List<SessionAssessment>>{};
      for (final r in rows) {
        byAssessment.putIfAbsent(r.assessmentId, () => []).add(r);
      }
      var deleted = 0;
      for (final list in byAssessment.values) {
        if (list.length <= 1) continue;
        list.sort((a, b) => a.id.compareTo(b.id));
        final removeIds = list.skip(1).map((e) => e.id).toList();
        deleted += await (_db.delete(_db.sessionAssessments)
              ..where((sa) => sa.id.isIn(removeIds)))
            .go();
      }
      return deleted;
    });
  }

  /// Runs [deduplicateSessionAssessments] for every non-deleted session in [trialId].
  Future<int> deduplicateSessionAssessmentsForTrial(int trialId) async {
    final sessions = await getSessionsForTrial(trialId);
    var total = 0;
    for (final s in sessions) {
      total += await deduplicateSessionAssessments(s.id);
    }
    return total;
  }

  /// Updates the rating order for this session. Same sequence applies to every plot.
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {
    for (var i = 0; i < assessmentIdsInOrder.length; i++) {
      await (_db.update(_db.sessionAssessments)
            ..where((sa) =>
                sa.sessionId.equals(sessionId) &
                sa.assessmentId.equals(assessmentIdsInOrder[i])))
          .write(SessionAssessmentsCompanion(sortOrder: Value(i)));
    }
  }

  Future<Session?> getSessionById(int sessionId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId) & s.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Soft-delete session and all rating_records for that session.
  /// [deletedByUserId] optional; stored on audit event as [performedByUserId].
  Future<void> softDeleteSession(int sessionId,
      {String? deletedBy, int? deletedByUserId}) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      final sessionRow = await (_db.select(_db.sessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingleOrNull();
      final trialId = sessionRow?.trialId;

      final deletedRatingsCount = await (_db.select(_db.ratingRecords)
            ..where((r) => r.sessionId.equals(sessionId)))
          .get()
          .then((l) => l.length);

      await (_db.update(_db.ratingRecords)
            ..where((r) => r.sessionId.equals(sessionId)))
          .write(RatingRecordsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));
      await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(SessionsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ));

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId:
                  trialId != null ? Value(trialId) : const Value.absent(),
              sessionId: Value(sessionId),
              eventType: 'SESSION_DELETED',
              description: 'Session deleted and moved to Recovery',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'deleted_ratings_count': deletedRatingsCount,
              })),
            ),
          );
    });
  }

  /// Recovery: soft-deleted sessions for a trial, newest deletion first.
  Future<List<Session>> getDeletedSessionsForTrial(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.deletedAt)]))
        .get();
  }

  /// Recovery: all soft-deleted sessions, newest deletion first.
  Future<List<Session>> getAllDeletedSessions() {
    return (_db.select(_db.sessions)
          ..where((s) => s.isDeleted.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.deletedAt)]))
        .get();
  }

  /// Recovery: single soft-deleted session by id, or null.
  Future<Session?> getDeletedSessionById(int id) {
    return (_db.select(_db.sessions)
          ..where((s) => s.id.equals(id) & s.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  /// Restores a soft-deleted session and its soft-deleted ratings for that session.
  Future<SessionRestoreResult> restoreSession(int sessionId,
      {String? restoredBy, int? restoredByUserId}) async {
    return _db.transaction(() async {
      final session = await getDeletedSessionById(sessionId);
      if (session == null) {
        return SessionRestoreResult.failure(
          'This session was not found or is no longer deleted.',
        );
      }

      final trial = await (_db.select(_db.trials)
            ..where((t) => t.id.equals(session.trialId)))
          .getSingleOrNull();
      if (trial == null) {
        return SessionRestoreResult.failure(
          'Trial not found. This session cannot be restored.',
        );
      }
      if (trial.isDeleted) {
        return SessionRestoreResult.failure(
          'Restore the trial from Recovery before restoring this session.',
        );
      }

      final restoredRatingsCount = await (_db.update(_db.ratingRecords)
            ..where((r) =>
                r.sessionId.equals(sessionId) & r.isDeleted.equals(true)))
          .write(
        const RatingRecordsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(
        const SessionsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(session.trialId),
              sessionId: Value(sessionId),
              eventType: 'SESSION_RESTORED',
              description: 'Session restored from Recovery',
              performedBy: Value(restoredBy),
              performedByUserId: Value(restoredByUserId),
              metadata: Value(jsonEncode({
                'restored_ratings_count': restoredRatingsCount,
              })),
            ),
          );

      return SessionRestoreResult.ok();
    });
  }

  /// Prefer [Trial.armImportSessionId] when set; else [ArmImportUseCase] session
  /// (name contains Import session marker); else closest [Session.startedAt] to
  /// [Trial.armImportedAt]; else most recent non-deleted session.
  Future<int?> resolveSessionIdForRatingShell(Trial trial) async {
    final sessions = await (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trial.id) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    if (sessions.isEmpty) return null;

    final pinned = trial.armImportSessionId;
    if (pinned != null) {
      final match = sessions.where((s) => s.id == pinned).toList();
      if (match.length == 1) {
        return match.single.id;
      }
      debugPrint(
        'resolveSessionIdForRatingShell: trials.armImportSessionId=$pinned '
        'not found for trial ${trial.id} or not in session list; using fallback.',
      );
    }

    if (trial.isArmLinked) {
      for (final s in sessions) {
        if (s.name.contains('Import Session') || s.name.contains('ARM Import')) {
          return s.id;
        }
      }
      final anchor = trial.armImportedAt;
      if (anchor != null) {
        Session? best;
        var bestDelta = 9223372036854775807;
        for (final s in sessions) {
          final d = (s.startedAt.millisecondsSinceEpoch -
                  anchor.millisecondsSinceEpoch)
              .abs();
          if (d < bestDelta) {
            bestDelta = d;
            best = s;
          }
        }
        return best?.id;
      }
    }
    return sessions.first.id;
  }

  /// True when this trial has any row in rating_records, notes, photos, or plot_flags.
  Stream<bool> watchTrialHasSessionData(int trialId) {
    final id = Variable<int>(trialId);
    return _db
        .customSelect(
          '''
SELECT EXISTS(
  SELECT 1 FROM rating_records WHERE trial_id = ? LIMIT 1
  UNION ALL
  SELECT 1 FROM notes WHERE trial_id = ? LIMIT 1
  UNION ALL
  SELECT 1 FROM photos WHERE trial_id = ? AND is_deleted = 0 LIMIT 1
  UNION ALL
  SELECT 1 FROM plot_flags WHERE trial_id = ? LIMIT 1
) AS has_data
''',
          variables: <Variable>[id, id, id, id],
          readsFrom: {
            _db.ratingRecords,
            _db.notes,
            _db.photos,
            _db.plotFlags,
          },
        )
        .watchSingle()
        .map((row) => row.read<bool>('has_data'));
  }
}

/// Result of [SessionRepository.restoreSession].
class SessionRestoreResult {
  const SessionRestoreResult._({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory SessionRestoreResult.ok() =>
      const SessionRestoreResult._(success: true);

  factory SessionRestoreResult.failure(String message) =>
      SessionRestoreResult._(success: false, errorMessage: message);
}

class OpenSessionExistsException implements Exception {
  final int trialId;
  OpenSessionExistsException(this.trialId);

  @override
  String toString() =>
      'Trial $trialId already has an open session. Resume it before creating a new one.';
}

class SessionNotFoundException implements Exception {
  final int sessionId;
  SessionNotFoundException(this.sessionId);

  @override
  String toString() => 'Session with id $sessionId not found.';
}
