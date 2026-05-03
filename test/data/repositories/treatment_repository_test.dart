import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

void main() {
  late AppDatabase db;
  late TreatmentRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TreatmentRepository(db, AssignmentRepository(db));
    trialRepo = TrialRepository(db);
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

  group('getTreatmentsForTrial', () {
    test('returns empty list for trial with no treatments', () async {
      final trialId = await createTrial();
      final result = await repo.getTreatmentsForTrial(trialId);
      expect(result, isEmpty);
    });

    test('returns only non-deleted treatments ordered by code', () async {
      final trialId = await createTrial();
      await repo.insertTreatment(trialId: trialId, code: 'B', name: 'Beta');
      final idA =
          await repo.insertTreatment(trialId: trialId, code: 'A', name: 'Alpha');
      await repo.insertTreatment(trialId: trialId, code: 'C', name: 'Charlie');
      await repo.softDeleteTreatment(idA);

      final result = await repo.getTreatmentsForTrial(trialId);
      expect(result.length, 2);
      expect(result[0].code, 'B');
      expect(result[1].code, 'C');
    });
  });

  group('getTreatmentById', () {
    test('returns treatment by id', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final t = await repo.getTreatmentById(id);
      expect(t, isNotNull);
      expect(t!.code, '1');
      expect(t.name, 'T1');
    });

    test('returns null for non-existent id', () async {
      final t = await repo.getTreatmentById(99999);
      expect(t, isNull);
    });

    test('returns null for soft-deleted treatment', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await repo.softDeleteTreatment(id);
      final t = await repo.getTreatmentById(id);
      expect(t, isNull);
    });
  });

  group('getTreatmentForTrial', () {
    test('returns treatment matching id and trial', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final t = await repo.getTreatmentForTrial(id, trialId);
      expect(t, isNotNull);
      expect(t!.id, id);
    });

    test('returns null when treatment belongs to different trial', () async {
      final trial1 = await createTrial();
      final trial2 = await createTrial();
      final id = await repo.insertTreatment(
          trialId: trial1, code: '1', name: 'T1');
      final t = await repo.getTreatmentForTrial(id, trial2);
      expect(t, isNull);
    });

    test('returns null for soft-deleted treatment', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await repo.softDeleteTreatment(id);
      final t = await repo.getTreatmentForTrial(id, trialId);
      expect(t, isNull);
    });
  });

  group('insertTreatment', () {
    test('inserts treatment with all fields', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
        trialId: trialId,
        code: 'UTC',
        name: 'Untreated Check',
        description: 'No product applied',
        treatmentType: 'CHK',
        timingCode: 'A',
        eppoCode: 'TRZAW',
      );
      final t = await repo.getTreatmentById(id);
      expect(t, isNotNull);
      expect(t!.code, 'UTC');
      expect(t.name, 'Untreated Check');
      expect(t.description, 'No product applied');
      expect(t.treatmentType, 'CHK');
      expect(t.timingCode, 'A');
      expect(t.eppoCode, 'TRZAW');
      expect(t.isDeleted, false);
    });

    test('blocks insert on ARM-linked trial', () async {
      final trialId = await createTrial();
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);
      expect(
        () => repo.insertTreatment(
            trialId: trialId, code: '1', name: 'T1'),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('updateTreatment', () {
    test('updates specified fields only', () async {
      final trialId = await createTrial();
      final id = await repo.insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'Original',
        description: 'Desc',
      );
      await repo.updateTreatment(id, name: 'Updated');
      final t = await repo.getTreatmentById(id);
      expect(t!.name, 'Updated');
      expect(t.code, '1');
      expect(t.description, 'Desc');
    });
  });

  group('softDeleteTreatment', () {
    test('marks treatment and components as deleted', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Product A',
      );

      await repo.softDeleteTreatment(trtId, deletedBy: 'test');

      // Treatment should be hidden from normal queries
      final t = await repo.getTreatmentById(trtId);
      expect(t, isNull);

      // But visible via deleted query
      final deleted = await repo.getDeletedTreatmentById(trtId);
      expect(deleted, isNotNull);
      expect(deleted!.isDeleted, true);
      expect(deleted.deletedBy, 'test');
      expect(deleted.deletedAt, isNotNull);

      // Components should also be soft-deleted
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps, isEmpty);
    });
  });

  group('restoreTreatment', () {
    test('restores soft-deleted treatment and components', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Product A',
      );
      await repo.softDeleteTreatment(trtId);

      final result = await repo.restoreTreatment(trtId);
      expect(result, TreatmentRestoreResult.restored);

      final t = await repo.getTreatmentById(trtId);
      expect(t, isNotNull);
      expect(t!.isDeleted, false);
      expect(t.deletedAt, isNull);
      expect(t.deletedBy, isNull);

      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
    });

    test('returns notFound for non-existent deleted treatment', () async {
      final result = await repo.restoreTreatment(99999);
      expect(result, TreatmentRestoreResult.notFound);
    });
  });

  group('insertComponent', () {
    test('inserts component with all fields', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Fungicide X',
        rate: 250.0,
        rateUnit: 'mL/ha',
        formulationType: 'SC',
        manufacturer: 'AgriCorp',
      );
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].id, compId);
      expect(comps[0].productName, 'Fungicide X');
      expect(comps[0].rate, 250.0);
      expect(comps[0].rateUnit, 'mL/ha');
    });

    test('blocks insert on ARM-linked trial', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);
      expect(
        () => repo.insertComponent(
          treatmentId: trtId,
          trialId: trialId,
          productName: 'Product',
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('softDeleteComponent', () {
    test('soft-deletes a single component', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final comp1 = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'A',
      );
      await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'B',
      );

      await repo.softDeleteComponent(comp1);
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].productName, 'B');
    });
  });

  group('deleteTreatment (hard delete)', () {
    test('removes treatment, components, and clears assignments', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Product',
      );

      await repo.deleteTreatment(trtId);

      final t = await repo.getTreatmentById(trtId);
      expect(t, isNull);
      final deleted = await repo.getDeletedTreatmentById(trtId);
      expect(deleted, isNull);
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps, isEmpty);
    });
  });

  group('getDeletedTreatmentsForTrial', () {
    test('returns only deleted treatments for the trial', () async {
      final trialId = await createTrial();
      await repo.insertTreatment(trialId: trialId, code: 'A', name: 'Keep');
      final delId = await repo.insertTreatment(
          trialId: trialId, code: 'B', name: 'Delete');
      await repo.softDeleteTreatment(delId);

      final deleted = await repo.getDeletedTreatmentsForTrial(trialId);
      expect(deleted.length, 1);
      expect(deleted[0].code, 'B');
    });
  });

  group('getTreatmentForPlot', () {
    test('resolves treatment via assignment', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(trialId: trialId, plotId: '101'),
          );
      // Create assignment
      await db.into(db.assignments).insert(
            AssignmentsCompanion.insert(
              trialId: trialId,
              plotId: plotPk,
              treatmentId: Value(trtId),
            ),
          );

      final t = await repo.getTreatmentForPlot(plotPk);
      expect(t, isNotNull);
      expect(t!.id, trtId);
    });

    test('falls back to plot.treatmentId when no assignment', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(
              trialId: trialId,
              plotId: '101',
              treatmentId: Value(trtId),
            ),
          );

      final t = await repo.getTreatmentForPlot(plotPk);
      expect(t, isNotNull);
      expect(t!.id, trtId);
    });

    test('returns null for soft-deleted treatment via assignment', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(trialId: trialId, plotId: '101'),
          );
      await db.into(db.assignments).insert(
            AssignmentsCompanion.insert(
              trialId: trialId,
              plotId: plotPk,
              treatmentId: Value(trtId),
            ),
          );
      await repo.softDeleteTreatment(trtId);

      final t = await repo.getTreatmentForPlot(plotPk);
      expect(t, isNull);
    });
  });

  group('TreatmentComponent audit events', () {
    test('insertComponent writes TREATMENT_COMPONENT_ADDED audit', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');

      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Fungicide X',
        rate: 250.0,
        rateUnit: 'mL/ha',
        performedBy: 'tester',
        performedByUserId: null,
      );

      final audits = await (db.select(db.auditEvents)
            ..where(
                (a) => a.eventType.equals('TREATMENT_COMPONENT_ADDED')))
          .get();
      expect(audits.length, 1);
      expect(audits[0].performedBy, 'tester');
      expect(audits[0].trialId, trialId);

      final meta = jsonDecode(audits[0].metadata!) as Map<String, dynamic>;
      expect(meta['component_id'], compId);
      expect(meta['treatment_id'], trtId);
      expect(meta['product_name'], 'Fungicide X');
      expect(meta['rate'], 250.0);
    });

    test('softDeleteComponent writes TREATMENT_COMPONENT_DELETED audit',
        () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Herbicide Y',
      );

      await repo.softDeleteComponent(
        compId,
        deletedBy: 'admin',
        deletedByUserId: null,
      );

      final audits = await (db.select(db.auditEvents)
            ..where(
                (a) => a.eventType.equals('TREATMENT_COMPONENT_DELETED')))
          .get();
      expect(audits.length, 1);
      expect(audits[0].performedBy, 'admin');

      final meta = jsonDecode(audits[0].metadata!) as Map<String, dynamic>;
      expect(meta['component_id'], compId);
      expect(meta['product_name'], 'Herbicide Y');
    });

    test('updateComponent writes TREATMENT_COMPONENT_UPDATED audit with diffs',
        () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Old Product',
        rate: 100.0,
        rateUnit: 'g/ha',
      );

      await repo.updateComponent(
        compId,
        productName: 'New Product',
        rate: 200.0,
        performedBy: 'editor',
      );

      // Verify the component was updated in-place
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].id, compId);
      expect(comps[0].productName, 'New Product');
      expect(comps[0].rate, 200.0);
      expect(comps[0].rateUnit, 'g/ha'); // unchanged

      // Verify audit event
      final audits = await (db.select(db.auditEvents)
            ..where(
                (a) => a.eventType.equals('TREATMENT_COMPONENT_UPDATED')))
          .get();
      expect(audits.length, 1);
      expect(audits[0].performedBy, 'editor');

      final meta = jsonDecode(audits[0].metadata!) as Map<String, dynamic>;
      expect(meta['component_id'], compId);
      final changes = (meta['changes'] as List).cast<Map<String, dynamic>>();
      expect(changes.length, 2);

      final nameChange = changes.firstWhere((c) => c['field'] == 'productName');
      expect(nameChange['old'], 'Old Product');
      expect(nameChange['new'], 'New Product');

      final rateChange = changes.firstWhere((c) => c['field'] == 'rate');
      expect(rateChange['old'], 100.0);
      expect(rateChange['new'], 200.0);
    });
  });

  // ─── pesticideCategory ─────────────────────────────────────────────────────

  group('pesticideCategory', () {
    test('11 — insertComponent saves pesticideCategory when provided', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'Roundup',
        pesticideCategory: 'herbicide',
      );
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].id, compId);
      expect(comps[0].pesticideCategory, 'herbicide');
    });

    test('12 — insertComponent saves null pesticideCategory when absent', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'ProductX',
      );
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].id, compId);
      expect(comps[0].pesticideCategory, isNull);
    });

    test('13 — updateComponent saves pesticideCategory correctly', () async {
      final trialId = await createTrial();
      final trtId = await repo.insertTreatment(
          trialId: trialId, code: '1', name: 'T1');
      final compId = await repo.insertComponent(
        treatmentId: trtId,
        trialId: trialId,
        productName: 'ProductY',
      );
      await repo.updateComponent(
        compId,
        pesticideCategory: 'fungicide',
        performedBy: 'tester',
      );
      final comps = await repo.getComponentsForTreatment(trtId);
      expect(comps.length, 1);
      expect(comps[0].pesticideCategory, 'fungicide');
    });
  });
}
