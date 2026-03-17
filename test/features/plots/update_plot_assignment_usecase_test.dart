import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/features/plots/usecases/update_plot_assignment_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';

class MockAssignmentRepository implements AssignmentRepository {
  final List<Map<String, dynamic>> _upserted = [];
  bool shouldThrow = false;

  List<Map<String, dynamic>> get upserted => _upserted;

  @override
  Future<Assignment?> getForPlot(int plotPk) async => null;

  @override
  Future<Assignment?> getForTrialAndPlot(int trialId, int plotPk) async => null;

  @override
  Future<List<Assignment>> getForTrial(int trialId) async => [];

  @override
  Stream<List<Assignment>> watchForTrial(int trialId) => Stream.value([]);

  @override
  Future<void> upsert({
    required int trialId,
    required int plotId,
    int? treatmentId,
    int? replication,
    int? block,
    int? range,
    int? column,
    int? position,
    bool? isCheck,
    bool? isControl,
    String? assignmentSource,
    DateTime? assignedAt,
    int? assignedBy,
    String? notes,
  }) async {
    if (shouldThrow) throw Exception('Mock DB error');
    _upserted.add({
      'trialId': trialId,
      'plotId': plotId,
      'treatmentId': treatmentId,
      'assignmentSource': assignmentSource,
    });
  }

  @override
  Future<void> upsertBulk({
    required int trialId,
    required Map<int, int?> plotPkToTreatmentId,
    String? assignmentSource,
    DateTime? assignedAt,
  }) async {
    if (shouldThrow) throw Exception('Mock DB error');
    for (final entry in plotPkToTreatmentId.entries) {
      _upserted.add({
        'trialId': trialId,
        'plotId': entry.key,
        'treatmentId': entry.value,
        'assignmentSource': assignmentSource,
      });
    }
  }
}

/// Mock that returns configurable session list for assignments-lock check.
class MockSessionRepository implements SessionRepository {
  List<Session> sessionsForTrial = [];

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      List.from(sessionsForTrial);

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal,
          {int? createdByUserId}) async =>
      [];

  @override
  Future<Session?> getOpenSession(int trialId) async => null;

  @override
  Stream<Session?> watchOpenSession(int trialId) => Stream.value(null);

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> closeSession(int sessionId,
      {String? raterName, int? closedByUserId}) async {}

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async => [];

  @override
  Future<Session?> getSessionById(int sessionId) async => null;

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}

  @override
  Future<void> softDeleteSession(int sessionId, {String? deletedBy}) async {}
}

Trial _trial({String status = 'ACTIVE'}) => Trial(
      id: 1,
      name: 'Test Trial',
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      crop: null,
      location: null,
      season: null,
      isDeleted: false,
    );

void main() {
  late UpdatePlotAssignmentUseCase useCase;
  late MockAssignmentRepository mockRepo;
  late MockSessionRepository mockSessionRepo;

  setUp(() {
    mockRepo = MockAssignmentRepository();
    mockSessionRepo = MockSessionRepository();
    useCase = UpdatePlotAssignmentUseCase(mockRepo, mockSessionRepo);
  });

  group('UpdatePlotAssignmentUseCase — updateOne', () {
    test('SUCCESS: assigns treatment to plot on active trial', () async {
      final result = await useCase.updateOne(
        trial: _trial(status: 'ACTIVE'),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, true);
      expect(mockRepo.upserted.length, 1);
      expect(mockRepo.upserted.first['treatmentId'], 5);
      expect(mockRepo.upserted.first['plotId'], 10);
    });

    test('SUCCESS: unassigns treatment (null treatmentId)', () async {
      final result = await useCase.updateOne(
        trial: _trial(status: 'ACTIVE'),
        plotPk: 10,
        treatmentId: null,
      );
      expect(result.success, true);
      expect(mockRepo.upserted.first['treatmentId'], null);
    });

    test('LOCK: rejects assignment when trial is CLOSED', () async {
      final result = await useCase.updateOne(
        trial: _trial(status: 'closed'),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, isNotNull);
      expect(mockRepo.upserted, isEmpty);
    });

    test('LOCK: rejects assignment when trial is LOCKED', () async {
      final result = await useCase.updateOne(
        trial: _trial(status: 'active'),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(mockRepo.upserted, isEmpty);
    });

    test('FAILURE: DB error returns failure result', () async {
      mockRepo.shouldThrow = true;
      final result = await useCase.updateOne(
        trial: _trial(),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Update failed'));
    });

    test('LOCK: rejects when trial has sessions (assignments fixed)', () async {
      mockSessionRepo.sessionsForTrial = [
        Session(
          id: 1,
          trialId: 1,
          name: 'S1',
          startedAt: DateTime.now(),
          endedAt: null,
          sessionDateLocal: '2026-01-01',
          raterName: null,
          createdByUserId: null,
          status: 'open',
          isDeleted: false,
        ),
      ];
      final result = await useCase.updateOne(
        trial: _trial(status: 'draft'),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('session data'));
      expect(mockRepo.upserted, isEmpty);
    });
  });

  group('UpdatePlotAssignmentUseCase — updateBulk', () {
    test('SUCCESS: bulk assigns multiple plots', () async {
      final result = await useCase.updateBulk(
        trial: _trial(),
        plotPkToTreatmentId: {1: 10, 2: 10, 3: 20},
      );
      expect(result.success, true);
      expect(mockRepo.upserted.length, 3);
    });

    test('SUCCESS: empty map returns success without writing', () async {
      final result = await useCase.updateBulk(
        trial: _trial(),
        plotPkToTreatmentId: {},
      );
      expect(result.success, true);
      expect(mockRepo.upserted, isEmpty);
    });

    test('LOCK: rejects bulk assignment on locked trial', () async {
      final result = await useCase.updateBulk(
        trial: _trial(status: 'active'),
        plotPkToTreatmentId: {1: 10, 2: 20},
      );
      expect(result.success, false);
      expect(mockRepo.upserted, isEmpty);
    });

    test('assignmentSource is set to manual for all plots', () async {
      await useCase.updateBulk(
        trial: _trial(),
        plotPkToTreatmentId: {1: 10, 2: 20},
      );
      for (final entry in mockRepo.upserted) {
        expect(entry['assignmentSource'], 'manual');
      }
    });
  });
}
