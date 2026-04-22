import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_plot_insert_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/arm_trial_metadata_test_utils.dart';

class _SpyPlotRepository extends PlotRepository {
  _SpyPlotRepository(super.db);

  int insertBulkCalls = 0;

  @override
  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async {
    insertBulkCalls++;
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

  test('draft non-ARM editable trial passes through to insertPlotsBulk', () async {
    final trialRepo = TrialRepository(db);
    final trialId =
        await trialRepo.createTrial(name: 'Draft', workspaceType: 'efficacy');
    final spy = _SpyPlotRepository(db);
    final service = ArmPlotInsertService(db, spy, trialRepo);

    await service.insertPlotsForArmImport(
      trialId: trialId,
      plots: [
        PlotsCompanion.insert(trialId: trialId, plotId: '101'),
      ],
    );

    expect(spy.insertBulkCalls, 1);
  });

  test('standalone active trial without session data passes through', () async {
    final trialRepo = TrialRepository(db);
    final trialId = await trialRepo.createTrial(
      name: 'Standalone',
      workspaceType: 'standalone',
    );
    await trialRepo.updateTrialStatus(trialId, kTrialStatusActive);

    final spy = _SpyPlotRepository(db);
    final service = ArmPlotInsertService(db, spy, trialRepo);

    await service.insertPlotsForArmImport(
      trialId: trialId,
      plots: [
        PlotsCompanion.insert(trialId: trialId, plotId: '101'),
      ],
    );

    expect(spy.insertBulkCalls, 1);
  });

  test('blocked trial throws ProtocolEditBlockedException', () async {
    final trialRepo = TrialRepository(db);
    final trialId =
        await trialRepo.createTrial(name: 'Active', workspaceType: 'efficacy');
    await trialRepo.updateTrialStatus(trialId, kTrialStatusActive);

    final spy = _SpyPlotRepository(db);
    final service = ArmPlotInsertService(db, spy, trialRepo);

    expect(
      () => service.insertPlotsForArmImport(
        trialId: trialId,
        plots: [
          PlotsCompanion.insert(trialId: trialId, plotId: '101'),
        ],
      ),
      throwsA(isA<ProtocolEditBlockedException>()),
    );
    expect(spy.insertBulkCalls, 0);
  });

  test('ARM-linked draft blocks with ARM structure message', () async {
    final trialRepo = TrialRepository(db);
    final trialId =
        await trialRepo.createTrial(name: 'ArmDraft', workspaceType: 'efficacy');
    await upsertArmTrialMetadataForTest(db,
        trialId: trialId, isArmLinked: true);

    final spy = _SpyPlotRepository(db);
    final service = ArmPlotInsertService(db, spy, trialRepo);

    expect(
      () => service.insertPlotsForArmImport(
        trialId: trialId,
        plots: [
          PlotsCompanion.insert(trialId: trialId, plotId: '101'),
        ],
      ),
      throwsA(
        isA<ProtocolEditBlockedException>().having(
          (e) => e.message,
          'message',
          kArmProtocolStructureLockMessage,
        ),
      ),
    );
    expect(spy.insertBulkCalls, 0);
  });
}
