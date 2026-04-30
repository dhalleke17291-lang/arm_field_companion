// Scenario-level tests for AovErrorVarianceWriter + ReplicationWarningWriter
// running together against a shared in-memory database.
//
// Each scenario exercises a realistic session state and asserts the combined
// signal output, catching problems that per-writer unit tests cannot see.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/aov_error_variance_writer.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/replication_warning_writer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<({int trialId, int sessionId})> _seedSession(AppDatabase db) async {
  final trialId = await db
      .into(db.trials)
      .insert(TrialsCompanion.insert(name: 'ScenTest'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-04-29',
        ),
      );
  return (trialId: trialId, sessionId: sessionId);
}

Future<int> _addTreatment(AppDatabase db,
        {required int trialId,
        required String code,
        required String name}) =>
    db.into(db.treatments).insert(
          TreatmentsCompanion.insert(trialId: trialId, code: code, name: name),
        );

Future<int> _addPlot(AppDatabase db,
        {required int trialId,
        required int treatmentId,
        required String plotId}) =>
    db.into(db.plots).insert(PlotsCompanion.insert(
          trialId: trialId,
          plotId: plotId,
          treatmentId: Value(treatmentId),
        ));

Future<int> _addAssessment(AppDatabase db,
    {required int trialId,
    required int sessionId,
    required String name}) async {
  final assessmentId = await db
      .into(db.assessments)
      .insert(AssessmentsCompanion.insert(trialId: trialId, name: name));
  await db.into(db.sessionAssessments).insert(
        SessionAssessmentsCompanion.insert(
          sessionId: sessionId,
          assessmentId: assessmentId,
        ),
      );
  return assessmentId;
}

Future<void> _addRating(AppDatabase db,
    {required int trialId,
    required int sessionId,
    required int plotPk,
    required int assessmentId,
    required double value}) async {
  await db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        numericValue: Value(value),
      ));
}

Future<({List<int> aov, List<int> rep})> _runWriters(
  AppDatabase db,
  SignalRepository repo,
  int trialId,
  int sessionId,
) async {
  final aov = await AovErrorVarianceWriter(db, repo)
      .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
  final rep = await ReplicationWarningWriter(db, repo)
      .checkAndRaiseForSession(trialId: trialId, sessionId: sessionId);
  return (aov: aov, rep: rep);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Session-close signal scenarios', () {
    late AppDatabase db;
    late ProviderContainer container;
    late SignalRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      repo = container.read(signalRepositoryProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    // ── Scenario 1: clean complete session ───────────────────────────────────

    test(
        '1 — clean complete session: ≥3 distinct values per treatment → zero signals',
        () async {
      final seed = await _seedSession(db);
      final tId = await _addTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide A');
      final asmId = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W003');
      final p1 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      final p3 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '103');
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmId,
          value: 10.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: asmId,
          value: 20.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p3,
          assessmentId: asmId,
          value: 30.0);

      final result = await _runWriters(db, repo, seed.trialId, seed.sessionId);

      expect(result.aov, isEmpty,
          reason: 'distinct values — no AOV signal expected');
      expect(result.rep, isEmpty,
          reason: '3 rated plots — no replication signal expected');
      expect(await db.select(db.signals).get(), isEmpty);
    });

    // ── Scenario 2: partial session ──────────────────────────────────────────

    test(
        '2 — partial session: T1 rated (1 plot), T2 unrated → replication for T1 only',
        () async {
      final seed = await _seedSession(db);
      final t1 = await _addTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide A');
      final t2 = await _addTreatment(db,
          trialId: seed.trialId, code: 'T2', name: 'Control');
      final asmId = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W003');
      final p1 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: t1, plotId: '101');
      await _addPlot(db,
          trialId: seed.trialId, treatmentId: t2, plotId: '201');
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmId,
          value: 50.0);

      final result = await _runWriters(db, repo, seed.trialId, seed.sessionId);

      expect(result.aov, isEmpty,
          reason: 'only 1 rating per treatment group — AOV skips');
      expect(result.rep, hasLength(1),
          reason: 'T1 has 1 rated plot → critical replication signal');
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.replicationWarning.dbValue);
      expect(signals.single.severity, SignalSeverity.critical.dbValue);
    });

    // ── Scenario 3: AOV + replication in same session ────────────────────────

    test(
        '3 — 2 plots, identical value → AOV critical + replication review both raised',
        () async {
      final seed = await _seedSession(db);
      final tId = await _addTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Herbicide B');
      final asmId = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W003');
      final p1 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmId,
          value: 75.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: asmId,
          value: 75.0);

      final result = await _runWriters(db, repo, seed.trialId, seed.sessionId);

      expect(result.aov, hasLength(1), reason: 'identical values → AOV critical');
      expect(result.rep, hasLength(1), reason: '2 plots → replication review');
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(2));
      final types = signals.map((s) => s.signalType).toSet();
      expect(types, containsAll({
        SignalType.aovPrediction.dbValue,
        SignalType.replicationWarning.dbValue,
      }));
    });

    // ── Scenario 4: multi-assessment AOV ────────────────────────────────────

    test(
        '4 — assessment A identical, B distinct → only A fires an AOV signal',
        () async {
      final seed = await _seedSession(db);
      final tId = await _addTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Fungicide C');
      final asmA = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W003');
      final asmB = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W004');
      final p1 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      // Assessment A: identical values → AOV fires.
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmA,
          value: 50.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: asmA,
          value: 50.0);
      // Assessment B: distinct values → AOV silent.
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmB,
          value: 30.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: asmB,
          value: 70.0);

      final result = await _runWriters(db, repo, seed.trialId, seed.sessionId);

      expect(result.aov, hasLength(1), reason: 'only assessment A triggers AOV');
      final aovSignal = (await db.select(db.signals).get())
          .firstWhere((s) => s.signalType == SignalType.aovPrediction.dbValue);
      expect(aovSignal.consequenceText, contains('W003'),
          reason: 'consequence text names assessment A');
      expect(aovSignal.consequenceText, isNot(contains('W004')));
    });

    // ── Scenario 5: re-run idempotency ───────────────────────────────────────

    test('5 — re-running both writers does not add new signal rows', () async {
      final seed = await _seedSession(db);
      final tId = await _addTreatment(db,
          trialId: seed.trialId, code: 'T1', name: 'Control');
      final asmId = await _addAssessment(db,
          trialId: seed.trialId, sessionId: seed.sessionId, name: 'W003');
      final p1 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _addPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: asmId,
          value: 60.0);
      await _addRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: asmId,
          value: 60.0);

      final first = await _runWriters(db, repo, seed.trialId, seed.sessionId);
      final countAfterFirst = (await db.select(db.signals).get()).length;

      final second = await _runWriters(db, repo, seed.trialId, seed.sessionId);
      final countAfterSecond = (await db.select(db.signals).get()).length;

      expect(countAfterSecond, equals(countAfterFirst),
          reason: 'second run must not create new signal rows');
      expect(first.aov, equals(second.aov),
          reason: 'AOV returns same signal id on re-run');
      expect(first.rep, equals(second.rep),
          reason: 'replication returns same signal id on re-run');
    });
  });
}
