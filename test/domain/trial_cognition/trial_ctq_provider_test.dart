import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_evaluator.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CtqFactorDefinitionRepository ctqRepo;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ctqRepo = CtqFactorDefinitionRepository(db);
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
  });

  tearDown(() async => db.close());

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<({int trialId, int purposeId})> makeTrialAndPurpose() async {
    final trialId =
        await trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');
    final purposeId =
        await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    return (trialId: trialId, purposeId: purposeId);
  }

  Future<({int trialId, int purposeId})> makeSeededTrial() async {
    final ctx = await makeTrialAndPurpose();
    await ctqRepo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    return ctx;
  }

  Future<int> makePlot(int trialId, {bool isGuard = false, int? treatmentId}) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
        trialId: trialId,
        plotId: 'P${DateTime.now().microsecondsSinceEpoch}',
        isGuardRow: Value(isGuard),
        treatmentId: Value(treatmentId),
      ));

  Future<int> makeSession(int trialId) =>
      db.into(db.sessions).insert(SessionsCompanion.insert(
        trialId: trialId,
        name: 'S1',
        sessionDateLocal: '2026-04-01',
      ));

  Future<int> makeAssessment(int trialId) =>
      db.into(db.assessments).insert(
        AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
      );

  Future<void> makeRating(
    int trialId,
    int plotPk,
    int sessionId,
    int assessmentId, {
    double? lat,
    double? lng,
    double? numericValue,
  }) =>
      db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
        trialId: trialId,
        plotPk: plotPk,
        sessionId: sessionId,
        assessmentId: assessmentId,
        capturedLatitude: Value(lat),
        capturedLongitude: Value(lng),
        numericValue: Value(numericValue),
      ));

  Future<int> makeCheckTreatment(int trialId) =>
      db.into(db.treatments).insert(TreatmentsCompanion.insert(
        trialId: trialId,
        code: 'CHK',
        name: 'Untreated Check',
      ));

  Future<void> makePhoto(int trialId, int plotPk, int sessionId) =>
      db.into(db.photos).insert(PhotosCompanion.insert(
        trialId: trialId,
        plotPk: plotPk,
        sessionId: sessionId,
        filePath: '/fake/photo.jpg',
      ));

  Future<int> makeTreatment(int trialId) =>
      db.into(db.treatments).insert(TreatmentsCompanion.insert(
        trialId: trialId,
        code: 'TRT_A',
        name: 'Treatment A',
      ));

  Future<void> makeApplication(int trialId) =>
      db.into(db.trialApplicationEvents).insert(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: DateTime(2026, 4, 1),
        ),
      );

  Future<void> makeApplicationWithBbch(int trialId, {int? bbch}) =>
      db.into(db.trialApplicationEvents).insert(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: DateTime(2026, 4, 1),
          growthStageBbchAtApplication: Value(bbch),
        ),
      );

  Future<void> makeTreatmentComponent(
    int trialId,
    int treatmentId, {
    String? pesticideCategory,
  }) =>
      db.into(db.treatmentComponents).insert(
        TreatmentComponentsCompanion.insert(
          trialId: trialId,
          treatmentId: treatmentId,
          productName: 'Test Product',
          pesticideCategory: Value(pesticideCategory),
        ),
      );

  Future<void> makeSignal(
    int trialId, {
    required String type,
    required String severity,
    String status = 'open',
  }) =>
      db.into(db.signals).insert(SignalsCompanion.insert(
        trialId: trialId,
        signalType: type,
        moment: 1,
        severity: severity,
        raisedAt: 0,
        referenceContext: '{}',
        consequenceText: 'Test signal.',
        status: Value(status),
        createdAt: 0,
      ));

  Future<TrialCtqDto> evaluate(int trialId) async {
    final factors = await ctqRepo.watchCtqFactorsForTrial(trialId).first;
    return computeTrialCtqDtoV1(db, trialId, factors);
  }

  TrialCtqItemDto? factorItem(TrialCtqDto dto, String key) =>
      dto.ctqItems.where((i) => i.factorKey == key).firstOrNull;

  // ── Tests ─────────────────────────────────────────────────────────────────

  test('1: empty trial with no factors returns unknown without crashing',
      () async {
    final ctx = await makeTrialAndPurpose();
    final dto = await evaluate(ctx.trialId);
    expect(dto.overallStatus, 'unknown');
    expect(dto.ctqItems, isEmpty);
    expect(dto.blockerCount, 0);
    expect(dto.warningCount, 0);
    expect(dto.reviewCount, 0);
    expect(dto.satisfiedCount, 0);
  });

  test(
      '2: seeded trial with one plot but no evidence — evaluable factors show missing/unknown',
      () async {
    final ctx = await makeSeededTrial();
    await makePlot(ctx.trialId); // analyzable plot → plot_completeness evaluable
    final dto = await evaluate(ctx.trialId);

    expect(dto.ctqItems.length, kCtqDefaultFactorKeys.length);
    // evidence-missing factors
    expect(factorItem(dto, 'photo_evidence')?.status, 'missing');
    expect(factorItem(dto, 'treatment_identity')?.status, 'missing');
    expect(factorItem(dto, 'plot_completeness')?.status, 'missing');
    expect(factorItem(dto, 'rating_window')?.status, 'missing');
    // no ratings → GPS cannot be evaluated
    expect(factorItem(dto, 'gps_evidence')?.status, 'unknown');
    // no treatments → application_timing cannot be evaluated
    expect(factorItem(dto, 'application_timing')?.status, 'unknown');
    // no rater signals → consistency unknown
    expect(factorItem(dto, 'rater_consistency')?.status, 'unknown');
    // intentionally unknown
    expect(factorItem(dto, 'disease_pressure')?.status, 'unknown');
    expect(factorItem(dto, 'crop_stage')?.status, 'unknown');
    expect(factorItem(dto, 'rainfall_after_application')?.status, 'unknown');
  });

  test('3: treatment_identity is satisfied when treatments exist', () async {
    final ctx = await makeSeededTrial();
    await makeTreatment(ctx.trialId);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'treatment_identity')?.status, 'satisfied');
    expect(dto.satisfiedCount, greaterThanOrEqualTo(1));
  });

  test('4: treatment_identity is missing when no treatments exist', () async {
    final ctx = await makeSeededTrial();
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'treatment_identity')?.status, 'missing');
    expect(dto.warningCount, greaterThanOrEqualTo(1));
  });

  test('5: photo_evidence is satisfied when a photo exists', () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    await makePhoto(ctx.trialId, plotPk, sessionId);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'photo_evidence')?.status, 'satisfied');
  });

  test('6: gps_evidence is satisfied when a rating with GPS coordinates exists',
      () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
        lat: 51.5074, lng: -0.1278);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'gps_evidence')?.status, 'satisfied');
  });

  group('7: plot_completeness', () {
    test('missing when analyzable plots exist but no ratings', () async {
      final ctx = await makeSeededTrial();
      await makePlot(ctx.trialId);
      await makePlot(ctx.trialId);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'plot_completeness')?.status, 'missing');
    });

    test('review_needed when only some plots are rated', () async {
      final ctx = await makeSeededTrial();
      final p1 = await makePlot(ctx.trialId);
      await makePlot(ctx.trialId); // second plot, unrated
      final sessionId = await makeSession(ctx.trialId);
      final assessmentId = await makeAssessment(ctx.trialId);
      await makeRating(ctx.trialId, p1, sessionId, assessmentId);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'plot_completeness')?.status, 'review_needed');
    });

    test('satisfied when all analyzable plots have recorded ratings', () async {
      final ctx = await makeSeededTrial();
      final p1 = await makePlot(ctx.trialId);
      final sessionId = await makeSession(ctx.trialId);
      final assessmentId = await makeAssessment(ctx.trialId);
      await makeRating(ctx.trialId, p1, sessionId, assessmentId);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'plot_completeness')?.status, 'satisfied');
    });

    test('unknown when no analyzable plots are defined', () async {
      final ctx = await makeSeededTrial();
      // no plots inserted → cannot evaluate
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'plot_completeness')?.status, 'unknown');
    });

    test('guard-only plots are not counted as analyzable', () async {
      final ctx = await makeSeededTrial();
      await makePlot(ctx.trialId, isGuard: true); // guard row only
      final dto = await evaluate(ctx.trialId);
      // no analyzable plots → unknown
      expect(factorItem(dto, 'plot_completeness')?.status, 'unknown');
    });
  });

  test('8: open critical signal causes review_needed overall', () async {
    final ctx = await makeSeededTrial();
    await makeSignal(ctx.trialId,
        type: 'scale_violation', severity: 'critical');
    final dto = await evaluate(ctx.trialId);
    expect(dto.overallStatus, 'review_needed');
  });

  test('8b: open rater_drift signal marks rater_consistency as review_needed',
      () async {
    final ctx = await makeSeededTrial();
    await makeSignal(ctx.trialId, type: 'rater_drift', severity: 'review');
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rater_consistency')?.status, 'review_needed');
    expect(dto.reviewCount, greaterThanOrEqualTo(1));
  });

  test('8c: critical rater_drift signal marks rater_consistency as blocked',
      () async {
    final ctx = await makeSeededTrial();
    await makeSignal(ctx.trialId, type: 'rater_drift', severity: 'critical');
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rater_consistency')?.status, 'blocked');
    expect(dto.blockerCount, greaterThanOrEqualTo(1));
  });

  test('8d: resolved rater_drift signal does not affect rater_consistency',
      () async {
    final ctx = await makeSeededTrial();
    await makeSignal(ctx.trialId,
        type: 'rater_drift', severity: 'review', status: 'resolved');
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rater_consistency')?.status, 'unknown');
  });

  test('9: protocol_divergence signal causes review_needed overall', () async {
    final ctx = await makeSeededTrial();
    await makeSignal(ctx.trialId,
        type: 'protocol_divergence', severity: 'review');
    final dto = await evaluate(ctx.trialId);
    expect(dto.overallStatus, 'review_needed');
  });

  test('10: disease_pressure remains unknown', () async {
    final ctx = await makeSeededTrial();
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'disease_pressure')?.status, 'unknown');
  });

  test('11: crop_stage remains unknown', () async {
    final ctx = await makeSeededTrial();
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'crop_stage')?.status, 'unknown');
  });

  test('12: rainfall_after_application remains unknown', () async {
    final ctx = await makeSeededTrial();
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rainfall_after_application')?.status, 'unknown');
  });

  test(
      '13: overallStatus is ready_for_review when all evaluated factors are satisfied and no issues',
      () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    // rating with GPS → satisfies plot_completeness, rating_window, gps_evidence
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
        lat: 51.5074, lng: -0.1278);
    // photo → satisfies photo_evidence
    await makePhoto(ctx.trialId, plotPk, sessionId);
    // treatment + application → satisfies treatment_identity, application_timing
    await makeTreatment(ctx.trialId);
    await makeApplication(ctx.trialId);

    final dto = await evaluate(ctx.trialId);

    expect(factorItem(dto, 'plot_completeness')?.status, 'satisfied');
    expect(factorItem(dto, 'photo_evidence')?.status, 'satisfied');
    expect(factorItem(dto, 'gps_evidence')?.status, 'satisfied');
    expect(factorItem(dto, 'treatment_identity')?.status, 'satisfied');
    expect(factorItem(dto, 'rating_window')?.status, 'satisfied');
    expect(factorItem(dto, 'application_timing')?.status, 'satisfied');
    expect(factorItem(dto, 'rater_consistency')?.status, 'unknown');
    expect(dto.overallStatus, 'ready_for_review');
    expect(dto.blockerCount, 0);
    expect(dto.warningCount, 0);
    expect(dto.reviewCount, 0);
  });

  // ── rating_window upgrades ────────────────────────────────────────────────

  test(
      '14: rating_window is review_needed when a causal_context_flag signal is open',
      () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId);
    await makeSignal(ctx.trialId,
        type: 'causal_context_flag', severity: 'review');
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rating_window')?.status, 'review_needed');
    expect(dto.reviewCount, greaterThanOrEqualTo(1));
  });

  test(
      '15: rating_window is satisfied when ratings exist and no timing-window signal',
      () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId);
    // no causal_context_flag signal → satisfied
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rating_window')?.status, 'satisfied');
  });

  test('15b: resolved causal_context_flag does not trigger rating_window review',
      () async {
    final ctx = await makeSeededTrial();
    final plotPk = await makePlot(ctx.trialId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId);
    await makeSignal(ctx.trialId,
        type: 'causal_context_flag', severity: 'review', status: 'resolved');
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'rating_window')?.status, 'satisfied');
  });

  // ── data_variance ─────────────────────────────────────────────────────────

  test('16: data_variance is unknown when no ratings exist', () async {
    final ctx = await makeSeededTrial();
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'data_variance')?.status, 'unknown');
  });

  test(
      '17: data_variance is unknown when fewer than 3 replicates per assessment',
      () async {
    final ctx = await makeSeededTrial();
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    // 2 ratings — below the 3-rep minimum
    for (final v in [10.0, 12.0]) {
      final plotPk = await makePlot(ctx.trialId);
      await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
          numericValue: v);
    }
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'data_variance')?.status, 'unknown');
  });

  test('18: data_variance is review_needed when CV ≥ 50%', () async {
    final ctx = await makeSeededTrial();
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    // Values [1.0, 1.0, 200.0] → CV ≈ 171% — well above the 50% threshold
    for (final v in [1.0, 1.0, 200.0]) {
      final plotPk = await makePlot(ctx.trialId);
      await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
          numericValue: v);
    }
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'data_variance')?.status, 'review_needed');
  });

  test('19: data_variance is satisfied when CV < 50%', () async {
    final ctx = await makeSeededTrial();
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    // Values [10.0, 11.0, 12.0] → CV ≈ 9.1% — well below the 50% threshold
    for (final v in [10.0, 11.0, 12.0]) {
      final plotPk = await makePlot(ctx.trialId);
      await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
          numericValue: v);
    }
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'data_variance')?.status, 'satisfied');
  });

  // ── untreated_check_pressure ──────────────────────────────────────────────

  test('20: untreated_check_pressure is unknown when no check treatment exists',
      () async {
    final ctx = await makeSeededTrial();
    await makeTreatment(ctx.trialId); // non-check treatment (code: 'TRT_A')
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'untreated_check_pressure')?.status, 'unknown');
  });

  test(
      '21: untreated_check_pressure is unknown when check plots have no numeric values',
      () async {
    final ctx = await makeSeededTrial();
    final checkId = await makeCheckTreatment(ctx.trialId);
    final plotPk = await makePlot(ctx.trialId, treatmentId: checkId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    // rating with no numericValue → checkValues list remains empty
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'untreated_check_pressure')?.status, 'unknown');
  });

  test(
      '22: untreated_check_pressure is review_needed when check mean is at floor zero',
      () async {
    final ctx = await makeSeededTrial();
    final checkId = await makeCheckTreatment(ctx.trialId);
    final plotPk = await makePlot(ctx.trialId, treatmentId: checkId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
        numericValue: 0.0);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'untreated_check_pressure')?.status, 'review_needed');
  });

  test(
      '23: untreated_check_pressure is satisfied when check plots show non-zero mean',
      () async {
    final ctx = await makeSeededTrial();
    final checkId = await makeCheckTreatment(ctx.trialId);
    final plotPk = await makePlot(ctx.trialId, treatmentId: checkId);
    final sessionId = await makeSession(ctx.trialId);
    final assessmentId = await makeAssessment(ctx.trialId);
    await makeRating(ctx.trialId, plotPk, sessionId, assessmentId,
        numericValue: 25.0);
    final dto = await evaluate(ctx.trialId);
    expect(factorItem(dto, 'untreated_check_pressure')?.status, 'satisfied');
  });

  // ── application_timing upgrades ──────────────────────────────────────────

  group('AT: application_timing category + BBCH evaluation', () {
    test('AT-1: no application events → missing', () async {
      final ctx = await makeSeededTrial();
      await makeTreatment(ctx.trialId);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'missing');
      expect(
        factorItem(dto, 'application_timing')?.reason,
        'No application events have been recorded.',
      );
    });

    test('AT-2: events exist, no pesticideCategory on any component → satisfied',
        () async {
      final ctx = await makeSeededTrial();
      final trtId = await makeTreatment(ctx.trialId);
      await makeTreatmentComponent(ctx.trialId, trtId); // no category
      await makeApplication(ctx.trialId);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'satisfied');
      expect(
        factorItem(dto, 'application_timing')?.reason,
        'Application events are present.',
      );
    });

    test(
        'AT-3: events exist, pesticideCategory set, all BBCH null → review_needed',
        () async {
      final ctx = await makeSeededTrial();
      final trtId = await makeTreatment(ctx.trialId);
      await makeTreatmentComponent(ctx.trialId, trtId,
          pesticideCategory: 'fungicide');
      await makeApplicationWithBbch(ctx.trialId); // bbch null
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'review_needed');
      expect(
        factorItem(dto, 'application_timing')?.reason,
        'Application events exist but BBCH at application has not been recorded. Timing cannot be evaluated.',
      );
    });

    test('AT-4: events exist, pesticideCategory set, BBCH present → satisfied',
        () async {
      final ctx = await makeSeededTrial();
      final trtId = await makeTreatment(ctx.trialId);
      await makeTreatmentComponent(ctx.trialId, trtId,
          pesticideCategory: 'fungicide');
      await makeApplicationWithBbch(ctx.trialId, bbch: 59);
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'satisfied');
      expect(
        factorItem(dto, 'application_timing')?.reason,
        contains('structured BBCH capture'),
      );
    });

    test('AT-5: multiple events — any with BBCH present → satisfied', () async {
      final ctx = await makeSeededTrial();
      final trtId = await makeTreatment(ctx.trialId);
      await makeTreatmentComponent(ctx.trialId, trtId,
          pesticideCategory: 'herbicide');
      await makeApplicationWithBbch(ctx.trialId); // BBCH null
      await makeApplicationWithBbch(ctx.trialId, bbch: 30); // BBCH present
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'satisfied');
    });

    test(
        'AT-6: multiple events — all BBCH null, category set → review_needed',
        () async {
      final ctx = await makeSeededTrial();
      final trtId = await makeTreatment(ctx.trialId);
      await makeTreatmentComponent(ctx.trialId, trtId,
          pesticideCategory: 'insecticide');
      await makeApplicationWithBbch(ctx.trialId); // BBCH null
      await makeApplicationWithBbch(ctx.trialId); // BBCH null
      final dto = await evaluate(ctx.trialId);
      expect(factorItem(dto, 'application_timing')?.status, 'review_needed');
    });
  });

  // ── DTO structure (pure model, no DB) ─────────────────────────────────────

  test('missing/satisfied/review_needed are representable via TrialCtqItemDto',
      () {
    const missing = TrialCtqItemDto(
      factorKey: 'plot_completeness',
      label: 'Plot Completeness',
      importance: 'critical',
      status: 'missing',
      evidenceSummary: '0 of 16 plots rated.',
      reason: 'No ratings recorded.',
      source: 'system',
    );
    expect(missing.isBlocked, false);
    expect(missing.isSatisfied, false);
    expect(missing.needsReview, false);

    const satisfied = TrialCtqItemDto(
      factorKey: 'plot_completeness',
      label: 'Plot Completeness',
      importance: 'critical',
      status: 'satisfied',
      evidenceSummary: '16/16 plots rated.',
      reason: 'Full coverage.',
      source: 'system',
    );
    expect(satisfied.isSatisfied, true);

    const blocked = TrialCtqItemDto(
      factorKey: 'rater_consistency',
      label: 'Rater Consistency',
      importance: 'standard',
      status: 'blocked',
      evidenceSummary: '1 open rater signal(s).',
      reason: 'Open rater signals require review.',
      source: 'system',
    );
    expect(blocked.isBlocked, true);
    expect(blocked.needsReview, false);
  });
}
