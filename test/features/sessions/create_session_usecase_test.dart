import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:arm_field_companion/features/sessions/usecases/create_session_usecase.dart';
import 'package:arm_field_companion/core/database/app_database.dart';

class MockSessionRepository implements SessionRepository {
  final List<Session> _sessions = [];

  @override
  Future<Session?> getOpenSession(int trialId) async {
    return _sessions
        .where((s) => s.trialId == trialId && s.endedAt == null)
        .firstOrNull;
  }

  @override
  Stream<Session?> watchOpenSession(int trialId) {
    return Stream.value(_sessions
        .where((s) => s.trialId == trialId && s.endedAt == null)
        .firstOrNull);
  }

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal,
      {int? createdByUserId}) async {
    return _sessions
        .where((s) => s.sessionDateLocal == dateLocal)
        .toList();
  }

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async {
    final existing = await getOpenSession(trialId);
    if (existing != null) throw OpenSessionExistsException(trialId);

    final session = Session(
      id: _sessions.length + 1,
      trialId: trialId,
      name: name,
      startedAt: DateTime.now(),
      endedAt: null,
      sessionDateLocal: sessionDateLocal,
      raterName: raterName,
      status: 'open',
    );
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> closeSession(int sessionId,
      {String? raterName, int? closedByUserId}) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _sessions[idx] = _sessions[idx].copyWith(endedAt: Value(DateTime.now()));
    }
  }

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async => [];

  @override
  Future<Session?> getSessionById(int sessionId) async {
    return _sessions.where((s) => s.id == sessionId).firstOrNull;
  }

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async {
    return _sessions.where((s) => s.trialId == trialId).toList();
  }
}

void main() {
  late CreateSessionUseCase useCase;
  late MockSessionRepository mockRepo;

  setUp(() {
    mockRepo = MockSessionRepository();
    useCase = CreateSessionUseCase(mockRepo);
  });

  group('CreateSessionUseCase — Invariants', () {
    test('SUCCESS: creates session with valid input', () async {
      final result = await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: 'Morning Rating',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1, 2, 3],
        raterName: 'Parminder',
      ));

      expect(result.success, true);
      expect(result.session?.name, 'Morning Rating');
    });

    test('INVARIANT: only one open session per trial', () async {
      await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: 'Morning Rating',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1],
      ));

      final result = await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: 'Afternoon Rating',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1],
      ));

      expect(result.success, false);
      expect(result.errorMessage, contains('already has an open session'));
    });

    test('INVARIANT: empty assessment list rejected', () async {
      final result = await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: 'Morning Rating',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [],
      ));

      expect(result.success, false);
      expect(result.errorMessage, contains('At least one assessment'));
    });

    test('INVARIANT: empty session name rejected', () async {
      final result = await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: '',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1],
      ));

      expect(result.success, false);
      expect(result.errorMessage, contains('must not be empty'));
    });

    test('SUCCESS: two trials can have separate open sessions', () async {
      final result1 = await useCase.execute(const CreateSessionInput(
        trialId: 1,
        name: 'Trial 1 Session',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1],
      ));

      final result2 = await useCase.execute(const CreateSessionInput(
        trialId: 2,
        name: 'Trial 2 Session',
        sessionDateLocal: '2026-03-04',
        assessmentIds: [1],
      ));

      expect(result1.success, true);
      expect(result2.success, true);
    });
  });
}
