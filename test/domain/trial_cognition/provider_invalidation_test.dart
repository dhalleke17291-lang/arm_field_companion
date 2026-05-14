import 'dart:async';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<int> makeTrial({String? crop}) => trialRepo.createTrial(
        name: 'T${DateTime.now().microsecondsSinceEpoch}',
        crop: crop,
      );

  Future<int> makeSession(int trialId) =>
      db.into(db.sessions).insert(SessionsCompanion.insert(
            trialId: trialId,
            name: 'S1',
            sessionDateLocal: '2026-04-01',
          ));

  Future<int> makePlot(int trialId) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: 'P1',
          ));

  Future<int> makeAssessment(int trialId) => db.into(db.assessments).insert(
        AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
      );

  Future<void> makeRecordedRating(
    int trialId,
    int plotPk,
    int sessionId,
    int assessmentId,
  ) =>
      db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            assessmentId: assessmentId,
            resultStatus: const Value('RECORDED'),
            isCurrent: const Value(true),
            numericValue: const Value(3.0),
          ));

  Future<void> makeSignal(int trialId, String type) =>
      db.into(db.signals).insert(SignalsCompanion.insert(
            trialId: trialId,
            signalType: type,
            moment: 1,
            severity: 'warning',
            raisedAt: 0,
            referenceContext: '{}',
            consequenceText: 'Test.',
            status: const Value('open'),
            createdAt: 0,
          ));

  Future<void> makeApplicationWithBbch(int trialId, {required int bbch}) =>
      db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion.insert(
              trialId: trialId,
              applicationDate: DateTime(2026, 4, 1),
              status: const Value('applied'),
              appliedAt: Value(DateTime(2026, 4, 1, 9)),
              growthStageBbchAtApplication: Value(bbch),
            ),
          );

  Future<int> makeTreatment(int trialId) =>
      db.into(db.treatments).insert(TreatmentsCompanion.insert(
            trialId: trialId,
            code: 'TRT_A',
            name: 'Treatment A',
          ));

  Future<void> makeTreatmentComponent(
    int trialId,
    int treatmentId, {
    String? pesticideCategory,
  }) =>
      db.into(db.treatmentComponents).insert(
            TreatmentComponentsCompanion.insert(
              trialId: trialId,
              treatmentId: treatmentId,
              productName: 'Product A',
              pesticideCategory: Value(pesticideCategory),
            ),
          );

  // ── INV-1 ─────────────────────────────────────────────────────────────────

  test(
      'INV-1: openSignalsForTrialProvider streams inserted signals without invalidation',
      () async {
    final trialId = await makeTrial();
    final c = makeContainer();

    final before = await c.read(openSignalsForTrialProvider(trialId).future);
    expect(before, isEmpty);

    final updated = Completer<List<Signal>>();
    final sub = c.listen(openSignalsForTrialProvider(trialId), (_, next) {
      next.whenData((rows) {
        if (rows.isNotEmpty && !updated.isCompleted) {
          updated.complete(rows);
        }
      });
    });
    addTearDown(sub.close);

    await makeSignal(trialId, 'aov_missing');

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('openSignalsForTrialProvider did not emit inserted signal'),
    );
    expect(after, hasLength(1));
    expect(after.first.signalType, 'aov_missing');
  });

  // ── INV-2 ─────────────────────────────────────────────────────────────────

  test(
      'INV-2: trialCoherenceProvider streams inserted application without invalidation',
      () async {
    final trialId = await makeTrial();
    await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    await makeTreatment(trialId);
    final c = makeContainer();

    // No application → cannot_evaluate
    final before = await c.read(trialCoherenceProvider(trialId).future);
    final beforeTiming = before.checks.firstWhere(
      (ch) => ch.checkKey == 'application_timing_within_claim_window',
    );
    expect(beforeTiming.status, 'cannot_evaluate');

    final updated = Completer<TrialCoherenceDto>();
    final sub = c.listen(trialCoherenceProvider(trialId), (_, next) {
      next.whenData((dto) {
        final timing = dto.checks.firstWhere(
          (ch) => ch.checkKey == 'application_timing_within_claim_window',
        );
        if (timing.status == 'aligned' && !updated.isCompleted) {
          updated.complete(dto);
        }
      });
    });
    addTearDown(sub.close);

    // Insert application with BBCH; provider should emit from table stream.
    await makeApplicationWithBbch(trialId, bbch: 20);

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('trialCoherenceProvider did not emit inserted application'),
    );
    final afterTiming = after.checks.firstWhere(
      (ch) => ch.checkKey == 'application_timing_within_claim_window',
    );
    // Application present with BBCH, no BBCH profile configured → aligned
    expect(afterTiming.status, 'aligned');
  });

  // ── INV-3 ─────────────────────────────────────────────────────────────────

  test(
      'INV-3: trialEvidenceArcProvider streams RECORDED rating without invalidation',
      () async {
    final trialId = await makeTrial();
    final sessionId = await makeSession(trialId);
    final plotPk = await makePlot(trialId);
    final assessmentId = await makeAssessment(trialId);
    final c = makeContainer();

    // Session exists but no RECORDED ratings yet → started
    final before = await c.read(trialEvidenceArcProvider(trialId).future);
    expect(before.evidenceState, 'started');

    final updated = Completer<TrialEvidenceArcDto>();
    final sub = c.listen(trialEvidenceArcProvider(trialId), (_, next) {
      next.whenData((dto) {
        if (dto.evidenceState == 'partial' && !updated.isCompleted) {
          updated.complete(dto);
        }
      });
    });
    addTearDown(sub.close);

    // Insert RECORDED rating; provider should emit from table stream.
    await makeRecordedRating(trialId, plotPk, sessionId, assessmentId);

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('trialEvidenceArcProvider did not emit inserted rating'),
    );
    // Rating present but no photos → partial (photos still missing)
    expect(after.evidenceState, 'partial');
    expect(after.hasEvidence, isTrue);
  });

  // ── INV-4 ─────────────────────────────────────────────────────────────────

  test(
      'INV-4: trialEvidenceArcProvider streams photo insert without invalidation',
      () async {
    final trialId = await makeTrial();
    final sessionId = await makeSession(trialId);
    final plotPk = await makePlot(trialId);
    final assessmentId = await makeAssessment(trialId);
    await makeRecordedRating(trialId, plotPk, sessionId, assessmentId);
    final c = makeContainer();

    // Ratings present but no photos → missingEvidenceItems includes photo gap
    final before = await c.read(trialEvidenceArcProvider(trialId).future);
    expect(
      before.missingEvidenceItems.any((m) => m.toLowerCase().contains('photo')),
      isTrue,
      reason: 'photo gap should be present before inserting a photo',
    );

    final updated = Completer<TrialEvidenceArcDto>();
    final sub = c.listen(trialEvidenceArcProvider(trialId), (_, next) {
      next.whenData((dto) {
        final hasPhotoGap = dto.missingEvidenceItems
            .any((m) => m.toLowerCase().contains('photo'));
        if (!hasPhotoGap && !updated.isCompleted) {
          updated.complete(dto);
        }
      });
    });
    addTearDown(sub.close);

    // Insert a photo; provider should emit from table stream.
    await db.into(db.photos).insert(PhotosCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          sessionId: sessionId,
          filePath: '/fake/img.jpg',
        ));

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('trialEvidenceArcProvider did not emit inserted photo'),
    );
    expect(
      after.missingEvidenceItems.any((m) => m.toLowerCase().contains('photo')),
      isFalse,
      reason: 'photo gap should clear after photo is inserted',
    );
  });

  // ── INV-5 ─────────────────────────────────────────────────────────────────

  test(
      'INV-5: trialCoherenceProvider streams open protocol-divergence signal without invalidation',
      () async {
    final trialId = await makeTrial();
    await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    final c = makeContainer();

    // No signals → open_protocol_divergence_signals is aligned
    final before = await c.read(trialCoherenceProvider(trialId).future);
    final beforeCheck = before.checks.firstWhere(
      (ch) => ch.checkKey == 'open_protocol_divergence_signals',
    );
    expect(beforeCheck.status, 'aligned');

    final updated = Completer<TrialCoherenceDto>();
    final sub = c.listen(trialCoherenceProvider(trialId), (_, next) {
      next.whenData((dto) {
        final check = dto.checks.firstWhere(
          (ch) => ch.checkKey == 'open_protocol_divergence_signals',
        );
        if (check.status == 'review_needed' && !updated.isCompleted) {
          updated.complete(dto);
        }
      });
    });
    addTearDown(sub.close);

    // Insert an open protocol_divergence signal; provider should stream update.
    await makeSignal(trialId, 'protocol_divergence');

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('trialCoherenceProvider did not emit inserted signal'),
    );
    final afterCheck = after.checks.firstWhere(
      (ch) => ch.checkKey == 'open_protocol_divergence_signals',
    );
    expect(afterCheck.status, 'review_needed');
  });

  // ── INV-6 ─────────────────────────────────────────────────────────────────

  test(
      'INV-6: trialInterpretationRiskProvider streams coherence timing changes without invalidation',
      () async {
    final trialId = await makeTrial(crop: 'Wheat');
    await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    final treatmentId = await makeTreatment(trialId);
    await makeTreatmentComponent(
      trialId,
      treatmentId,
      pesticideCategory: 'herbicide',
    );
    final c = makeContainer();

    final before = await c.read(trialInterpretationRiskProvider(trialId).future);
    final beforeTiming = before.factors.firstWhere(
      (f) => f.factorKey == 'application_timing_deviation',
    );
    expect(beforeTiming.severity, 'cannot_evaluate');

    final updated = Completer<TrialInterpretationRiskDto>();
    final sub = c.listen(trialInterpretationRiskProvider(trialId), (_, next) {
      next.whenData((dto) {
        final timing = dto.factors.firstWhere(
          (f) => f.factorKey == 'application_timing_deviation',
        );
        if (timing.severity == 'moderate' && !updated.isCompleted) {
          updated.complete(dto);
        }
      });
    });
    addTearDown(sub.close);

    await makeApplicationWithBbch(trialId, bbch: 32);

    final after = await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () =>
          fail('trialInterpretationRiskProvider did not emit timing risk'),
    );
    final afterTiming = after.factors.firstWhere(
      (f) => f.factorKey == 'application_timing_deviation',
    );
    expect(afterTiming.severity, 'moderate');
  });

  // ── INV-7 ─────────────────────────────────────────────────────────────────
  //
  // Tests watchDecisionEventsForTrial at the repository layer — the specific
  // code changed in scope 1.  We write directly into signalDecisionEvents
  // (bypassing recordDecisionEvent so the signals table is NOT touched) to
  // isolate the signalDecisionEvents watch path.  Testing via the Riverpod
  // provider is impractical here: autoDispose + the 10-stream initial burst
  // from mergeTableWatchStreams makes emission counting unreliable.

  test(
      'INV-7: watchDecisionEventsForTrial does not emit for other-trial decision events',
      () async {
    final trialAId = await makeTrial();
    final trialBId = await makeTrial();

    // Signal belongs to trial A only.
    final signalAId = await db.into(db.signals).insert(
          SignalsCompanion.insert(
            trialId: trialAId,
            signalType: 'scale_violation',
            moment: 1,
            severity: 'warning',
            raisedAt: 0,
            referenceContext: '{}',
            consequenceText: 'Test.',
            status: const Value('open'),
            createdAt: 0,
          ),
        );

    final repo = SignalRepository.attach(db);

    // Subscribe to trial B's scoped stream — capture every emission.
    final trialBValues = <List<SignalDecisionEvent>>[];
    final initB = Completer<void>();
    final subB = repo.watchDecisionEventsForTrial(trialBId).listen((events) {
      trialBValues.add(events);
      if (!initB.isCompleted) initB.complete();
    });
    addTearDown(subB.cancel);

    // Also subscribe to trial A — to confirm the write was processed.
    final trialAReceived = Completer<List<SignalDecisionEvent>>();
    final subA = repo.watchDecisionEventsForTrial(trialAId).listen((events) {
      if (events.isNotEmpty && !trialAReceived.isCompleted) {
        trialAReceived.complete(events);
      }
    });
    addTearDown(subA.cancel);

    // Wait for trial B's initial (empty) emission.
    await initB.future.timeout(const Duration(seconds: 2));
    final countBefore = trialBValues.length;

    // Write decision event for trial A's signal — no signals table update.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.signalDecisionEvents).insert(
          SignalDecisionEventsCompanion.insert(
            signalId: signalAId,
            eventType: SignalDecisionEventType.defer.dbValue,
            occurredAt: now,
            resultingStatus: SignalStatus.deferred.dbValue,
            createdAt: now,
          ),
        );

    // Confirm trial A's stream saw the new event.
    await trialAReceived.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail(
          'watchDecisionEventsForTrial(A) did not emit after decision event insert'),
    );

    // Allow extra time for any spurious trial B emission.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      trialBValues.length,
      countBefore,
      reason:
          'watchDecisionEventsForTrial(B) must not emit for a trial-A decision event',
    );
  });

  // ── INV-8 ─────────────────────────────────────────────────────────────────

  test(
      'INV-8: watchDecisionEventsForTrial emits when same-trial decision event is written',
      () async {
    final trialId = await makeTrial();

    final signalId = await db.into(db.signals).insert(
          SignalsCompanion.insert(
            trialId: trialId,
            signalType: 'scale_violation',
            moment: 1,
            severity: 'warning',
            raisedAt: 0,
            referenceContext: '{}',
            consequenceText: 'Test.',
            status: const Value('open'),
            createdAt: 0,
          ),
        );

    final repo = SignalRepository.attach(db);

    // Skip the first emission (initial empty list); wait for the non-empty one.
    bool initialized = false;
    final received = Completer<List<SignalDecisionEvent>>();
    final sub = repo.watchDecisionEventsForTrial(trialId).listen((events) {
      if (!initialized) {
        initialized = true;
        return;
      }
      if (events.isNotEmpty && !received.isCompleted) received.complete(events);
    });
    addTearDown(sub.cancel);

    // Allow initial emission to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Write decision event for the same trial's signal.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.signalDecisionEvents).insert(
          SignalDecisionEventsCompanion.insert(
            signalId: signalId,
            eventType: SignalDecisionEventType.defer.dbValue,
            occurredAt: now,
            resultingStatus: SignalStatus.deferred.dbValue,
            createdAt: now,
          ),
        );

    final events = await received.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail(
          'watchDecisionEventsForTrial did not emit after same-trial decision event'),
    );

    expect(events, hasLength(1));
    expect(events.first.signalId, signalId);
  });
}
