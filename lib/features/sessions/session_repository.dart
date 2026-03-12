import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  Future<Session?> getOpenSession(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.endedAt.isNull()))
        .getSingleOrNull();
  }

  Stream<Session?> watchOpenSession(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.endedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<List<Session>> getSessionsForTrial(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
  }

  /// Sessions for a given local date (yyyy-MM-dd). Optionally filter by createdByUserId.
  Future<List<Session>> getSessionsForDate(String dateLocal, {int? createdByUserId}) {
    var query = _db.select(_db.sessions)
      ..where((s) {
        var pred = s.sessionDateLocal.equals(dateLocal);
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
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      endedAt: Value(DateTime.now()),
      status: const Value('closed'),
    ));

    await _db.into(_db.auditEvents).insert(
          AuditEventsCompanion.insert(
            sessionId: Value(sessionId),
            eventType: 'SESSION_CLOSED',
            description: 'Session closed',
            performedBy: Value(raterName),
            performedByUserId: Value(closedByUserId),
          ),
        );
  }

  Future<List<Assessment>> getSessionAssessments(int sessionId) async {
    final sessionAssessmentRows = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId))
          ..orderBy([(sa) => OrderingTerm.asc(sa.sortOrder), (sa) => OrderingTerm.asc(sa.id)]))
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
    return (_db.select(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
  }
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