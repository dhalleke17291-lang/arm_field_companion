import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/trials/usecases/create_trial_usecase.dart';
import 'package:arm_field_companion/core/database/app_database.dart';

class MockTrialRepository implements TrialRepository {
  final List<Trial> _trials = [];

  @override
  Future<Trial?> getTrialById(int id) async {
    return _trials.where((t) => t.id == id).firstOrNull;
  }

  @override
  Future<int> createTrial({
    required String name,
    String? crop,
    String? location,
    String? season,
    String workspaceType = 'efficacy',
  }) async {
    final existing = _trials.where((t) => t.name == name).firstOrNull;
    if (existing != null) throw DuplicateTrialException(name);

    final trial = Trial(
      id: _trials.length + 1,
      name: name,
      crop: crop,
      location: location,
      season: season,
      status: 'active',
      workspaceType: workspaceType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
    );
    _trials.add(trial);
    return trial.id;
  }

  @override
  Future<bool> updateTrial(Trial trial) async => true;

  @override
  Future<int> updateTrialSetup(int trialId, TrialsCompanion companion) async =>
      0;

  @override
  Future<bool> updateTrialStatus(int trialId, String status) async => true;

  @override
  Future<TrialSummary> getTrialSummary(int trialId) async {
    final trial = await getTrialById(trialId);
    if (trial == null) throw TrialNotFoundException(trialId);
    return TrialSummary(
      trial: trial,
      plotCount: 0,
      treatmentCount: 0,
      assessmentCount: 0,
    );
  }

  @override
  Future<void> softDeleteTrial(int trialId,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Trial>> getDeletedTrials() async => [];

  @override
  Future<Trial?> getDeletedTrialById(int id) async => null;

  @override
  Future<TrialRestoreResult> restoreTrial(int trialId,
          {String? restoredBy, int? restoredByUserId}) async =>
      TrialRestoreResult.ok();

  @override
  Stream<List<Trial>> watchAllTrials() => Stream.value(_trials);
}

void main() {
  late CreateTrialUseCase useCase;
  late MockTrialRepository mockRepo;

  setUp(() {
    mockRepo = MockTrialRepository();
    useCase = CreateTrialUseCase(mockRepo);
  });

  group('CreateTrialUseCase — Invariants', () {
    test('SUCCESS: creates trial with valid name', () async {
      final result = await useCase.execute(const CreateTrialInput(
        name: 'Wheat Trial 2026',
        crop: 'Wheat',
        location: 'Field A',
        season: '2026',
      ));

      expect(result.success, true);
      expect(result.trial?.name, 'Wheat Trial 2026');
    });

    test('INVARIANT: duplicate trial name rejected', () async {
      await useCase.execute(const CreateTrialInput(name: 'Wheat Trial 2026'));

      final result = await useCase.execute(const CreateTrialInput(
        name: 'Wheat Trial 2026',
      ));

      expect(result.success, false);
      expect(result.errorMessage, contains('already exists'));
    });

    test('INVARIANT: empty trial name rejected', () async {
      final result = await useCase.execute(const CreateTrialInput(name: ''));

      expect(result.success, false);
      expect(result.errorMessage, contains('must not be empty'));
    });

    test('INVARIANT: whitespace-only name rejected', () async {
      final result = await useCase.execute(const CreateTrialInput(name: '   '));

      expect(result.success, false);
      expect(result.errorMessage, contains('must not be empty'));
    });

    test('SUCCESS: name is trimmed before saving', () async {
      final result = await useCase.execute(const CreateTrialInput(
        name: '  Canola Trial  ',
      ));

      expect(result.success, true);
      expect(result.trial?.name, 'Canola Trial');
    });
  });
}
