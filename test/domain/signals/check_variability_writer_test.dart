import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/check_variability_writer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds a trial with one session, one assessment, one check treatment (CHK),
/// and two check plots. Returns the relevant IDs.
Future<
    ({
      int trialId,
      int sessionId,
      int assessmentId,
      int checkTreatmentId,
      int plot1Pk,
      int plot2Pk,
    })> _seedCheckTrial(AppDatabase db) async {
  final trialId =
      await db.into(db.trials).insert(TrialsCompanion.insert(name: 'CVTest'));
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
  final checkTreatmentId = await db.into(db.treatments).insert(
        TreatmentsCompanion.insert(
          trialId: trialId,
          code: 'CHK',
          name: 'Untreated Check',
        ),
      );
  final plot1Pk = await db.into(db.plots).insert(PlotsCompanion.insert(
        trialId: trialId,
        plotId: '101',
        treatmentId: Value(checkTreatmentId),
      ));
  final plot2Pk = await db.into(db.plots).insert(PlotsCompanion.insert(
        trialId: trialId,
        plotId: '102',
        treatmentId: Value(checkTreatmentId),
      ));
  return (
    trialId: trialId,
    sessionId: sessionId,
    assessmentId: assessmentId,
    checkTreatmentId: checkTreatmentId,
    plot1Pk: plot1Pk,
    plot2Pk: plot2Pk,
  );
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
  group('CheckVariabilityWriter', () {
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

    test(
        '1 — CV > 50 % on check treatment → checkBaselineVariability signal raised',
        () async {
      final seed = await _seedCheckTrial(db);
      // Values: 10.0 and 90.0 → mean=50, SD≈56.57, CV≈113% — well above 50%.
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 10.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 90.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      final s = signals.single;
      expect(s.signalType, SignalType.checkBaselineVariability.dbValue);
      expect(s.severity, SignalSeverity.review.dbValue);
      expect(s.moment, SignalMoment.three.dbValue);
      expect(s.plotId, isNull);
      // Consequence text must include key identifiers.
      expect(s.consequenceText, contains('S1'));
      expect(s.consequenceText, contains('2026'));
      expect(s.consequenceText, contains('Untreated Check'));
      expect(s.consequenceText, contains('W003'));
      expect(s.consequenceText, contains('CV='));
      // reliabilityTier in context.
      final ctx = SignalReferenceContext.decodeJson(s.referenceContext);
      expect(ctx.reliabilityTier, 'MEDIUM');
      expect(ctx.treatmentId, seed.checkTreatmentId);
      expect(ctx.seType, seed.assessmentId.toString());
    });

    test('2 — CV ≤ 50 % on check treatment → no signal raised', () async {
      final seed = await _seedCheckTrial(db);
      // Values: 40.0 and 60.0 → mean=50, SD≈14.14, CV≈28% — below threshold.
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 40.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 60.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('3 — only one rated check plot → no signal raised (< 2 replicates)',
        () async {
      final seed = await _seedCheckTrial(db);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 80.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      expect(raised, isEmpty);
    });

    test(
        '4 — no check treatment in trial → no signal raised and returns empty',
        () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'NoCheck'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-28',
            ),
          );
      // Non-check treatment only.
      await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
              trialId: trialId,
              code: 'T1',
              name: 'Fungicide A',
            ),
          );

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo)
          .checkAndRaiseForAllClosedSessionsAndCurrent(
        trialId: trialId,
        currentSessionId: sessionId,
      );

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('5 — mean is zero → CV undefined, no signal raised', () async {
      final seed = await _seedCheckTrial(db);
      // Both zero → mean=0, CV undefined.
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 0.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 0.0);

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      expect(raised, isEmpty);
    });

    test('6 — duplicate call → no new signal, existing id returned', () async {
      final seed = await _seedCheckTrial(db);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 5.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 95.0);

      final repo = container.read(signalRepositoryProvider);
      final writer = CheckVariabilityWriter(db, repo);

      final first = await writer.checkAndRaiseForSession(
          trialId: seed.trialId, sessionId: seed.sessionId);
      final second = await writer.checkAndRaiseForSession(
          trialId: seed.trialId, sessionId: seed.sessionId);

      final allSignals = await db.select(db.signals).get();
      expect(allSignals, hasLength(1));
      expect(first, equals(second));
    });

    test(
        '7 — UTC code also recognised as check treatment and raises signal',
        () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'UTCTest'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-05-01',
            ),
          );
      final assessmentId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'WC'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );
      final utcId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
              trialId: trialId,
              code: 'UTC',
              name: 'Untreated Control',
            ),
          );
      for (final pid in ['201', '202']) {
        final pk = await db.into(db.plots).insert(PlotsCompanion.insert(
              trialId: trialId,
              plotId: pid,
              treatmentId: Value(utcId),
            ));
        final val = pid == '201' ? 5.0 : 95.0;
        await _insertRating(db,
            trialId: trialId,
            sessionId: sessionId,
            plotPk: pk,
            assessmentId: assessmentId,
            value: val);
      }

      final repo = container.read(signalRepositoryProvider);
      final raised = await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: trialId,
        sessionId: sessionId,
      );

      expect(raised, hasLength(1));
      final s = (await db.select(db.signals).get()).single;
      expect(s.signalType, SignalType.checkBaselineVariability.dbValue);
    });

    test(
        '8 — retroactive scan: closing session 2 raises signal for prior '
        'closed session with high check CV', () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'RetroCV'));
      final s1Id = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
              endedAt: Value(DateTime(2026, 4, 1, 17)),
            ),
          );
      final s2Id = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S2',
              sessionDateLocal: '2026-04-28',
            ),
          );
      final aId = await db
          .into(db.assessments)
          .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'WC'));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
                sessionId: s1Id, assessmentId: aId),
          );
      final chkId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
              trialId: trialId,
              code: 'CHK',
              name: 'Untreated Check',
            ),
          );
      for (final pair in [('301', 5.0), ('302', 95.0)]) {
        final pk = await db.into(db.plots).insert(PlotsCompanion.insert(
              trialId: trialId,
              plotId: pair.$1,
              treatmentId: Value(chkId),
            ));
        await _insertRating(db,
            trialId: trialId,
            sessionId: s1Id,
            plotPk: pk,
            assessmentId: aId,
            value: pair.$2);
      }

      final repo = container.read(signalRepositoryProvider);
      // Closing S2 (no S2 check ratings) — retroactively flags S1.
      final raised = await CheckVariabilityWriter(db, repo)
          .checkAndRaiseForAllClosedSessionsAndCurrent(
        trialId: trialId,
        currentSessionId: s2Id,
      );

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.sessionId, s1Id);
      expect(signals.single.consequenceText, contains('S1'));
      expect(signals.single.consequenceText, contains('1 Apr 2026'));
    });

    test(
        '9 — TrialAssessment displayNameOverride used in consequenceText',
        () async {
      final seed = await _seedCheckTrial(db);
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'CV_TEST_STAND',
              name: 'Stand coverage def',
              category: 'growth',
            ),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: seed.trialId,
              assessmentDefinitionId: defId,
              displayNameOverride: const Value('Stand coverage'),
              legacyAssessmentId: Value(seed.assessmentId),
            ),
          );
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 5.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 95.0);

      final repo = container.read(signalRepositoryProvider);
      await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      final signal = (await db.select(db.signals).get()).single;
      expect(signal.consequenceText, contains('Stand coverage'));
      expect(signal.consequenceText, isNot(contains('— TA')));
    });

    test('10 — consequence text contains no ARM-specific language', () async {
      final seed = await _seedCheckTrial(db);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot1Pk,
          assessmentId: seed.assessmentId,
          value: 5.0);
      await _insertRating(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plot2Pk,
          assessmentId: seed.assessmentId,
          value: 95.0);

      final repo = container.read(signalRepositoryProvider);
      await CheckVariabilityWriter(db, repo).checkAndRaiseForSession(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      final text =
          (await db.select(db.signals).get()).single.consequenceText.toLowerCase();
      expect(text, isNot(contains('arm')),
          reason: 'consequence text must not mention ARM software');
    });
  });
}
