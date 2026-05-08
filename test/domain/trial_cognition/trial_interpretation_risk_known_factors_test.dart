import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_evaluator.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TrialCoherenceDto _emptyAligned() => TrialCoherenceDto(
      coherenceState: 'aligned',
      checks: const [],
      computedAt: DateTime(2026, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  Future<void> setPurposeFactors(int trialId, String? factorsJson) =>
      purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        knownInterpretationFactors: factorsJson,
      );

  Future<TrialRiskFactorDto> siteSeasonFactor(int trialId) async {
    final dto = await computeTrialInterpretationRiskDto(
      db: db,
      trialId: trialId,
      coherenceDto: _emptyAligned(),
    );
    return dto.factors.firstWhere((f) => f.factorKey == 'known_site_season_factors');
  }

  group('known_site_season_factors risk factor', () {
    test('IRK-1: no purpose row → severity is cannot_evaluate', () async {
      final trialId = await makeTrial();
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'cannot_evaluate');
    });

    test('IRK-2: null knownInterpretationFactors → severity is cannot_evaluate',
        () async {
      final trialId = await makeTrial();
      await setPurposeFactors(trialId, null);
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'cannot_evaluate');
    });

    test('IRK-3: empty array (none selected) → severity is none', () async {
      final trialId = await makeTrial();
      await setPurposeFactors(
          trialId, InterpretationFactorsCodec.serialize([]));
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'none');
    });

    test('IRK-4: single key → severity is moderate, reason names condition',
        () async {
      final trialId = await makeTrial();
      await setPurposeFactors(
          trialId, InterpretationFactorsCodec.serialize(['drought_stress']));
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'moderate');
      expect(f.reason, contains('Drought stress this season'));
    });

    test('IRK-5: multiple keys → reason lists all conditions', () async {
      final trialId = await makeTrial();
      await setPurposeFactors(
          trialId,
          InterpretationFactorsCodec.serialize(
              ['drought_stress', 'spatial_gradient']));
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'moderate');
      expect(f.reason, contains('Drought stress this season'));
      expect(f.reason, contains('Spatial gradient in the field'));
    });

    test('IRK-6: other text included in reason', () async {
      final trialId = await makeTrial();
      await setPurposeFactors(
          trialId,
          InterpretationFactorsCodec.serialize(
            [],
            otherText: 'Hail damage on NW corner',
          ));
      final f = await siteSeasonFactor(trialId);
      expect(f.severity, 'moderate');
      expect(f.reason, contains('Hail damage on NW corner'));
    });

    test('IRK-7: factors list has exactly 6 entries', () async {
      final trialId = await makeTrial();
      final dto = await computeTrialInterpretationRiskDto(
        db: db,
        trialId: trialId,
        coherenceDto: _emptyAligned(),
      );
      expect(dto.factors.length, 6);
    });
  });
}
