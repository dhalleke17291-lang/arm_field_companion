import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

void main() {
  late AppDatabase db;
  late TrialAssessmentRepository repo;
  late TrialRepository trialRepo;
  late AssessmentDefinitionRepository defRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TrialAssessmentRepository(db);
    trialRepo = TrialRepository(db);
    defRepo = AssessmentDefinitionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTrial() async {
    return trialRepo.createTrial(
      name: 'Trial ${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<int> getSystemDefId() async {
    final def = await defRepo.getByCode('CROP_INJURY');
    return def!.id;
  }

  group('addToTrial', () {
    test('adds assessment definition to trial', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();

      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
        sortOrder: 0,
      );
      expect(taId, greaterThan(0));

      final list = await repo.getForTrial(trialId);
      expect(list.length, 1);
      expect(list[0].assessmentDefinitionId, defId);
    });

    test('blocks add on ARM-linked trial', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);

      expect(
        () => repo.addToTrial(
          trialId: trialId,
          assessmentDefinitionId: defId,
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('getForTrial', () {
    test('returns assessments ordered by sortOrder then id', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final def2 = await defRepo.insertCustom(
        code: 'CUSTOM_SORT',
        name: 'Custom Sort',
        category: 'custom',
      );

      await repo.addToTrial(
          trialId: trialId,
          assessmentDefinitionId: def2,
          sortOrder: 1);
      await repo.addToTrial(
          trialId: trialId,
          assessmentDefinitionId: defId,
          sortOrder: 0);

      final list = await repo.getForTrial(trialId);
      expect(list.length, 2);
      expect(list[0].assessmentDefinitionId, defId);
      expect(list[1].assessmentDefinitionId, def2);
    });
  });

  group('getById', () {
    test('returns trial assessment by id', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
      );

      final ta = await repo.getById(taId);
      expect(ta, isNotNull);
      expect(ta!.trialId, trialId);
    });

    test('returns null for non-existent id', () async {
      final ta = await repo.getById(99999);
      expect(ta, isNull);
    });
  });

  group('hasDefinitionForTrial', () {
    test('returns true when definition already added', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      await repo.addToTrial(
          trialId: trialId, assessmentDefinitionId: defId);

      final has = await repo.hasDefinitionForTrial(trialId, defId);
      expect(has, true);
    });

    test('returns false when definition not added', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();

      final has = await repo.hasDefinitionForTrial(trialId, defId);
      expect(has, false);
    });
  });

  group('update', () {
    test('updates trial-specific settings', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
        sortOrder: 0,
      );

      await repo.update(taId,
          displayNameOverride: 'Renamed', sortOrder: 5, isActive: false);

      final ta = await repo.getById(taId);
      expect(ta!.displayNameOverride, 'Renamed');
      expect(ta.sortOrder, 5);
      expect(ta.isActive, false);
    });

    test('blocks update on ARM-linked trial', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
      );
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);

      expect(
        () => repo.update(taId, displayNameOverride: 'X'),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('delete', () {
    test('removes trial assessment', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
      );

      await repo.delete(taId);

      final ta = await repo.getById(taId);
      expect(ta, isNull);
    });

    test('blocks delete on ARM-linked trial', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
      );
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);

      expect(
        () => repo.delete(taId),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });
  });

  group('getOrCreateLegacyAssessmentIdsForTrialAssessments', () {
    test('creates legacy assessment rows and returns ids', () async {
      final trialId = await createTrial();
      final defId = await getSystemDefId();
      final taId = await repo.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
      );

      final ids = await repo
          .getOrCreateLegacyAssessmentIdsForTrialAssessments(trialId, [taId]);
      expect(ids.length, 1);
      expect(ids[0], greaterThan(0));

      // Second call returns same ids (idempotent)
      final ids2 = await repo
          .getOrCreateLegacyAssessmentIdsForTrialAssessments(trialId, [taId]);
      expect(ids2, ids);
    });
  });
}
