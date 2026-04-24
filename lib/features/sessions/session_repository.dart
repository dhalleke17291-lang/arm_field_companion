import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/field_operation_date_rules.dart';
import '../../core/session_state.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  /// Open sessions for [trialId] (not unique in DB); returns most recently started.
  /// Excludes [kSessionStatusPlanned] — those are pre-scheduled slots that have
  /// not been started yet and must not be treated as active field work.
  Future<Session?> getOpenSession(int trialId) async {
    final rows = await (_db.select(_db.sessions)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.endedAt.isNull() &
              s.status.equals(kSessionStatusPlanned).not() &
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
              s.status.equals(kSessionStatusPlanned).not() &
              s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// All non-deleted sessions across all trials, most recent first.
  Future<List<Session>> getAllActiveSessions() {
    return (_db.select(_db.sessions)
          ..where((s) => s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
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
    int? cropStageBbch,
  }) async {
    await deduplicateSessionAssessmentsForTrial(trialId);

    final existing = await getOpenSession(trialId);
    if (existing != null) {
      throw OpenSessionExistsException(trialId);
    }

    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingleOrNull();
    if (trial == null) {
      throw StateError('Trial $trialId not found');
    }
    final sessionDateErr = validateSessionDateLocal(
      sessionDateLocal: sessionDateLocal,
      trialCreatedAt: trial.createdAt,
    );
    if (sessionDateErr != null) {
      throw OperationalDateRuleException(sessionDateErr);
    }

    return _db.transaction(() async {
      final sessionId = await _db.into(_db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: name,
              sessionDateLocal: sessionDateLocal,
              raterName: Value(raterName),
              createdByUserId: Value(createdByUserId),
              cropStageBbch: cropStageBbch != null
                  ? Value(cropStageBbch)
                  : const Value.absent(),
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

  /// Transitions an existing [kSessionStatusPlanned] session to
  /// [kSessionStatusOpen] and stamps [Sessions.startedAt] with "now".
  ///
  /// Planned sessions are created by the ARM importer (one per unique ARM
  /// Rating Date) as placeholders on the Sessions tab. Starting one gives the
  /// user the standard "open" session they then rate into.
  ///
  /// Throws [SessionNotFoundException] if the session does not exist (or is
  /// soft-deleted), [PlannedSessionStartException] if the session is not in
  /// the planned state, and [OpenSessionExistsException] if another session
  /// on the same trial is already open.
  Future<Session> startPlannedSession(
    int sessionId, {
    String? raterName,
    int? startedByUserId,
    int? cropStageBbch,
  }) async {
    return _db.transaction(() async {
      final session = await (_db.select(_db.sessions)
            ..where((s) => s.id.equals(sessionId) & s.isDeleted.equals(false)))
          .getSingleOrNull();
      if (session == null) {
        throw SessionNotFoundException(sessionId);
      }
      if (session.status != kSessionStatusPlanned) {
        throw PlannedSessionStartException(sessionId, session.status);
      }

      final existingOpen = await getOpenSession(session.trialId);
      if (existingOpen != null && existingOpen.id != sessionId) {
        throw OpenSessionExistsException(session.trialId);
      }

      final now = DateTime.now();
      await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(SessionsCompanion(
        status: const Value(kSessionStatusOpen),
        startedAt: Value(now),
        cropStageBbch:
            cropStageBbch != null ? Value(cropStageBbch) : const Value.absent(),
      ));

      // Populate session_assessments from ARM column mappings if none exist yet.
      // ARM-imported planned sessions skip createSession, so they have no
      // session_assessments rows. Derive them from arm_column_mappings ordered
      // by column index, falling back to the trial's defaultInSessions assessments.
      final existingSA = await (_db.select(_db.sessionAssessments)
            ..where((sa) => sa.sessionId.equals(sessionId)))
          .get();
      if (existingSA.isEmpty) {
        final mappings = await (_db.select(_db.armColumnMappings)
              ..where((m) =>
                  m.sessionId.equals(sessionId) &
                  m.trialAssessmentId.isNotNull())
              ..orderBy([(m) => OrderingTerm.asc(m.armColumnIndex)]))
            .get();

        final seenTaIds = <int>{};
        final assessmentIds = <int>[];
        for (final m in mappings) {
          final taId = m.trialAssessmentId!;
          if (!seenTaIds.add(taId)) continue;
          final ta = await (_db.select(_db.trialAssessments)
                ..where((t) => t.id.equals(taId)))
              .getSingleOrNull();
          if (ta?.legacyAssessmentId != null) {
            assessmentIds.add(ta!.legacyAssessmentId!);
          }
        }

        // Fallback: trial's defaultInSessions assessments when no ARM mappings
        if (assessmentIds.isEmpty) {
          final defaults = await (_db.select(_db.trialAssessments)
                ..where((ta) =>
                    ta.trialId.equals(session.trialId) &
                    ta.defaultInSessions.equals(true) &
                    ta.isActive.equals(true) &
                    ta.legacyAssessmentId.isNotNull())
                ..orderBy([(ta) => OrderingTerm.asc(ta.sortOrder)]))
              .get();
          for (final ta in defaults) {
            assessmentIds.add(ta.legacyAssessmentId!);
          }
        }

        for (var i = 0; i < assessmentIds.length; i++) {
          await _db.into(_db.sessionAssessments).insert(
                SessionAssessmentsCompanion.insert(
                  sessionId: sessionId,
                  assessmentId: assessmentIds[i],
                  sortOrder: Value(i),
                ),
              );
        }
      }

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(session.trialId),
              sessionId: Value(sessionId),
              eventType: 'SESSION_STARTED',
              description: 'Planned session "${session.name}" started',
              performedBy: Value(raterName),
              performedByUserId: Value(startedByUserId),
            ),
          );

      return (_db.select(_db.sessions)..where((s) => s.id.equals(sessionId)))
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

  /// Updates optional BBCH growth stage (0–99) for an existing session.
  Future<void> updateSessionCropStageBbch(
      int sessionId, int? cropStageBbch) async {
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      cropStageBbch:
          cropStageBbch == null ? const Value(null) : Value(cropStageBbch),
    ));
  }

  Future<void> updateSessionCropInjury(
    int sessionId, {
    required String status,
    String? notes,
    String? photoIds,
  }) async {
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      cropInjuryStatus: Value(status),
      cropInjuryNotes: Value(notes),
      cropInjuryPhotoIds: Value(photoIds),
    ));
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
              trialId: trialId != null ? Value(trialId) : const Value.absent(),
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

  /// Prefer [ArmTrialMetadata.armImportSessionId] when set; else [ArmImportUseCase] session
  /// (name contains Import session marker); else closest [Session.startedAt] to
  /// [ArmTrialMetadata.armImportedAt]; else most recent non-deleted session.
  Future<int?> resolveSessionIdForRatingShell(Trial trial) async {
    final sessions = await (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trial.id) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    if (sessions.isEmpty) return null;

    final arm = await (_db.select(_db.armTrialMetadata)
          ..where((m) => m.trialId.equals(trial.id)))
        .getSingleOrNull();

    final pinned = arm?.armImportSessionId;
    if (pinned != null) {
      final match = sessions.where((s) => s.id == pinned).toList();
      if (match.length == 1) {
        return match.single.id;
      }
      debugPrint(
        'resolveSessionIdForRatingShell: arm_trial_metadata.arm_import_session_id=$pinned '
        'not found for trial ${trial.id} or not in session list; using fallback.',
      );
    }

    if (arm?.isArmLinked == true) {
      for (final s in sessions) {
        if (s.name.contains('Import Session') ||
            s.name.contains('ARM Import')) {
          return s.id;
        }
      }
      final anchor = arm?.armImportedAt;
      if (anchor != null) {
        Session? best;
        var bestDelta = 1 << 62;
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

  /// Latest [Session.startedAt] per trial (non-deleted sessions only).
  /// Used by the portfolio screen for “last activity” sorting and subtitles.
  Future<Map<int, DateTime>> getLatestSessionStartedAtByTrial() async {
    final rows = await _db.customSelect(
      '''
SELECT trial_id AS tid, MAX(started_at) AS last_started
FROM sessions
WHERE is_deleted = 0
GROUP BY trial_id
''',
      readsFrom: {_db.sessions},
    ).get();
    final out = <int, DateTime>{};
    for (final row in rows) {
      final tid = row.read<int>('tid');
      final last = row.read<DateTime>('last_started');
      out[tid] = last;
    }
    return out;
  }

  /// True when this trial has any row in rating_records, photos, or plot_flags.
  /// Field observations ([Notes] table) intentionally do not lock assignments.
  Stream<bool> watchTrialHasSessionData(int trialId) {
    final id = Variable<int>(trialId);
    return _db
        .customSelect(
          '''
SELECT EXISTS(
  SELECT 1 FROM rating_records WHERE trial_id = ? LIMIT 1
  UNION ALL
  SELECT 1 FROM photos WHERE trial_id = ? AND is_deleted = 0 LIMIT 1
  UNION ALL
  SELECT 1 FROM plot_flags WHERE trial_id = ? LIMIT 1
) AS has_data
''',
          variables: <Variable>[id, id, id],
          readsFrom: {
            _db.ratingRecords,
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

/// Thrown by [SessionRepository.startPlannedSession] when the session exists
/// but is not in the planned state (e.g. already open, already closed).
class PlannedSessionStartException implements Exception {
  final int sessionId;
  final String currentStatus;
  PlannedSessionStartException(this.sessionId, this.currentStatus);

  @override
  String toString() =>
      'Session $sessionId is not planned (current status: $currentStatus) '
      'and cannot be started through the planned-session flow.';
}
