import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/trials/usecases/update_treatment_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopTreatmentRepository extends TreatmentRepository {
  _NoopTreatmentRepository(super.db);

  bool updateCalled = false;

  @override
  Future<void> updateTreatment(
    int id, {
    String? code,
    String? name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
  }) async {
    updateCalled = true;
  }
}

Trial _armDraft() {
  final now = DateTime.utc(2020, 1, 1);
  return Trial(
    id: 1,
    name: 'ARM',
    status: kTrialStatusDraft,
    workspaceType: 'efficacy',
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    isArmLinked: true,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('ARM-linked trial blocks treatment update before repository', () async {
    final repo = _NoopTreatmentRepository(db);
    final uc = UpdateTreatmentUseCase(repo);
    final r = await uc.execute(
      trial: _armDraft(),
      treatmentId: 99,
      code: 'C1',
      name: 'N1',
    );
    expect(r.success, false);
    expect(r.errorMessage, getArmProtocolLockMessage());
    expect(repo.updateCalled, false);
  });
}
