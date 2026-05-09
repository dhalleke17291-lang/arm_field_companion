import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/mode_c_revelation_model.dart';
import 'package:arm_field_companion/domain/trial_cognition/regulatory_context_value.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_intent_inferrer.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrialPurposeRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TrialPurposeRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  group('updateKnownInterpretationFactors', () {
    test('creates initial purpose row when none exists', () async {
      final trialId = await makeTrial();
      final json = InterpretationFactorsCodec.serialize([]);

      await expectLater(
        repo.updateKnownInterpretationFactors(trialId, json),
        completes,
      );

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row, isNotNull);
      expect(row!.knownInterpretationFactors, json);
    });

    test('writes JSON string to column', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);

      final json = InterpretationFactorsCodec.serialize(
        ['drought_stress', 'frost_risk'],
      );
      await repo.updateKnownInterpretationFactors(trialId, json);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.knownInterpretationFactors, json);
      final result = InterpretationFactorsCodec.parse(row.knownInterpretationFactors);
      expect(result!.selectedKeys, containsAll(['drought_stress', 'frost_risk']));
    });

    test('writes empty array (none selected)', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);

      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize([]));

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.knownInterpretationFactors, '[]');
    });

    test('does not touch regulatory_context', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        regulatoryContext: RegulatoryContextValue.registration,
      );

      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize(['drought_stress']));

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.regulatoryContext, RegulatoryContextValue.registration,
          reason: 'updateKnownInterpretationFactors must not touch regulatory_context');
    });

    test('does not touch trial_purpose', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        trialPurpose: 'On-farm demonstration',
      );

      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize(['atypical_season']));

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.trialPurpose, 'On-farm demonstration',
          reason: 'updateKnownInterpretationFactors must not touch trial_purpose');
    });

    test('does not clear requires_confirmation', () async {
      final trialId = await makeTrial();
      final inferred = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'standalone',
        treatments: [],
        assessments: [],
        inferenceSource: TrialPurposeSourceMode.standaloneStructure,
      ));
      await repo.createInferredTrialPurpose(
        trialId: trialId,
        inferred: inferred,
        sourceMode: TrialPurposeSourceMode.standaloneStructure,
      );

      final before = await repo.getCurrentTrialPurpose(trialId);
      expect(before!.requiresConfirmation, 1);

      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize(['spatial_gradient']));

      final after = await repo.getCurrentTrialPurpose(trialId);
      expect(after!.requiresConfirmation, 1,
          reason: 'updateKnownInterpretationFactors must not clear requiresConfirmation');
    });

    test('targets only the non-superseded row', () async {
      final trialId = await makeTrial();
      final v1Id = await repo.createInitialTrialPurpose(trialId: trialId);

      final v2Id = await repo.createNewTrialPurposeVersion(
        (await repo.getCurrentTrialPurpose(trialId))!,
        TrialPurposesCompanion.insert(
          trialId: trialId,
          claimBeingTested: const Value('v2 claim'),
        ),
      );

      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize(['excessive_rainfall']));

      final active = await repo.getCurrentTrialPurpose(trialId);
      expect(active!.id, v2Id);
      expect(active.knownInterpretationFactors, isNotNull);

      final v1 = await (db.select(db.trialPurposes)
            ..where((p) => p.id.equals(v1Id)))
          .getSingleOrNull();
      expect(v1!.knownInterpretationFactors, isNull,
          reason: 'superseded row must not be touched');
    });

    test('can be set to null (clear answered state)', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);
      await repo.updateKnownInterpretationFactors(
          trialId, InterpretationFactorsCodec.serialize(['frost_risk']));

      await repo.updateKnownInterpretationFactors(trialId, null);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.knownInterpretationFactors, isNull);
    });
  });
}
