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

      await _ensureSessionAssessments(
          sessionId: sessionId, trialId: session.trialId);

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

  /// Populate session_assessments from arm_column_mappings if none exist yet.
  /// ARM-imported planned sessions skip createSession, so they have no
  /// session_assessments rows. Derives them from arm_column_mappings ordered
  /// by column index, falling back to the trial's defaultInSessions assessments.
  /// Also back-fills ARM-imported session names from the old "Planned — $date"
  /// form to the cleaner assessment-names form.
  Future<void> _ensureSessionAssessments({
    required int sessionId,
    required int trialId,
  }) async {
    final existingSA = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId)))
        .get();
    if (existingSA.isNotEmpty) {
      await _backfillArmSessionName(sessionId: sessionId, trialId: trialId);
      return;
    }

    final mappings = await (_db.select(_db.armColumnMappings)
          ..where((m) =>
              m.sessionId.equals(sessionId) &
              m.trialAssessmentId.isNotNull())
          ..orderBy([(m) => OrderingTerm.asc(m.armColumnIndex)]))
        .get();

    final seenTaIds = <int>{};
    final orderedTaIds = <int>[];
    for (final m in mappings) {
      final taId = m.trialAssessmentId!;
      if (seenTaIds.add(taId)) orderedTaIds.add(taId);
    }

    // Fallback: trial's defaultInSessions assessments when no ARM mappings.
    if (orderedTaIds.isEmpty) {
      final defaults = await (_db.select(_db.trialAssessments)
            ..where((ta) =>
                ta.trialId.equals(trialId) &
                ta.defaultInSessions.equals(true) &
                ta.isActive.equals(true))
            ..orderBy([(ta) => OrderingTerm.asc(ta.sortOrder)]))
          .get();
      for (final ta in defaults) {
        orderedTaIds.add(ta.id);
      }
    }

    // Resolve each trial_assessment to a legacy assessment row, creating the
    // legacy row on demand when the ARM import never populated legacyAssessmentId.
    // Mirrors TrialAssessmentRepository.getOrCreateLegacyAssessmentIdsForTrialAssessments
    // but inlined to avoid a cross-repository dependency.
    final assessmentIds = <int>[];
    for (final taId in orderedTaIds) {
      final ta = await (_db.select(_db.trialAssessments)
            ..where((t) => t.id.equals(taId)))
          .getSingleOrNull();
      if (ta == null || ta.trialId != trialId) continue;
      if (ta.legacyAssessmentId != null) {
        // Back-fill cleanup: an earlier revision of this helper always named
        // the legacy assessment "DisplayName — TA$id". Rename to the clean
        // display name when no other assessment in the trial claims it, so the
        // rating screen shows "CONTRO" instead of "CONTRO — TA5".
        final existingAsmt = await (_db.select(_db.assessments)
              ..where((a) => a.id.equals(ta.legacyAssessmentId!)))
            .getSingleOrNull();
        if (existingAsmt != null) {
          final def = await (_db.select(_db.assessmentDefinitions)
                ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
              .getSingleOrNull();
          final cleanName = ta.displayNameOverride ?? def?.name;
          if (cleanName != null &&
              existingAsmt.name == '$cleanName — TA$taId') {
            final clash = await (_db.select(_db.assessments)
                  ..where((a) =>
                      a.trialId.equals(trialId) &
                      a.name.equals(cleanName) &
                      a.id.equals(existingAsmt.id).not()))
                .getSingleOrNull();
            if (clash == null) {
              await (_db.update(_db.assessments)
                    ..where((a) => a.id.equals(existingAsmt.id)))
                  .write(AssessmentsCompanion(name: Value(cleanName)));
            }
          }
        }
        assessmentIds.add(ta.legacyAssessmentId!);
        continue;
      }
      final def = await (_db.select(_db.assessmentDefinitions)
            ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
          .getSingleOrNull();
      if (def == null) continue;
      // Prefer the clean display name ("CONTRO", "Phytotoxicity", etc.) so
      // the rating screen doesn't surface internal row ids like "CONTRO — TA5".
      // Fall back to the legacy uniqueness-suffixed form only when a different
      // trial_assessment already claims the clean name (extremely rare for ARM
      // imports — dedup guarantees one TA per identity within a trial).
      final displayName = ta.displayNameOverride ?? def.name;
      int? legacyId;
      final existingClean = await (_db.select(_db.assessments)
            ..where((a) =>
                a.trialId.equals(trialId) & a.name.equals(displayName)))
          .getSingleOrNull();
      if (existingClean != null) {
        final claimed = await (_db.select(_db.trialAssessments)
              ..where((t) =>
                  t.trialId.equals(trialId) &
                  t.legacyAssessmentId.equals(existingClean.id)))
            .getSingleOrNull();
        if (claimed == null || claimed.id == taId) {
          legacyId = existingClean.id;
        }
      }
      if (legacyId == null) {
        final name = existingClean == null
            ? displayName
            : '$displayName — TA$taId';
        final suffixed = existingClean == null
            ? null
            : await (_db.select(_db.assessments)
                  ..where((a) =>
                      a.trialId.equals(trialId) & a.name.equals(name)))
                .getSingleOrNull();
        legacyId = suffixed?.id ??
            await _db.into(_db.assessments).insert(
                  AssessmentsCompanion.insert(
                    trialId: trialId,
                    name: name,
                    dataType: Value(def.dataType),
                    unit: Value(def.unit),
                    minValue: Value(def.scaleMin),
                    maxValue: Value(def.scaleMax),
                  ),
                );
      }
      await (_db.update(_db.trialAssessments)
            ..where((t) => t.id.equals(taId)))
          .write(TrialAssessmentsCompanion(legacyAssessmentId: Value(legacyId)));
      assessmentIds.add(legacyId);
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

    await _backfillArmSessionName(sessionId: sessionId, trialId: trialId);
  }

  /// Batch-rename every "Planned — $date" session in [trialId] to a
  /// comma-joined list of assessment names, derived from arm_column_mappings
  /// (preferred) or session_assessments (fallback). Exists so the trial
  /// detail screen can back-fill *all* pre-fix planned sessions on load
  /// without waiting for the user to tap into each one. Returns the number
  /// of sessions renamed.
  Future<int> backfillArmPlannedSessionNames(int trialId) async {
    final legacyPattern = RegExp(r'^Planned\s*[—-]\s*');
    final sessions = await (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false)))
        .get();
    var renamed = 0;
    for (final s in sessions) {
      if (!legacyPattern.hasMatch(s.name)) continue;
      final names = await _computeArmAssessmentNamesForSession(s.id, trialId);
      if (names.isEmpty) continue;
      await (_db.update(_db.sessions)..where((t) => t.id.equals(s.id)))
          .write(SessionsCompanion(name: Value(names.join(', '))));
      renamed++;
    }
    return renamed;
  }

  /// Returns the ordered, deduplicated assessment display names for a
  /// session, looking first at arm_column_mappings (planned sessions with
  /// no session_assessments yet) and falling back to session_assessments
  /// (sessions populated by createSession or the self-heal path).
  Future<List<String>> _computeArmAssessmentNamesForSession(
    int sessionId,
    int trialId,
  ) async {
    final names = <String>[];
    final seen = <String>{};

    // Prefer arm_column_mappings so we can rename planned sessions before
    // they're ever opened (no session_assessments rows yet).
    final mappings = await (_db.select(_db.armColumnMappings)
          ..where((m) =>
              m.sessionId.equals(sessionId) &
              m.trialAssessmentId.isNotNull())
          ..orderBy([(m) => OrderingTerm.asc(m.armColumnIndex)]))
        .get();
    final seenTa = <int>{};
    for (final m in mappings) {
      final taId = m.trialAssessmentId!;
      if (!seenTa.add(taId)) continue;
      final ta = await (_db.select(_db.trialAssessments)
            ..where((t) => t.id.equals(taId)))
          .getSingleOrNull();
      if (ta == null) continue;
      var name = ta.displayNameOverride?.trim();
      if (name == null || name.isEmpty) {
        final def = await (_db.select(_db.assessmentDefinitions)
              ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
            .getSingleOrNull();
        name = def?.name.trim();
      }
      if (name == null || name.isEmpty) continue;
      if (seen.add(name)) names.add(name);
    }
    if (names.isNotEmpty) return names;

    // Fallback: session_assessments already populated.
    final saRows = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId))
          ..orderBy([
            (sa) => OrderingTerm.asc(sa.sortOrder),
            (sa) => OrderingTerm.asc(sa.id),
          ]))
        .get();
    if (saRows.isEmpty) return names;
    final ids = saRows.map((sa) => sa.assessmentId).toList();
    final asmtRows = await (_db.select(_db.assessments)
          ..where((a) => a.id.isIn(ids)))
        .get();
    final byId = {for (final a in asmtRows) a.id: a};
    for (final id in ids) {
      final a = byId[id];
      if (a == null) continue;
      final cleaned =
          a.name.replaceAll(RegExp(r'\s+—\s+TA\d+$'), '').trim();
      if (cleaned.isEmpty) continue;
      if (seen.add(cleaned)) names.add(cleaned);
    }
    return names;
  }

  /// Rename an ARM-imported planned session from the legacy
  /// "Planned — $date" form to a comma-joined assessment-names form.
  /// The session tile already shows the date separately, so keeping the date
  /// in the name was duplication. Only runs for sessions whose current name
  /// matches the old pattern — any user-customized name is left alone.
  Future<void> _backfillArmSessionName({
    required int sessionId,
    required int trialId,
  }) async {
    final session = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    if (session == null) return;
    final oldPattern = RegExp(r'^Planned\s*[—-]\s*');
    if (!oldPattern.hasMatch(session.name)) return;

    final names = await _computeArmAssessmentNamesForSession(sessionId, trialId);
    if (names.isEmpty) return;

    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(name: Value(names.join(', '))));
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

    var sessionAssessmentRows = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId))
          ..orderBy([
            (sa) => OrderingTerm.asc(sa.sortOrder),
            (sa) => OrderingTerm.asc(sa.id)
          ]))
        .get();

    // Self-heal: always run the ensure helper — it populates rows when empty
    // and back-fills legacy "Planned — date" session names either way. Both
    // operations are idempotent, so running on every read is cheap.
    final session = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    if (session != null) {
      await _ensureSessionAssessments(
          sessionId: sessionId, trialId: session.trialId);
      if (sessionAssessmentRows.isEmpty) {
        sessionAssessmentRows = await (_db.select(_db.sessionAssessments)
              ..where((sa) => sa.sessionId.equals(sessionId))
              ..orderBy([
                (sa) => OrderingTerm.asc(sa.sortOrder),
                (sa) => OrderingTerm.asc(sa.id)
              ]))
            .get();
      }
    }

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
