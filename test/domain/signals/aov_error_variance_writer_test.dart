import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/aov_error_variance_writer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<({int trialId, int sessionId, int assessmentId})> _seedBasicTrial(
    AppDatabase db) async {
  final trialId =
      await db.into(db.trials).insert(TrialsCompanion.insert(name: 'AovTest'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-04-28',
        ),
      );
  final assessmentId = await db
      .into(db.assessments)
      .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'W003'));
  await db.into(db.sessionAssessments).insert(
        SessionAssessmentsCompanion.insert(
          sessionId: sessionId,
          assessmentId: assessmentId,
        ),
      );
  return (trialId: trialId, sessionId: sessionId, assessmentId: assessmentId);
}

Future<int> _insertPlot(AppDatabase db,
    {required int trialId,
    required int treatmentId,
    required String plotId}) async {
  return db.into(db.plots).insert(PlotsCompanion.insert(
        trialId: trialId,
        plotId: plotId,
        treatmentId: Value(treatmentId),
      ));
}

Future<void> _insertRating(
  AppDatabase db, {
  required int trialId,
  required int sessionId,
  required int plotPk,
  required int assessmentId,
  required double value,
}) async {
  await db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        numericValue: Value(value),
      ));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AovErrorVarianceWriter', () {
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

    test('1 — identical values in treatment group → aovPrediction signal raised',
        () async {
      final seed = await _seedBasicTrial(db);
      final tId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: seed.trialId, code: 'T1', name: 'Fungicide A'),
          );
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: seed.assessmentId,
          value: 75.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: seed.assessmentId,
          value: 75.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await AovErrorVarianceWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.aovPrediction.dbValue);
      expect(signals.single.severity, SignalSeverity.critical.dbValue);
      expect(signals.single.moment, SignalMoment.three.dbValue);
      expect(signals.single.plotId, isNull);
      expect(signals.single.consequenceText, contains('Fungicide A'));
      expect(signals.single.consequenceText, contains('W003'));
    });

    test('2 — different values in treatment group → no signal raised', () async {
      final seed = await _seedBasicTrial(db);
      final tId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: seed.trialId, code: 'T1', name: 'Fungicide A'),
          );
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: seed.assessmentId,
          value: 70.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: seed.assessmentId,
          value: 85.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await AovErrorVarianceWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('3 — only one rated plot in treatment group → no signal raised',
        () async {
      final seed = await _seedBasicTrial(db);
      final tId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: seed.trialId, code: 'T1', name: 'Fungicide A'),
          );
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: seed.assessmentId,
          value: 75.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await AovErrorVarianceWriter(db, repo)
          .checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      expect(raised, isEmpty);
    });

    test('4 — duplicate call → no new signal, existing id returned', () async {
      final seed = await _seedBasicTrial(db);
      final tId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: seed.trialId, code: 'T1', name: 'Fungicide A'),
          );
      final p1 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '101');
      final p2 = await _insertPlot(db,
          trialId: seed.trialId, treatmentId: tId, plotId: '102');
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p1,
          assessmentId: seed.assessmentId,
          value: 75.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: p2,
          assessmentId: seed.assessmentId,
          value: 75.0);

      final repo = container.read(signalRepositoryProvider);
      final writer = AovErrorVarianceWriter(db, repo);

      final first =
          await writer.checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);
      final second =
          await writer.checkAndRaiseForSession(
              trialId: seed.trialId, sessionId: seed.sessionId);

      final allSignals = await db.select(db.signals).get();
      expect(allSignals, hasLength(1));
      expect(first, equals(second));
    });
  });
}
