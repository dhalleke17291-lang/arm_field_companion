import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
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

  group('updateRegulatoryContext', () {
    test('no-op when no active purpose row exists', () async {
      final trialId = await makeTrial();
      // No exception, no row created.
      await expectLater(
        repo.updateRegulatoryContext(trialId, RegulatoryContextValue.registration),
        completes,
      );
      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row, isNull);
    });

    for (final key in RegulatoryContextValue.all) {
      test('writes correct key for $key', () async {
        final trialId = await makeTrial();
        await repo.createInitialTrialPurpose(trialId: trialId);

        await repo.updateRegulatoryContext(trialId, key);

        final row = await repo.getCurrentTrialPurpose(trialId);
        expect(row!.regulatoryContext, key);
      });
    }

    test('does not touch requires_confirmation', () async {
      final trialId = await makeTrial();
      // Create an inferred row (requiresConfirmation = 1).
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

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.internalResearch);

      final after = await repo.getCurrentTrialPurpose(trialId);
      expect(after!.requiresConfirmation, 1,
          reason: 'updateRegulatoryContext must not clear requiresConfirmation');
      expect(after.regulatoryContext, RegulatoryContextValue.internalResearch);
    });

    test('does not touch inferred_fields_json', () async {
      final trialId = await makeTrial();
      final inferred = inferTrialPurpose(const TrialInferenceInput(
        workspaceType: 'efficacy',
        treatments: [
          TreatmentInferenceData(id: 1, name: 'Product A', code: 'PA'),
          TreatmentInferenceData(id: 2, name: 'UTC', code: 'UTC'),
        ],
        assessments: [],
        inferenceSource: TrialPurposeSourceMode.armStructure,
      ));
      await repo.createInferredTrialPurpose(
        trialId: trialId,
        inferred: inferred,
        sourceMode: TrialPurposeSourceMode.armStructure,
      );

      final before = await repo.getCurrentTrialPurpose(trialId);
      final originalJson = before!.inferredFieldsJson;
      expect(originalJson, isNotNull);

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.registration);

      final after = await repo.getCurrentTrialPurpose(trialId);
      expect(after!.inferredFieldsJson, originalJson,
          reason: 'updateRegulatoryContext must not touch inferredFieldsJson');
    });

    test('does not touch claim_being_tested or primary_endpoint', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Compare A vs B',
        primaryEndpoint: 'Disease control %',
      );

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.academic);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.claimBeingTested, 'Compare A vs B');
      expect(row.primaryEndpoint, 'Disease control %');
      expect(row.regulatoryContext, RegulatoryContextValue.academic);
    });

    test('can overwrite a previously written regulatory_context', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        regulatoryContext: RegulatoryContextValue.registration,
      );

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.internalResearch);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.regulatoryContext, RegulatoryContextValue.internalResearch);
    });

    test('only updates the non-superseded row', () async {
      final trialId = await makeTrial();
      final v1Id = await repo.createInitialTrialPurpose(trialId: trialId);
      // Supersede v1 by creating v2.
      final v2Id = await repo.createNewTrialPurposeVersion(
        (await repo.getCurrentTrialPurpose(trialId))!,
        TrialPurposesCompanion.insert(
          trialId: trialId,
          claimBeingTested: const Value('v2 claim'),
        ),
      );

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.undetermined);

      final active = await repo.getCurrentTrialPurpose(trialId);
      expect(active!.id, v2Id);
      expect(active.regulatoryContext, RegulatoryContextValue.undetermined);

      // v1 should remain superseded and untouched.
      final v1 = await (db.select(db.trialPurposes)
            ..where((p) => p.id.equals(v1Id)))
          .getSingleOrNull();
      expect(v1!.regulatoryContext, isNull);
    });
  });

  group('field independence — regulatory_context vs trial_purpose', () {
    test('updateRegulatoryContext does not touch trial_purpose', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        trialPurpose: 'Efficacy and safety evaluation',
        regulatoryContext: RegulatoryContextValue.registration,
      );

      await repo.updateRegulatoryContext(
          trialId, RegulatoryContextValue.academic);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.trialPurpose, 'Efficacy and safety evaluation',
          reason: 'updateRegulatoryContext must not clear trial_purpose');
      expect(row.regulatoryContext, RegulatoryContextValue.academic);
    });

    test('createInitialTrialPurpose stores regulatory_context and trial_purpose independently',
        () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        trialPurpose: 'On-farm demo',
        regulatoryContext: RegulatoryContextValue.academic,
      );

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.trialPurpose, 'On-farm demo');
      expect(row.regulatoryContext, RegulatoryContextValue.academic,
          reason: 'trial_purpose and regulatory_context are separate columns');
    });

    test('regulatory_context key is never a display label (no mirroring)', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        regulatoryContext: RegulatoryContextValue.internalResearch,
      );

      final row = await repo.getCurrentTrialPurpose(trialId);
      // If label mirroring occurred the column would contain the display label.
      expect(row!.regulatoryContext, RegulatoryContextValue.internalResearch,
          reason: 'column must hold the key, not the display label');
      expect(row.regulatoryContext,
          isNot('Internal research / product positioning'));
    });
  });

  group('confirm flow writes regulatory_context', () {
    test('createInitialTrialPurpose accepts regulatory_context', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        regulatoryContext: RegulatoryContextValue.registration,
        claimBeingTested: 'Efficacy of Product X',
      );
      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.regulatoryContext, RegulatoryContextValue.registration);
    });

    test('createNewTrialPurposeVersion carries regulatory_context', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);
      final existing = await repo.getCurrentTrialPurpose(trialId);

      await repo.createNewTrialPurposeVersion(
        existing!,
        TrialPurposesCompanion.insert(
          trialId: trialId,
          regulatoryContext:
              const Value(RegulatoryContextValue.internalResearch),
          claimBeingTested: const Value('Market positioning study'),
        ),
      );

      final updated = await repo.getCurrentTrialPurpose(trialId);
      expect(updated!.regulatoryContext, RegulatoryContextValue.internalResearch);
    });

    test('confirmTrialPurpose does not clear regulatory_context', () async {
      final trialId = await makeTrial();
      final id = await repo.createInitialTrialPurpose(
        trialId: trialId,
        regulatoryContext: RegulatoryContextValue.academic,
        claimBeingTested: 'On-farm demonstration',
        primaryEndpoint: 'Yield t/ha',
        treatmentRoleSummary: 'A=test, B=check',
        trialPurpose: 'Academic / extension / on-farm',
      );
      await repo.confirmTrialPurpose(id);

      final row = await repo.getCurrentTrialPurpose(trialId);
      expect(row!.regulatoryContext, RegulatoryContextValue.academic);
      expect(row.status, 'confirmed');
    });
  });

  group('legacy display fallback', () {
    test('RegulatoryContextValue.labelFor returns null for legacy free-text', () {
      expect(
        RegulatoryContextValue.labelFor('PMRA or regulatory submission likely'),
        isNull,
      );
      expect(
        RegulatoryContextValue.labelFor('Internal research or market positioning'),
        isNull,
      );
    });

    test('RegulatoryContextValue.labelFor returns label for structured keys', () {
      expect(
        RegulatoryContextValue.labelFor(RegulatoryContextValue.registration),
        'Registration / regulatory submission',
      );
    });
  });
}
