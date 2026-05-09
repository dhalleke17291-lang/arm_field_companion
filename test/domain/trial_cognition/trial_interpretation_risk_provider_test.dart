import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;
  late SignalRepository signalRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
    signalRepo = SignalRepository.attach(db);
  });

  tearDown(() async => db.close());

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<TrialCoherenceDto> coherence(int trialId) =>
      computeTrialCoherenceDto(db: db, trialId: trialId, signalRepo: signalRepo);

  Future<TrialInterpretationRiskDto> risk(
    int trialId, {
    EnvironmentalSeasonSummaryDto? environmentalSummary,
  }) async {
    final coherenceDto = await coherence(trialId);
    return computeTrialInterpretationRiskDto(
      db: db,
      trialId: trialId,
      coherenceDto: coherenceDto,
      environmentalSummary: environmentalSummary,
    );
  }

  TrialRiskFactorDto factor(TrialInterpretationRiskDto dto, String key) =>
      dto.factors.firstWhere((f) => f.factorKey == key);

  Future<int> makeTrial({String? crop}) => trialRepo.createTrial(
      name: 'T${DateTime.now().microsecondsSinceEpoch}', crop: crop);

  Future<int> makePurpose(
    int trialId, {
    String? primaryEndpoint,
    String? treatmentRoleSummary,
  }) =>
      purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        primaryEndpoint: primaryEndpoint,
        treatmentRoleSummary: treatmentRoleSummary,
      );

  Future<int> makeAssessment(int trialId, String name) =>
      db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: name),
          );

  Future<int> makeTreatment(int trialId, {String code = 'TRT_A'}) =>
      db.into(db.treatments).insert(TreatmentsCompanion.insert(
            trialId: trialId,
            code: code,
            name: 'Treatment $code',
          ));

  Future<int> makeSession(int trialId) =>
      db.into(db.sessions).insert(SessionsCompanion.insert(
            trialId: trialId,
            name: 'Session',
            sessionDateLocal: '2026-04-01',
          ));

  Future<int> makePlot(int trialId, {int? treatmentId}) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: 'P${DateTime.now().microsecondsSinceEpoch}',
            rep: const Value(1),
            treatmentId: Value(treatmentId),
          ));

  Future<void> makeRating(
    int trialId,
    int sessionId,
    int plotPk,
    int assessmentId,
    double value,
  ) =>
      db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            isCurrent: const Value(true),
            isDeleted: const Value(false),
            resultStatus: const Value('RECORDED'),
            numericValue: Value(value),
          ));

  Future<void> setPurposeKnownFactors(int trialId, String factors) =>
      (db.update(db.trialPurposes)
            ..where((p) => p.trialId.equals(trialId)))
          .write(TrialPurposesCompanion(
            knownInterpretationFactors: Value(factors),
          ));

  // ── TIR-1: CV below 25% returns none on data_variability ─────────────────

  test('TIR-1: CV below 25% returns none on data_variability', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final sessionId = await makeSession(trialId);

    // Two plots, same treatment, similar values → low CV.
    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 50.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 52.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'data_variability');

    expect(f.severity, 'none');
  });

  // ── TIR-2: CV above 35% returns high on data_variability ─────────────────

  test('TIR-2: CV above 35% returns high on data_variability', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final sessionId = await makeSession(trialId);

    // Wide spread → CV > 35%.
    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 10.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 90.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'data_variability');

    expect(f.severity, 'high');
  });

  // ── TIR-3: CV value appears in reason text ────────────────────────────────

  test('TIR-3: CV value appears in reason text for data_variability', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final sessionId = await makeSession(trialId);

    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 50.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 52.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'data_variability');

    expect(f.reason, contains('CV ='));
    expect(f.reason, contains('%'));
  });

  // ── TIR-4: check at scale floor returns high on untreated_check_pressure ──

  test('TIR-4: check mean of zero returns high on untreated_check_pressure',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final sessionId = await makeSession(trialId);

    // Untreated check treatment uses code 'UTC'.
    final checkTrtId = await makeTreatment(trialId, code: 'UTC');
    final p1 = await makePlot(trialId, treatmentId: checkTrtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 0.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'untreated_check_pressure');

    expect(f.severity, 'high');
  });

  // ── TIR-5: coherence review_needed → moderate on timing deviation ─────────

  test(
      'TIR-5: coherence timing review_needed maps to moderate on '
      'application_timing_deviation', () async {
    // BBCH 32 for wheat herbicide → coherence = review_needed.
    final trialId = await makeTrial(crop: 'wheat');
    await makePurpose(trialId);

    final trtId = await makeTreatment(trialId);
    await db.into(db.treatmentComponents).insert(
          TreatmentComponentsCompanion.insert(
            trialId: trialId,
            treatmentId: trtId,
            productName: 'Product',
            pesticideCategory: const Value('herbicide'),
          ),
        );
    await db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: DateTime(2026, 4, 1),
            growthStageBbchAtApplication: const Value(32),
          ),
        );

    final dto = await risk(trialId);
    final f = factor(dto, 'application_timing_deviation');

    expect(f.severity, 'moderate');
  });

  // ── TIR-6: coherence acknowledged → moderate with researcher note ──────────

  test(
      'TIR-6: coherence timing acknowledged maps to moderate with researcher '
      'note in reason', () async {
    final trialId = await makeTrial(crop: 'wheat');
    await makePurpose(trialId);

    final trtId = await makeTreatment(trialId);
    await db.into(db.treatmentComponents).insert(
          TreatmentComponentsCompanion.insert(
            trialId: trialId,
            treatmentId: trtId,
            productName: 'Product',
            pesticideCategory: const Value('herbicide'),
          ),
        );
    await db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: DateTime(2026, 4, 1),
            growthStageBbchAtApplication: const Value(32),
          ),
        );

    final signalId = await signalRepo.raiseSignal(
      trialId: trialId,
      signalType: SignalType.causalContextFlag,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext:
          const SignalReferenceContext(seType: 'application_timing'),
      consequenceText: 'Timing deviation detected.',
    );
    await signalRepo.recordResearcherDecision(
      signalId: signalId,
      eventType: SignalDecisionEventType.confirm,
      reason: 'Rain delay approved by agronomist.',
    );

    final dto = await risk(trialId);
    final f = factor(dto, 'application_timing_deviation');

    expect(f.severity, 'moderate');
    expect(f.reason, contains('Rain delay approved by agronomist.'));
  });

  // ── TIR-7: zero plots rated → high on primary_endpoint_completeness ────────

  test(
      'TIR-7: no plots rated for primary endpoint returns high on '
      'primary_endpoint_completeness', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    await makeAssessment(trialId, 'PHYGEN');
    await makePlot(trialId); // plot exists but no ratings

    final dto = await risk(trialId);
    final f = factor(dto, 'primary_endpoint_completeness');

    expect(f.severity, 'high');
  });

  // ── TIR-8: open rater signal → moderate on rater_consistency ──────────────

  test('TIR-8: open rater_drift signal returns moderate on rater_consistency',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await signalRepo.raiseSignal(
      trialId: trialId,
      signalType: SignalType.raterDrift,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext:
          const SignalReferenceContext(seType: 'rater_consistency'),
      consequenceText: 'Rater drift detected between sessions.',
    );

    final dto = await risk(trialId);
    final f = factor(dto, 'rater_consistency');

    expect(f.severity, 'moderate');
    expect(f.reason, contains('1 open rater signal'));
  });

  // ── TIR-B1: CV reason contains "treated plots only" ──────────────────────

  test('TIR-B1: data_variability reason contains "treated plots only"',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 60.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 65.0);

    // Check plots at zero — should be excluded from CV.
    final cp1 = await makePlot(trialId, treatmentId: checkId);
    final cp2 = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp1, assessmentId, 0.0);
    await makeRating(trialId, sessionId, cp2, assessmentId, 0.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'data_variability');

    expect(f.reason, contains('treated plots only'));
    expect(f.severity, 'none');
  });

  // ── TIR-B2: only check plots → CV cannot_evaluate ─────────────────────────

  test(
      'TIR-B2: only check-plot ratings returns cannot_evaluate for '
      'data_variability', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    final cp1 = await makePlot(trialId, treatmentId: checkId);
    final cp2 = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp1, assessmentId, 40.0);
    await makeRating(trialId, sessionId, cp2, assessmentId, 50.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'data_variability');

    expect(f.severity, 'cannot_evaluate');
  });

  // ── TIR-B3: check pressure scoped to primary endpoint assessment ───────────

  test(
      'TIR-B3: check pressure ignores ratings for non-endpoint assessments',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    await makeAssessment(trialId, 'PHYGEN');
    final otherAssessmentId = await makeAssessment(trialId, 'OTHER');
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    // Rate UTC plot only for OTHER, not for the primary endpoint PHYGEN.
    final cp = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp, otherAssessmentId, 80.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'untreated_check_pressure');

    expect(f.severity, 'cannot_evaluate');
  });

  // ── TIR-B4: unmatched primary endpoint → check pressure cannot_evaluate ────

  test(
      'TIR-B4: unmatched primary endpoint returns cannot_evaluate for '
      'check pressure', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'NO_SUCH_ENDPOINT');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    final cp = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp, assessmentId, 80.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'untreated_check_pressure');

    expect(f.severity, 'cannot_evaluate');
  });

  // ── TIR-B5: no primary endpoint → check pressure cannot_evaluate ──────────

  test(
      'TIR-B5: no primary endpoint returns cannot_evaluate for '
      'check pressure', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId); // no primaryEndpoint
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    final cp = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp, assessmentId, 80.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'untreated_check_pressure');

    expect(f.severity, 'cannot_evaluate');
  });

  // ── TIR-B6: check pressure reason includes endpoint name and rep count ─────

  test(
      'TIR-B6: check pressure reason includes endpoint name and rep count',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final checkId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    final cp1 = await makePlot(trialId, treatmentId: checkId);
    final cp2 = await makePlot(trialId, treatmentId: checkId);
    await makeRating(trialId, sessionId, cp1, assessmentId, 40.0);
    await makeRating(trialId, sessionId, cp2, assessmentId, 50.0);

    final dto = await risk(trialId);
    final f = factor(dto, 'untreated_check_pressure');

    expect(f.severity, 'none');
    expect(f.reason, contains('PHYGEN'));
    expect(f.reason, contains('2 reps'));
  });

  // ── TIR-9: overall riskLevel reflects worst factor ─────────────────────────

  test('TIR-9: overall riskLevel reflects worst factor (high)', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final sessionId = await makeSession(trialId);

    // Wide spread → CV > 35% → data_variability = high.
    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 10.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 90.0);

    final dto = await risk(trialId);

    expect(factor(dto, 'data_variability').severity, 'high');
    expect(dto.riskLevel, 'high');
  });

  // ── TIR-10: all factors none → low ────────────────────────────────────────

  test('TIR-10: all factors none returns low riskLevel', () async {
    final trialId = await makeTrial();
    await makePurpose(
      trialId,
      primaryEndpoint: 'PHYGEN',
      treatmentRoleSummary: 'Active fungicide.',
    );
    // Explicitly answer site conditions with none-selected so the factor
    // returns 'none' (null → cannot_evaluate, which would raise overall level).
    await setPurposeKnownFactors(trialId, '[]');

    final assessmentId = await makeAssessment(trialId, 'PHYGEN');
    final trtId = await makeTreatment(trialId);
    final checkTrtId = await makeTreatment(trialId, code: 'UTC');
    final sessionId = await makeSession(trialId);

    // Low CV (similar values).
    final p1 = await makePlot(trialId, treatmentId: trtId);
    final p2 = await makePlot(trialId, treatmentId: trtId);
    await makeRating(trialId, sessionId, p1, assessmentId, 50.0);
    await makeRating(trialId, sessionId, p2, assessmentId, 52.0);

    // Adequate check pressure (mean=40 ≥ 10).
    final cp = await makePlot(trialId, treatmentId: checkTrtId);
    await makeRating(trialId, sessionId, cp, assessmentId, 40.0);

    // Application with BBCH and no pesticideCategory → coherence timing = aligned.
    await db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: DateTime(2026, 4, 1),
            growthStageBbchAtApplication: const Value(20),
          ),
        );

    const cleanEnv = EnvironmentalSeasonSummaryDto(
      totalPrecipitationMm: 30.0,
      totalFrostEvents: 0,
      totalExcessiveRainfallEvents: 0,
      daysWithData: 30,
      daysExpected: 30,
      overallConfidence: 'measured',
    );
    final dto = await risk(trialId, environmentalSummary: cleanEnv);

    for (final f in dto.factors) {
      expect(f.severity, 'none',
          reason: 'factor ${f.factorKey} should be none but got ${f.severity}');
    }
    expect(dto.riskLevel, 'low');
  });

  // ── SC-1: null knownInterpretationFactors → cannot_evaluate ───────────────

  test('SC-1: null knownInterpretationFactors → site factor cannot_evaluate',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId); // no knownInterpretationFactors set

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'cannot_evaluate');
    expect(f.reason, 'Site conditions not yet captured.');
  });

  // ── SC-2: empty array (none selected) → none ──────────────────────────────

  test('SC-2: empty array (none selected) → none severity', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId, InterpretationFactorsCodec.serialize([]));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'none');
    expect(f.reason, 'No site conditions flagged by researcher.');
  });

  // ── SC-3: low_pest_pressure → moderate ────────────────────────────────────

  test('SC-3: low_pest_pressure → moderate severity with condition in reason',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId, InterpretationFactorsCodec.serialize(['low_pest_pressure']));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'moderate');
    expect(f.reason, contains('Low pest'));
  });

  // ── SC-4: high_pest_pressure → none ──────────────────────────────────────

  test('SC-4: high_pest_pressure alone → none severity', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId, InterpretationFactorsCodec.serialize(['high_pest_pressure']));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'none');
    expect(f.reason, contains('High pest'));
  });

  // ── SC-5: spatial_gradient → moderate ────────────────────────────────────

  test('SC-5: spatial_gradient → moderate severity', () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId, InterpretationFactorsCodec.serialize(['spatial_gradient']));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'moderate');
  });

  // ── SC-6: low_pest_pressure + spatial_gradient → moderate (highest wins) ─

  test(
      'SC-6: low_pest_pressure + spatial_gradient → moderate (highest severity wins)',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId,
        InterpretationFactorsCodec.serialize(
            ['low_pest_pressure', 'spatial_gradient']));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'moderate');
    expect(f.reason, contains('Low pest'));
    expect(f.reason, contains('Spatial gradient'));
  });

  // ── SC-7: other text → moderate with researcher text in reason ────────────

  test('SC-7: hasOther with text → moderate with researcher text in reason',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId,
        InterpretationFactorsCodec.serialize([],
            otherText: 'Unusual soil compaction'));

    final dto = await risk(trialId);
    final f = factor(dto, 'known_site_season_factors');

    expect(f.severity, 'moderate');
    expect(f.reason, contains('Unusual soil compaction'));
  });

  // ── SC-8: site conditions moderate → readiness caution not action item ────

  test('SC-8: site conditions moderate → readiness caution, not action item',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await setPurposeKnownFactors(
        trialId, InterpretationFactorsCodec.serialize(['drought_stress']));

    final riskDto = await risk(trialId);
    final siteF = factor(riskDto, 'known_site_season_factors');
    expect(siteF.severity, 'moderate');

    final readiness = computeTrialReadinessStatement(
      coherenceDto: TrialCoherenceDto(
        coherenceState: 'aligned',
        checks: const [],
        computedAt: DateTime(2026, 1, 1),
      ),
      riskDto: riskDto,
      ctqDto: const TrialCtqDto(
        trialId: 1,
        ctqItems: [],
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        overallStatus: 'ready_for_review',
      ),
      trialState: 'active',
    );

    expect(
      readiness.cautions.any((c) => c.contains('Drought') || c.contains('drought')),
      isTrue,
      reason: 'site condition must appear in cautions',
    );
    expect(
      readiness.actionItems.any((a) => a.contains('Drought') || a.contains('drought')),
      isFalse,
      reason: 'site condition must not appear in action items',
    );
  });
}
