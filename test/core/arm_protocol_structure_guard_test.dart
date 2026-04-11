import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_plot_insert_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _markArmLinked(AppDatabase db, int trialId) async {
  await (db.update(db.trials)..where((t) => t.id.equals(trialId))).write(
    const TrialsCompanion(isArmLinked: Value(true)),
  );
}

void main() {
  late AppDatabase db;
  late TrialRepository trialRepo;
  late TreatmentRepository treatmentRepo;
  late PlotRepository plotRepo;
  late AssignmentRepository assignmentRepo;
  late TrialAssessmentRepository trialAssessmentRepo;
  late ArmImportPersistenceRepository armImportPersistenceRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trialRepo = TrialRepository(db);
    treatmentRepo = TreatmentRepository(db);
    plotRepo = PlotRepository(db);
    assignmentRepo = AssignmentRepository(db);
    trialAssessmentRepo = TrialAssessmentRepository(db);
    armImportPersistenceRepo = ArmImportPersistenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('canEditProtocol', () {
    test('non-ARM draft trial is editable', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Draft', workspaceType: 'efficacy');
      final t = await trialRepo.getTrialById(trialId);
      expect(t, isNotNull);
      expect(canEditProtocol(t!), true);
    });

    test('ARM-linked draft trial is not editable', () async {
      final trialId =
          await trialRepo.createTrial(name: 'ArmDraft', workspaceType: 'efficacy');
      await _markArmLinked(db, trialId);
      final t = await trialRepo.getTrialById(trialId);
      expect(t, isNotNull);
      expect(canEditProtocol(t!), false);
    });

    test('non-ARM closed trial is not editable', () {
      final now = DateTime.utc(2020, 1, 1);
      final t = Trial(
        id: 1,
        name: 'Test',
        status: kTrialStatusClosed,
        workspaceType: 'efficacy',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
        isArmLinked: false,
      );
      expect(canEditProtocol(t), false);
    });

    test('getArmProtocolLockMessage matches kArmProtocolStructureLockMessage',
        () {
      expect(getArmProtocolLockMessage(), kArmProtocolStructureLockMessage);
    });
  });

  group('treatment mutations', () {
    test('updateTreatment blocked when trial becomes ARM-linked', () async {
      final trialId =
          await trialRepo.createTrial(name: 'T', workspaceType: 'efficacy');
      final tid = await treatmentRepo.insertTreatment(
        trialId: trialId,
        code: 'C1',
        name: 'N1',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => treatmentRepo.updateTreatment(tid, name: 'Blocked'),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('insertTreatment blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Ti', workspaceType: 'efficacy');
      await _markArmLinked(db, trialId);

      expect(
        () => treatmentRepo.insertTreatment(
          trialId: trialId,
          code: 'C1',
          name: 'N1',
        ),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('softDeleteTreatment blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Td', workspaceType: 'efficacy');
      final tid = await treatmentRepo.insertTreatment(
        trialId: trialId,
        code: 'C1',
        name: 'N1',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => treatmentRepo.softDeleteTreatment(tid),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('insertComponent blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'T2', workspaceType: 'efficacy');
      final tid = await treatmentRepo.insertTreatment(
        trialId: trialId,
        code: 'C1',
        name: 'N1',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => treatmentRepo.insertComponent(
          treatmentId: tid,
          trialId: trialId,
          productName: 'P',
        ),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('softDeleteComponent blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tdc', workspaceType: 'efficacy');
      final tid = await treatmentRepo.insertTreatment(
        trialId: trialId,
        code: 'C1',
        name: 'N1',
      );
      final cid = await treatmentRepo.insertComponent(
        treatmentId: tid,
        trialId: trialId,
        productName: 'P',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => treatmentRepo.softDeleteComponent(cid),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });
  });

  group('plot mutations', () {
    test('insertPlotsBulk blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tp', workspaceType: 'efficacy');
      await _markArmLinked(db, trialId);

      expect(
        () => plotRepo.insertPlotsBulk([
              PlotsCompanion.insert(trialId: trialId, plotId: '101'),
            ]),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('ArmPlotInsertService blocks bulk insert for ARM-linked trial',
        () async {
      final trialId =
          await trialRepo.createTrial(name: 'Ts', workspaceType: 'efficacy');
      await _markArmLinked(db, trialId);

      final service = ArmPlotInsertService(plotRepo, trialRepo);
      expect(
        () => service.insertPlotsForArmImport(
          trialId: trialId,
          plots: [
            PlotsCompanion.insert(trialId: trialId, plotId: '101'),
          ],
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('trial assessment mutations', () {
    test('addToTrial blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Ta', workspaceType: 'efficacy');
      await _markArmLinked(db, trialId);

      final defs = await db.select(db.assessmentDefinitions).get();
      expect(defs, isNotEmpty);
      final defId = defs.first.id;

      expect(
        () => trialAssessmentRepo.addToTrial(
          trialId: trialId,
          assessmentDefinitionId: defId,
        ),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('update blocked after trial becomes ARM-linked', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tau', workspaceType: 'efficacy');
      final defs = await db.select(db.assessmentDefinitions).get();
      final taId = await trialAssessmentRepo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defs.first.id,
      );
      await _markArmLinked(db, trialId);

      expect(
        () => trialAssessmentRepo.update(taId, displayNameOverride: 'X'),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });

    test('delete blocked after trial becomes ARM-linked', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tad', workspaceType: 'efficacy');
      final defs = await db.select(db.assessmentDefinitions).get();
      final taId = await trialAssessmentRepo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defs.first.id,
      );
      await _markArmLinked(db, trialId);

      expect(
        () => trialAssessmentRepo.delete(taId),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });
  });

  group('assignment mutations', () {
    test('upsert blocked for ARM-linked trial', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tb', workspaceType: 'efficacy');
      final trId = await treatmentRepo.insertTreatment(
        trialId: trialId,
        code: 'C1',
        name: 'N1',
      );
      final plotPk = await plotRepo.insertPlot(
        trialId: trialId,
        plotId: '101',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => assignmentRepo.upsert(
          trialId: trialId,
          plotId: plotPk,
          treatmentId: trId,
        ),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });
  });

  group('ARM import WIP persistence', () {
    test('markTrialAsArmLinked via persistence API still blocks structure insert',
        () async {
      final trialId =
          await trialRepo.createTrial(name: 'Twip', workspaceType: 'efficacy');
      await armImportPersistenceRepo.markTrialAsArmLinked(
        trialId: trialId,
        sourceFile: 'arm.csv',
        armVersion: '1',
      );

      expect(
        () => plotRepo.insertPlot(trialId: trialId, plotId: '101'),
        throwsA(
          predicate<ProtocolEditBlockedException>(
            (e) => e.message == kArmProtocolStructureLockMessage,
          ),
        ),
      );
    });
  });

  group('plot notes vs lifecycle lock', () {
    test('active non-ARM trial still allows updatePlotNotes', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Tc', workspaceType: 'efficacy');
      final plotPk = await plotRepo.insertPlot(
        trialId: trialId,
        plotId: '101',
      );
      await trialRepo.updateTrialStatus(trialId, kTrialStatusActive);

      await plotRepo.updatePlotNotes(plotPk, 'field note');
      final p = await plotRepo.getPlotByPk(plotPk);
      expect(p?.plotNotes, 'field note');
    });

    test('ARM-linked trial blocks updatePlotNotes', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Td', workspaceType: 'efficacy');
      final plotPk = await plotRepo.insertPlot(
        trialId: trialId,
        plotId: '101',
      );
      await _markArmLinked(db, trialId);

      expect(
        () => plotRepo.updatePlotNotes(plotPk, 'x'),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('non-ARM structure mutation succeeds', () {
    test('draft trial insertPlot succeeds', () async {
      final trialId =
          await trialRepo.createTrial(name: 'Ok', workspaceType: 'efficacy');
      final id = await plotRepo.insertPlot(trialId: trialId, plotId: '202');
      expect(id, greaterThan(0));
    });
  });
}
