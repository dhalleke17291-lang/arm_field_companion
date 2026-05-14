import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/replication_warning_writer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<({int trialId, int sessionId})> _seedSession(AppDatabase db) async {
  final trialId = await db
      .into(db.trials)
      .insert(TrialsCompanion.insert(name: 'RepTest'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-04-28',
        ),
      );
  return (trialId: trialId, sessionId: sessionId);
}

Future<int> _insertTreatment(AppDatabase db,
    {required int trialId, required String code, required String name}) =>
    db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
              trialId: trialId, code: code, name: name),
        );

Future<int> _insertPlot(AppDatabase db,
    {required int trialId,
    required int treatmentId,
    required String plotId}) =>
    db.into(db.plots).insert(PlotsCompanion.insert(
          trialId: trialId,
          plotId: plotId,
          treatmentId: Value(treatmentId),
        ));

Future<void> _insertRating(AppDatabase db,
    {required int trialId,
    required int sessionId,
    required int plotPk,
    required int assessmentId}) async {
  await db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
      ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReplicationWarningWriter', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('1 — treatment with 1 rated plot → critical signal raised', () async {
      final seed = await _seedSession(db);
      final tId = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Control');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.replicationWarning.dbValue);
      expect(signals.single.severity, SignalSeverity.critical.dbValue);
      expect(signals.single.moment, SignalMoment.three.dbValue);
      expect(signals.single.plotId, isNull);
      expect(signals.single.consequenceText, contains('Control'));
      expect(signals.single.consequenceText, contains('1'));
      final ctx =
          SignalReferenceContext.decodeJson(signals.single.referenceContext);
      expect(ctx.reliabilityTier, 'HIGH');
    });

    test('2 — treatment with 2 rated plots → review signal raised', () async {
      final seed = await _seedSession(db);
      final tId = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Herbicide B');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: assessmentId);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals.single.severity, SignalSeverity.review.dbValue);
    });

    test('3 — treatment with 3 rated plots → no signal raised', () async {
      final seed = await _seedSession(db);
      final tId = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide C');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      for (var i = 1; i <= 3; i++) {
        final pk = await _insertPlot(db,
            trialId: seed.trialId, treatmentId: tId, plotId: '10$i');
        await _insertRating(db,
            trialId: seed.trialId,
            sessionId: seed.sessionId,
            plotPk: pk,
            assessmentId: assessmentId);
      }

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('5 — empty session (no rated plots) → returns [], no signals raised',
        () async {
      final seed = await _seedSession(db);
      await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Control');

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('4 — duplicate call → no new signal, existing id returned', () async {
      final seed = await _seedSession(db);
      final tId = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Control');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      final writer = ReplicationWarningWriter(db, repo);

      final first = await writer.checkAndRaiseForSession(
          trialId: seed.trialId, sessionId: seed.sessionId);
      final second = await writer.checkAndRaiseForSession(
          trialId: seed.trialId, sessionId: seed.sessionId);

      final allSignals = await db.select(db.signals).get();
      expect(allSignals, hasLength(1));
      expect(first, equals(second));
    });

    test(
        '6 — T1 rated (1 plot), T2 unrated → signal for T1 only, T2 skipped',
        () async {
      final seed = await _seedSession(db);
      final t1 = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide');
      final t2 = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T2', name: 'Untreated');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: t1, plotId: '101');
      // T2 has an assigned plot but no rating this session.
      await _insertPlot(db,
          trialId: seed.trialId, treatmentId: t2, plotId: '201');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      // Only T1 (started but under-replicated) gets a signal; T2 is skipped.
      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      final ctx = SignalReferenceContext.decodeJson(
          signals.single.referenceContext);
      expect(ctx.treatmentId, t1);
    });

    test(
        '7 — T1 fully replicated (3 plots), T2 partial (1 plot) → only T2 gets signal',
        () async {
      final seed = await _seedSession(db);
      final t1 = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide');
      final t2 = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T2', name: 'Untreated');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      // T1: 3 rated plots — no signal.
      for (var i = 1; i <= 3; i++) {
        final pk = await _insertPlot(db,
            trialId: seed.trialId, treatmentId: t1, plotId: '10$i');
        await _insertRating(db,
            trialId: seed.trialId,
            sessionId: seed.sessionId,
            plotPk: pk,
            assessmentId: assessmentId);
      }
      // T2: 1 rated plot — critical signal.
      final p2 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: t2, plotId: '201');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      final raised = await ReplicationWarningWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.severity, SignalSeverity.critical.dbValue);
      final ctx = SignalReferenceContext.decodeJson(
          signals.single.referenceContext);
      expect(ctx.treatmentId, t2);
    });

    test('8 — consequence text contains no ARM-specific language', () async {
      final seed = await _seedSession(db);
      final tId = await _insertTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide A');
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(
              trialId: seed.trialId, name: 'W003'));
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: assessmentId);

      final repo = container.read(signalRepositoryProvider);
      await ReplicationWarningWriter(db, repo).checkAndRaiseForSession(
          trialId: seed.trialId, sessionId: seed.sessionId);

      final signal = (await db.select(db.signals).get()).single;
      final text = signal.consequenceText.toLowerCase();
      expect(text, isNot(contains('arm')),
          reason: 'consequence text must not mention ARM software');
    });
  });
}
