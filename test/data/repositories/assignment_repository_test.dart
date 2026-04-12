import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AssignmentRepository repo;
  late TrialRepository trialRepo;
  late TreatmentRepository trtRepo;
  late PlotRepository plotRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AssignmentRepository(db);
    trialRepo = TrialRepository(db);
    trtRepo = TreatmentRepository(db);
    plotRepo = PlotRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTrial({String workspaceType = 'efficacy'}) async {
    return trialRepo.createTrial(
      name: 'Trial ${DateTime.now().microsecondsSinceEpoch}',
      workspaceType: workspaceType,
    );
  }

  group('upsert', () {
    test('inserts new assignment and writes audit event', () async {
      final trialId = await createTrial();
      final trtId = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');

      await repo.upsert(
        trialId: trialId,
        plotId: plotPk,
        treatmentId: trtId,
        assignmentSource: 'manual',
      );

      final a = await repo.getForPlot(plotPk);
      expect(a, isNotNull);
      expect(a!.treatmentId, trtId);
      expect(a.trialId, trialId);

      // Audit event written
      final audits = await (db.select(db.auditEvents)
            ..where((e) => e.eventType.equals('TREATMENT_ASSIGNED')))
          .get();
      expect(audits.length, 1);
    });

    test('updates existing assignment on second upsert', () async {
      final trialId = await createTrial();
      final trt1 = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final trt2 = await trtRepo.insertTreatment(
          trialId: trialId, code: '2', name: 'T2');
      final plotPk = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');

      await repo.upsert(
          trialId: trialId, plotId: plotPk, treatmentId: trt1);
      await repo.upsert(
          trialId: trialId, plotId: plotPk, treatmentId: trt2);

      final a = await repo.getForPlot(plotPk);
      expect(a!.treatmentId, trt2);
    });

    test('blocks upsert on ARM-linked trial', () async {
      final trialId = await createTrial();
      final plotPk = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');
      await (db.update(db.trials)..where((t) => t.id.equals(trialId)))
          .write(const TrialsCompanion(isArmLinked: Value(true)));

      expect(
        () => repo.upsert(trialId: trialId, plotId: plotPk, treatmentId: 1),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('upsertBulk', () {
    test('assigns multiple plots in one call', () async {
      final trialId = await createTrial();
      final trt1 = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final trt2 = await trtRepo.insertTreatment(
          trialId: trialId, code: '2', name: 'T2');
      final p1 = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');
      final p2 = await plotRepo.insertPlot(
          trialId: trialId, plotId: '102');

      await repo.upsertBulk(
        trialId: trialId,
        plotPkToTreatmentId: {p1: trt1, p2: trt2},
        assignmentSource: 'bulk',
      );

      final a1 = await repo.getForPlot(p1);
      final a2 = await repo.getForPlot(p2);
      expect(a1!.treatmentId, trt1);
      expect(a2!.treatmentId, trt2);

      // Bulk audit event
      final audits = await (db.select(db.auditEvents)
            ..where((e) => e.eventType.equals('TREATMENT_ASSIGNED_BULK')))
          .get();
      expect(audits.length, 1);
    });
  });

  group('getForTrial', () {
    test('returns all assignments for trial', () async {
      final trialId = await createTrial();
      final trt = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final p1 = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');
      final p2 = await plotRepo.insertPlot(
          trialId: trialId, plotId: '102');

      await repo.upsert(trialId: trialId, plotId: p1, treatmentId: trt);
      await repo.upsert(trialId: trialId, plotId: p2, treatmentId: trt);

      final all = await repo.getForTrial(trialId);
      expect(all.length, 2);
    });

    test('returns empty list for trial with no assignments', () async {
      final trialId = await createTrial();
      final all = await repo.getForTrial(trialId);
      expect(all, isEmpty);
    });
  });

  group('getForTrialAndPlot', () {
    test('returns specific assignment', () async {
      final trialId = await createTrial();
      final trt = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');

      await repo.upsert(trialId: trialId, plotId: plotPk, treatmentId: trt);

      final a = await repo.getForTrialAndPlot(trialId, plotPk);
      expect(a, isNotNull);
      expect(a!.treatmentId, trt);
    });

    test('returns null for non-existent combination', () async {
      final trialId = await createTrial();
      final a = await repo.getForTrialAndPlot(trialId, 99999);
      expect(a, isNull);
    });
  });

  group('unassign treatment', () {
    test('upsert with null treatmentId clears assignment', () async {
      final trialId = await createTrial();
      final trt = await trtRepo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await plotRepo.insertPlot(
          trialId: trialId, plotId: '101');

      await repo.upsert(trialId: trialId, plotId: plotPk, treatmentId: trt);
      await repo.upsert(trialId: trialId, plotId: plotPk, treatmentId: null);

      final a = await repo.getForPlot(plotPk);
      expect(a!.treatmentId, isNull);
    });
  });
}
