import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_evaluator.dart';
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

  TrialCoherenceCheckDto check(TrialCoherenceDto dto, String key) =>
      dto.checks.firstWhere((c) => c.checkKey == key);

  Future<int> makeTrial({String? crop}) =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}',
          crop: crop);

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

  Future<void> makeAssignment(int trialId, int treatmentId) =>
      db.into(db.assignments).insert(AssignmentsCompanion.insert(
        trialId: trialId,
        plotId: -1, // no plot needed for replication counting
        treatmentId: Value(treatmentId),
      ));

  Future<void> makeApplicationWithBbch(
    int trialId,
    int bbch, {
    String? pesticideCategory,
    String crop = 'wheat',
  }) async {
    if (pesticideCategory != null) {
      final trtId = await makeTreatment(trialId);
      await db.into(db.treatmentComponents).insert(
        TreatmentComponentsCompanion.insert(
          trialId: trialId,
          treatmentId: trtId,
          productName: 'Product',
          pesticideCategory: Value(pesticideCategory),
        ),
      );
    }
    await db.into(db.trialApplicationEvents).insert(
      TrialApplicationEventsCompanion.insert(
        trialId: trialId,
        applicationDate: DateTime(2026, 4, 1),
        growthStageBbchAtApplication: Value(bbch),
      ),
    );
  }

  Future<void> raiseTimingSignalWithDecision(
    int trialId, {
    required String note,
  }) async {
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
      reason: note,
    );
  }

  // ── TC-1: No purpose → all checks cannot_evaluate ─────────────────────────

  test('TC-1: trial with no purpose returns cannot_evaluate on all checks',
      () async {
    final trialId = await makeTrial();
    final dto = await coherence(trialId);

    expect(dto.coherenceState, 'cannot_evaluate');
    for (final c in dto.checks) {
      expect(c.status, 'cannot_evaluate',
          reason: 'check ${c.checkKey} should be cannot_evaluate');
    }
  });

  // ── TC-2: Check 1 — matching assessment → aligned ─────────────────────────

  test('TC-2: purpose with matching assessment returns aligned on check 1',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    await makeAssessment(trialId, 'PHYGEN');

    final dto = await coherence(trialId);
    final c = check(dto, 'primary_endpoint_assessment_present');

    expect(c.status, 'aligned');
  });

  // ── TC-3: Check 2 — BBCH 32 wheat herbicide → review_needed ──────────────

  test(
      'TC-3: BBCH 32 for wheat herbicide without acknowledgment returns '
      'review_needed on check 2', () async {
    // Wheat herbicide optimal BBCH 12–30, acceptable 12–45.
    // BBCH 32 is outside optimal (severity 1) → review_needed.
    final trialId = await makeTrial(crop: 'wheat');
    await makePurpose(trialId);
    await makeApplicationWithBbch(trialId, 32,
        pesticideCategory: 'herbicide', crop: 'wheat');

    final dto = await coherence(trialId);
    final c = check(dto, 'application_timing_within_claim_window');

    expect(c.status, 'review_needed');
  });

  // ── TC-4: Check 2 — BBCH 32 + acknowledged signal → acknowledged ──────────

  test(
      'TC-4: BBCH 32 with researcher-acknowledged timing signal returns '
      'acknowledged on check 2 and includes researcher note', () async {
    final trialId = await makeTrial(crop: 'wheat');
    await makePurpose(trialId);
    await makeApplicationWithBbch(trialId, 32,
        pesticideCategory: 'herbicide', crop: 'wheat');
    await raiseTimingSignalWithDecision(trialId,
        note: 'Applied slightly late due to rain delay — agronomist approved.');

    final dto = await coherence(trialId);
    final c = check(dto, 'application_timing_within_claim_window');

    expect(c.status, 'acknowledged');
    expect(c.reason,
        contains('Applied slightly late due to rain delay — agronomist approved.'));
  });

  // ── TC-5: Check 3 — 4 reps → aligned ─────────────────────────────────────

  test('TC-5: 4 assignments on claim treatment returns aligned on check 3',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId,
        treatmentRoleSummary: 'Treatment A is the active fungicide.');
    final trtId = await makeTreatment(trialId);
    for (var i = 0; i < 4; i++) {
      await makeAssignment(trialId, trtId);
    }

    final dto = await coherence(trialId);
    final c = check(dto, 'claim_treatment_adequate_replication');

    expect(c.status, 'aligned');
  });

  // ── TC-6: Check 3 — 3 reps → review_needed ───────────────────────────────

  test('TC-6: 3 assignments on claim treatment returns review_needed on check 3',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId,
        treatmentRoleSummary: 'Treatment A is the active fungicide.');
    final trtId = await makeTreatment(trialId);
    for (var i = 0; i < 3; i++) {
      await makeAssignment(trialId, trtId);
    }

    final dto = await coherence(trialId);
    final c = check(dto, 'claim_treatment_adequate_replication');

    expect(c.status, 'review_needed');
  });

  // ── TC-7: Check 4 — no open signals → aligned ────────────────────────────

  test('TC-7: no open protocol divergence signals returns aligned on check 4',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);

    final dto = await coherence(trialId);
    final c = check(dto, 'open_protocol_divergence_signals');

    expect(c.status, 'aligned');
  });

  // ── TC-8: Check 4 — one open signal → review_needed ─────────────────────

  test(
      'TC-8: one open protocol_divergence signal returns review_needed on check 4',
      () async {
    final trialId = await makeTrial();
    await makePurpose(trialId);
    await signalRepo.raiseSignal(
      trialId: trialId,
      signalType: SignalType.protocolDivergence,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext:
          const SignalReferenceContext(seType: 'application_method'),
      consequenceText: 'Application method deviated from protocol.',
    );

    final dto = await coherence(trialId);
    final c = check(dto, 'open_protocol_divergence_signals');

    expect(c.status, 'review_needed');
    expect(c.reason, contains('1 open signal'));
  });

  // ── TC-9: Overall state reflects worst check ──────────────────────────────

  test('TC-9: overall coherenceState reflects worst individual check', () async {
    // Check 3 will be cannot_evaluate (no purpose treatmentRoleSummary).
    // Check 4 has an open signal → review_needed.
    // Overall must be cannot_evaluate (worst).
    final trialId = await makeTrial();
    // Purpose with no treatmentRoleSummary → check 3 = cannot_evaluate.
    await makePurpose(trialId, primaryEndpoint: 'PHYGEN');
    await makeAssessment(trialId, 'PHYGEN');
    await signalRepo.raiseSignal(
      trialId: trialId,
      signalType: SignalType.protocolDivergence,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext:
          const SignalReferenceContext(seType: 'application_method'),
      consequenceText: 'Protocol deviation noted.',
    );

    final dto = await coherence(trialId);

    expect(
      check(dto, 'claim_treatment_adequate_replication').status,
      'cannot_evaluate',
    );
    expect(
      check(dto, 'open_protocol_divergence_signals').status,
      'review_needed',
    );
    expect(dto.coherenceState, 'cannot_evaluate');
  });
}
