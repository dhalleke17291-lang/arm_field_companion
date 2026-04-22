import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_exception.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
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

/// Mock that returns configurable session list and session-data flag (DB parity for tests).
class MockSessionRepository implements SessionRepository {
  List<Session> sessionsForTrial = [];

  /// Matches [SessionRepository.watchTrialHasSessionData]: ratings/notes/photos/flags exist.
  bool trialHasSessionData = false;

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      List.from(sessionsForTrial);

  @override
  Future<List<Session>> getAllActiveSessions() async =>
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
  Future<void> updateSessionCropStageBbch(int sessionId, int? cropStageBbch) async {}

  @override
  Future<void> updateSessionCropInjury(int sessionId, {required String status, String? notes, String? photoIds}) async {}

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
    int? cropStageBbch,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> closeSession(int sessionId,
      {String? raterName, int? closedByUserId}) async {}

  @override
  Future<Session> startPlannedSession(int sessionId,
          {String? raterName, int? startedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async => [];

  @override
  Future<bool> isAssessmentInSession(int assessmentId, int sessionId) async =>
      false;

  @override
  Future<Session?> getSessionById(int sessionId) async => null;

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}

  @override
  Future<void> softDeleteSession(int sessionId,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Session>> getDeletedSessionsForTrial(int trialId) async => [];

  @override
  Future<List<Session>> getAllDeletedSessions() async => [];

  @override
  Future<Session?> getDeletedSessionById(int id) async => null;

  @override
  Stream<bool> watchTrialHasSessionData(int trialId) =>
      Stream.value(trialHasSessionData);

  @override
  Future<SessionRestoreResult> restoreSession(int sessionId,
          {String? restoredBy, int? restoredByUserId}) async =>
      SessionRestoreResult.failure('Not implemented');

  @override
  Future<int?> resolveSessionIdForRatingShell(Trial trial) async => null;

  @override
  Future<int> deduplicateSessionAssessments(int sessionId) async => 0;

  @override
  Future<int> deduplicateSessionAssessmentsForTrial(int trialId) async => 0;

  @override
  Future<Map<int, DateTime>> getLatestSessionStartedAtByTrial() async => {};
}

class MockAssignmentIntegrity implements AssignmentIntegrityChecks {
  @override
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  }) async {}


  @override
  Future<void> assertTreatmentBelongsToTrial({
    required int treatmentId,
    required int trialId,
  }) async {}
}

Trial _trial({String status = kTrialStatusDraft, String? workspaceType}) =>
    Trial(
      id: 1,
      name: 'Test Trial',
      status: status,
      workspaceType: workspaceType ?? 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      crop: null,
      location: null,
      season: null,
      isDeleted: false,
      isArmLinked: false,
    );

Trial _trialArmLinkedDraft() => Trial(
      id: 1,
      name: 'Test Trial',
      status: kTrialStatusDraft,
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      crop: null,
      location: null,
      season: null,
      isDeleted: false,
      isArmLinked: true,
    );

void main() {
  late UpdatePlotAssignmentUseCase useCase;
  late MockAssignmentRepository mockRepo;
  late MockSessionRepository mockSessionRepo;

  setUp(() {
    mockRepo = MockAssignmentRepository();
    mockSessionRepo = MockSessionRepository();
    useCase = UpdatePlotAssignmentUseCase(
      mockRepo,
      mockSessionRepo,
      MockAssignmentIntegrity(),
    );
  });

  group('UpdatePlotAssignmentUseCase — updateOne', () {
    test('SUCCESS: assigns treatment on standalone active trial without session data',
        () async {
      mockSessionRepo.trialHasSessionData = false;
      final result = await useCase.updateOne(
        trial: _trial(
          status: kTrialStatusActive,
          workspaceType: 'standalone',
        ),
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
        trial: _trial(),
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

    test('LOCK: rejects assignment when efficacy trial is active', () async {
      mockSessionRepo.trialHasSessionData = false;
      final result = await useCase.updateOne(
        trial: _trial(status: kTrialStatusActive),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(mockRepo.upserted, isEmpty);
    });

    test(
        'LOCK: rejects assignment when standalone active trial has session data',
        () async {
      mockSessionRepo.trialHasSessionData = true;
      final result = await useCase.updateOne(
        trial: _trial(
          status: kTrialStatusActive,
          workspaceType: 'standalone',
        ),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(
        result.errorMessage,
        kStructureLockedDataCollectionStartedUserMessage,
      );
      expect(mockRepo.upserted, isEmpty);
    });

    test('LOCK: ARM-linked draft returns ARM protocol message', () async {
      final result = await useCase.updateOne(
        trial: _trialArmLinkedDraft(),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, kArmProtocolStructureLockMessage);
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

    test('INTEGRITY: plot check failure returns message and skips upsert',
        () async {
      final integrity = _ThrowingAssignmentIntegrity(
        plotMessage: 'Plot wrong trial.',
        plotCode: 'plot_wrong_trial',
      );
      final uc = UpdatePlotAssignmentUseCase(
        mockRepo,
        mockSessionRepo,
        integrity,
      );
      final result = await uc.updateOne(
        trial: _trial(),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, 'Plot wrong trial.');
      expect(mockRepo.upserted, isEmpty);
    });

    test('INTEGRITY: treatment check failure returns message and skips upsert',
        () async {
      final integrity = _ThrowingAssignmentIntegrity(
        treatmentMessage: 'Treatment invalid.',
        treatmentCode: 'treatment_not_found_wrong_trial_or_deleted',
      );
      final uc = UpdatePlotAssignmentUseCase(
        mockRepo,
        mockSessionRepo,
        integrity,
      );
      final result = await uc.updateOne(
        trial: _trial(),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, 'Treatment invalid.');
      expect(mockRepo.upserted, isEmpty);
    });

    test('LOCK: rejects when trial has session data (assignments fixed)', () async {
      mockSessionRepo.trialHasSessionData = true;
      final result = await useCase.updateOne(
        trial: _trial(status: 'draft'),
        plotPk: 10,
        treatmentId: 5,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('cannot be changed'));
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

    test('LOCK: rejects bulk assignment on efficacy active trial', () async {
      mockSessionRepo.trialHasSessionData = false;
      final result = await useCase.updateBulk(
        trial: _trial(status: kTrialStatusActive),
        plotPkToTreatmentId: {1: 10, 2: 20},
      );
      expect(result.success, false);
      expect(mockRepo.upserted, isEmpty);
    });

    test('LOCK: ARM-linked draft bulk returns ARM protocol message', () async {
      final result = await useCase.updateBulk(
        trial: _trialArmLinkedDraft(),
        plotPkToTreatmentId: {1: 10, 2: 20},
      );
      expect(result.success, false);
      expect(result.errorMessage, kArmProtocolStructureLockMessage);
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

    test('INTEGRITY: bulk fails entirely if any plot check fails', () async {
      final integrity = _ThrowingAssignmentIntegrity(
        plotMessage: 'Plot missing.',
        plotCode: 'plot_not_found_or_deleted',
        failPlotPk: 2,
        trialId: 1,
      );
      final uc = UpdatePlotAssignmentUseCase(
        mockRepo,
        mockSessionRepo,
        integrity,
      );
      final result = await uc.updateBulk(
        trial: _trial(),
        plotPkToTreatmentId: {1: 10, 2: 20, 3: 20},
      );
      expect(result.success, false);
      expect(result.errorMessage, 'Plot missing.');
      expect(mockRepo.upserted, isEmpty);
    });

    test('INTEGRITY: bulk fails entirely if any treatment check fails',
        () async {
      final integrity = _ThrowingAssignmentIntegrity(
        treatmentMessage: 'Bad treatment.',
        treatmentCode: 'treatment_not_found_wrong_trial_or_deleted',
        failTreatmentId: 20,
        trialId: 1,
      );
      final uc = UpdatePlotAssignmentUseCase(
        mockRepo,
        mockSessionRepo,
        integrity,
      );
      final result = await uc.updateBulk(
        trial: _trial(),
        plotPkToTreatmentId: {1: 10, 2: 20, 3: 20},
      );
      expect(result.success, false);
      expect(result.errorMessage, 'Bad treatment.');
      expect(mockRepo.upserted, isEmpty);
    });
  });
}

class _ThrowingAssignmentIntegrity implements AssignmentIntegrityChecks {
  _ThrowingAssignmentIntegrity({
    this.plotMessage,
    this.plotCode,
    this.treatmentMessage,
    this.treatmentCode,
    this.failPlotPk,
    this.failTreatmentId,
    this.trialId,
  });

  final String? plotMessage;
  final String? plotCode;
  final String? treatmentMessage;
  final String? treatmentCode;
  final int? failPlotPk;
  final int? failTreatmentId;
  final int? trialId;

  @override
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  }) async {
    if (plotMessage != null &&
        (failPlotPk == null || failPlotPk == plotPk) &&
        (this.trialId == null || this.trialId == trialId)) {
      throw RatingIntegrityException(plotMessage!, code: plotCode ?? 'test');
    }
  }

  @override
  Future<void> assertTreatmentBelongsToTrial({
    required int treatmentId,
    required int trialId,
  }) async {
    if (treatmentMessage != null &&
        (failTreatmentId == null || failTreatmentId == treatmentId) &&
        (this.trialId == null || this.trialId == trialId)) {
      throw RatingIntegrityException(treatmentMessage!,
          code: treatmentCode ?? 'test');
    }
  }
}
