import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  // Only one open session per trial — spec invariant
  Future<Session?> getOpenSession(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.endedAt.isNull()))
        .getSingleOrNull();
  }

  // Watch open session for reactive UI
  Stream<Session?> watchOpenSession(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.endedAt.isNull()))
        .watchSingleOrNull();
  }

  // Get all sessions for a trial
  Future<List<Session>> getSessionsForTrial(int trialId) {
    return (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
  }

  // Create new session — enforces one open session per trial
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
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
            ),
          );

      // Lock in assessment set — immutable once session begins
      for (final assessmentId in assessmentIds) {
        await _db.into(_db.sessionAssessments).insert(
              SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: assessmentId,
              ),
            );
      }

      // Write audit event
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              eventType: 'SESSION_STARTED',
              description: 'Session "$name" started',
              performedBy: Value(raterName),
            ),
          );

      return await (_db.select(_db.sessions)
            ..where((s) => s.id.equals(sessionId)))
          .getSingle();
    });
  }

  // Close a session
  Future<void> closeSession(int sessionId, String? raterName) async {
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(endedAt: Value(DateTime.now())));

    await _db.into(_db.auditEvents).insert(
          AuditEventsCompanion.insert(
            sessionId: Value(sessionId),
            eventType: 'SESSION_CLOSED',
            description: 'Session closed',
            performedBy: Value(raterName),
          ),
        );
  }

  // Get assessments locked to a session
  Future<List<Assessment>> getSessionAssessments(int sessionId) async {
    final sessionAssessmentRows = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId)))
        .get();

    final assessmentIds =
        sessionAssessmentRows.map((sa) => sa.assessmentId).toList();

    return (_db.select(_db.assessments)
          ..where((a) => a.id.isIn(assessmentIds)))
        .get();
  }

  // Get session by id
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
