import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/domain/signals/se_type_causal_profile_provider.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/aov_error_variance_writer.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/replication_warning_writer.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/scale_violation_writer.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(AppDatabase db) => ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

Future<int> _trial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'SigTrial'));

Future<int> _session(AppDatabase db, int trialId) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S',
            sessionDateLocal: '2026-04-01',
          ),
        );

Future<int> _plot(AppDatabase db, int trialId) =>
    db.into(db.plots).insert(
          PlotsCompanion.insert(trialId: trialId, plotId: 'PL1'),
        );

void main() {
  group('SignalRepository', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = _container(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('raiseSignal creates signal with status open', () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);

      final repo = container.read(signalRepositoryProvider);
      final id = await repo.raiseSignal(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        signalType: SignalType.exportPreflight,
        moment: SignalMoment.five,
        severity: SignalSeverity.info,
        referenceContext: const SignalReferenceContext(seType: 'CONTRO'),
        consequenceText: 'c',
      );

      final row =
          await (db.select(db.signals)..where((s) => s.id.equals(id))).getSingle();
      expect(row.status, SignalStatus.open.dbValue);
    });

    test('recordDecisionEvent confirm updates signal status to resolved',
        () async {
      final trialId = await _trial(db);
      final repo = container.read(signalRepositoryProvider);
      final id = await repo.raiseSignal(
        trialId: trialId,
        signalType: SignalType.deviationDeclaration,
        moment: SignalMoment.two,
        severity: SignalSeverity.review,
        referenceContext: const SignalReferenceContext(),
        consequenceText: 'x',
      );

      await repo.recordDecisionEvent(
        signalId: id,
        eventType: SignalDecisionEventType.confirm,
        occurredAt: 1000,
      );

      final row =
          await (db.select(db.signals)..where((s) => s.id.equals(id))).getSingle();
      expect(row.status, SignalStatus.resolved.dbValue);
    });

    test(
        'defer then confirm: statuses transition and history preserves both '
        'events in chronological order',
        () async {
      final trialId = await _trial(db);
      final repo = container.read(signalRepositoryProvider);
      final id = await repo.raiseSignal(
        trialId: trialId,
        signalType: SignalType.protocolDivergence,
        moment: SignalMoment.three,
        severity: SignalSeverity.critical,
        referenceContext: const SignalReferenceContext(),
        consequenceText: 'y',
      );

      await repo.recordDecisionEvent(
        signalId: id,
        eventType: SignalDecisionEventType.defer,
        occurredAt: 500,
      );
      expect(
        (await (db.select(db.signals)..where((s) => s.id.equals(id))).getSingle())
            .status,
        SignalStatus.deferred.dbValue,
      );

      await repo.recordDecisionEvent(
        signalId: id,
        eventType: SignalDecisionEventType.confirm,
        occurredAt: 900,
      );
      expect(
        (await (db.select(db.signals)..where((s) => s.id.equals(id))).getSingle())
            .status,
        SignalStatus.resolved.dbValue,
      );

      final hist = await repo.getDecisionHistory(id);
      expect(hist.length, 2);
      expect(hist[0].eventType, SignalDecisionEventType.defer.dbValue);
      expect(hist[1].eventType, SignalDecisionEventType.confirm.dbValue);
    });

    test('closing trial expires unresolved signals via TrialRepository', () async {
      final trialId = await _trial(db);
      final repo = container.read(signalRepositoryProvider);
      await repo.raiseSignal(
        trialId: trialId,
        signalType: SignalType.exportPreflight,
        moment: SignalMoment.five,
        severity: SignalSeverity.info,
        referenceContext: const SignalReferenceContext(),
        consequenceText: 'pre-close',
      );

      final trialRepo = TrialRepository(db);
      await trialRepo.updateTrialStatus(trialId, kTrialStatusClosed);

      final rows = await db.select(db.signals).get();
      expect(rows, hasLength(1));
      expect(rows.single.status, SignalStatus.expired.dbValue);

      final events = await repo.getDecisionHistory(rows.single.id);
      expect(events, hasLength(1));
      expect(events.single.eventType, SignalDecisionEventType.expire.dbValue);
    });
  });

  group('ScaleViolationWriter', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = _container(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('value in range returns null', () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      final id = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 50,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'out',
      );
      expect(id, isNull);
    });

    test('value out of range raises signal and returns id', () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      final id = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 101,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'bounds',
      );
      expect(id, isNotNull);

      final row =
          await (db.select(db.signals)..where((s) => s.id.equals(id!))).getSingle();
      expect(row.signalType, SignalType.scaleViolation.dbValue);
      expect(row.status, SignalStatus.open.dbValue);
      final ctx = SignalReferenceContext.decodeJson(row.referenceContext);
      expect(ctx.reliabilityTier, 'HIGH');
    });

    test(
        'second call for same plot/session/assessment returns existing signal id',
        () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      final id1 = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: -1,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'c',
      );
      final id2 = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 200,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO', // same assessment — dedup applies
        consequenceText: 'c2',
      );
      expect(id1, id2);

      final signals = await db.select(db.signals).get();
      expect(signals.length, 1);
    });

    test(
        'different assessment on same plot/session each get their own signal',
        () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      final id1 = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 150,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'contro violation',
      );
      final id2 = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: -5,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'PHYGEN', // different assessment — separate signal
        consequenceText: 'phygen violation',
      );

      expect(id1, isNotNull);
      expect(id2, isNotNull);
      expect(id1, isNot(equals(id2)));

      final signals = await db.select(db.signals).get();
      expect(signals.length, 2);
    });

    test('valid value on same plot after violation does not create new signal',
        () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      // out of range — raises
      await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 150,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'violation',
      );
      // in range — no signal, original violation still open
      final id2 = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 50,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'ok',
      );

      expect(id2, isNull);
      final signals = await db.select(db.signals).get();
      expect(signals.length, 1); // original violation untouched
    });
  });

  group('SeTypeCausalProfileProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = _container(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns seeded CONTRO × efficacy profile', () async {
      final profile = await container.read(
        seTypeCausalProfileProvider(
          const SeTypeProfileKey(seType: 'CONTRO', trialType: 'efficacy'),
        ).future,
      );
      expect(profile, isNotNull);
      expect(profile!.causalWindowDaysMin, 7);
      expect(profile.causalWindowDaysMax, 28);
      expect(profile.expectedResponseDirection, 'increase');
      expect(profile.expectedChangeRatePerWeek, 8.0);
      expect(profile.source, 'EPPO_PP1');
    });

    test('returns null for unknown se_type', () async {
      final profile = await container.read(
        seTypeCausalProfileProvider(
          const SeTypeProfileKey(
              seType: 'UNKNOWN_SE_TYPE_XYZ', trialType: 'efficacy'),
        ).future,
      );
      expect(profile, isNull);
    });
  });

  // ── Session-close writers idempotency ────────────────────────────────────

  group('Session-close writers idempotency', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = _container(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
        'running AOV + replication writers twice produces same signal count',
        () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);

      // Assessment linked to session.
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'W003'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );

      // One treatment, two plots — both rated identically (triggers AOV).
      final tId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: trialId, code: 'T1', name: 'Fungicide'),
          );
      for (final plotId in ['P1', 'P2']) {
        final pk = await db.into(db.plots).insert(
              PlotsCompanion.insert(
                trialId: trialId,
                plotId: plotId,
                treatmentId: Value(tId),
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: pk,
                assessmentId: assessmentId,
                sessionId: sessionId,
                numericValue: const Value(75.0),
              ),
            );
      }

      final repo = container.read(signalRepositoryProvider);

      // First run.
      await AovErrorVarianceWriter(db, repo)
          .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
      await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
      final countAfterFirst = (await db.select(db.signals).get()).length;

      // Second run — simulates diagnostic re-open.
      await AovErrorVarianceWriter(db, repo)
          .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
      await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
      final countAfterSecond = (await db.select(db.signals).get()).length;

      expect(countAfterSecond, countAfterFirst,
          reason: 're-running session-close writers must not create duplicates');
    });
  });

  group('Dedup status alignment', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = _container(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('deferred scale violation blocks a second raise', () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final plotPk = await _plot(db, trialId);
      final repo = container.read(signalRepositoryProvider);
      final writer = ScaleViolationWriter(repo);

      final firstId = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 150,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'violation',
      );
      expect(firstId, isNotNull);

      // Transition to deferred.
      await repo.recordDecisionEvent(
        signalId: firstId!,
        eventType: SignalDecisionEventType.defer,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
      );

      final secondId = await writer.checkAndRaise(
        trialId: trialId,
        sessionId: sessionId,
        plotId: plotPk,
        enteredValue: 200,
        scaleMin: 0,
        scaleMax: 100,
        seType: 'CONTRO',
        consequenceText: 'still violated',
      );

      expect(secondId, equals(firstId));
      expect(await db.select(db.signals).get(), hasLength(1));
    });

    test('investigating AOV signal blocks a second raise', () async {
      final trialId = await _trial(db);
      final sessionId = await _session(db, trialId);
      final repo = container.read(signalRepositoryProvider);

      const seType = 'CONTRO';
      const treatmentId = 42;
      final signalId = await repo.raiseSignal(
        trialId: trialId,
        sessionId: sessionId,
        signalType: SignalType.aovPrediction,
        moment: SignalMoment.two,
        severity: SignalSeverity.review,
        referenceContext: const SignalReferenceContext(
          seType: seType,
          treatmentId: treatmentId,
        ),
        consequenceText: 'aov signal',
      );

      // Transition to investigating.
      await repo.recordDecisionEvent(
        signalId: signalId,
        eventType: SignalDecisionEventType.investigate,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
      );

      final found = await repo.findOpenAovSignalForSessionAssessmentTreatment(
        sessionId: sessionId,
        seType: seType,
        treatmentId: treatmentId,
      );

      expect(found, isNotNull);
      expect(found!.id, signalId);
      expect(found.status, SignalStatus.investigating.dbValue);
    });
  });
}
