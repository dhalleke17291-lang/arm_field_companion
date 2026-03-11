import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/features/plots/usecases/update_plot_assignment_usecase.dart';

class MockAssignmentRepository implements AssignmentRepository {
  final List<Map<String, dynamic>> _upserted = [];
  bool shouldThrow = false;

  List<Map<String, dynamic>> get upserted => _upserted;

  @override
  Future<Assignment?> getForPlot(int plotPk) async => null;

  @override
  Future<Assignment?> getForTrialAndPlot(int trialId, int plotPk) async =>
      null;

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

Trial _trial({String status = 'ACTIVE'}) => Trial(
      id: 1,
      name: 'Test Trial',
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      crop: null,
      location: null,
      season: null,
    );

void main() {
  late UpdatePlotAssignmentUseCase useCase;
  late MockAssignmentRepository mockRepo;

  setUp(() {
    mockRepo = MockAssignmentRepository();
    useCase = UpdatePlotAssignmentUseCase(mockRepo);
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
