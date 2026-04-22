import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/trials/usecases/update_treatment_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

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
    int? performedByUserId,
  }) async {
    updateCalled = true;
  }
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
    final trialId =
        await TrialRepository(db).createTrial(name: 'ARM', workspaceType: 'efficacy');
    await upsertArmTrialMetadataForTest(db, trialId: trialId, isArmLinked: true);
    final trial = await TrialRepository(db).getTrialById(trialId);
    final repo = _NoopTreatmentRepository(db);
    final uc = UpdateTreatmentUseCase(db, repo);
    final r = await uc.execute(
      trial: trial!,
      treatmentId: 99,
      code: 'C1',
      name: 'N1',
    );
    expect(r.success, false);
    expect(r.errorMessage, getArmProtocolLockMessage());
    expect(repo.updateCalled, false);
  });
}
