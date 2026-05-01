import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/timing_window_violation_writer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seed scaffold: trial (efficacy) + session + plot.
Future<({int trialId, int sessionId, int plotPk})> _seedScaffold(
    AppDatabase db) async {
  final trialId = await db.into(db.trials).insert(
        TrialsCompanion.insert(
          name: 'TW Test',
          workspaceType: const Value('efficacy'),
        ),
      );
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-06-10',
        ),
      );
  final plotPk = await db.into(db.plots).insert(
        PlotsCompanion.insert(trialId: trialId, plotId: 'P1'),
      );
  return (trialId: trialId, sessionId: sessionId, plotPk: plotPk);
}

/// Creates AssessmentDefinitions → TrialAssessments → ArmAssessmentMetadata
/// chain and returns the trialAssessmentId.
Future<int> _seedArmChain(
  AppDatabase db, {
  required int trialId,
  required String ratingType,
}) async {
  final defId = await db.into(db.assessmentDefinitions).insert(
        AssessmentDefinitionsCompanion.insert(
          code: 'TST',
          name: 'Test',
          category: 'pest',
        ),
      );
  final taId = await db.into(db.trialAssessments).insert(
        TrialAssessmentsCompanion.insert(
          trialId: trialId,
          assessmentDefinitionId: defId,
        ),
      );
  await db.into(db.armAssessmentMetadata).insert(
        ArmAssessmentMetadataCompanion.insert(
          trialAssessmentId: taId,
          ratingType: Value(ratingType),
        ),
      );
  return taId;
}

Future<int> _seedAssessment(AppDatabase db, int trialId) =>
    db.into(db.assessments).insert(
          AssessmentsCompanion.insert(trialId: trialId, name: 'A'),
        );

Future<int> _seedRating(
  AppDatabase db, {
  required int trialId,
  required int sessionId,
  required int plotPk,
  required int assessmentId,
  required DateTime createdAt,
  int? trialAssessmentId,
}) =>
    db.into(db.ratingRecords).insert(
          RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            createdAt: Value(createdAt),
            trialAssessmentId: trialAssessmentId != null
                ? Value(trialAssessmentId)
                : const Value.absent(),
          ),
        );

Future<void> _seedApplication(
  AppDatabase db, {
  required int trialId,
  required DateTime applicationDate,
  String status = 'applied',
}) =>
    db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion(
            trialId: Value(trialId),
            applicationDate: Value(applicationDate),
            status: Value(status),
          ),
        );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TimingWindowViolationWriter', () {
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

    TimingWindowViolationWriter makeWriter() =>
        TimingWindowViolationWriter(db, container.read(signalRepositoryProvider));

    test('1 — no profile for unknown seType → no signal', () async {
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'UNKNWN');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 5, 27)); // 14 days before

      final result = await makeWriter().checkAndRaise(ratingId: ratingId);

      expect(result, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('2 — in-window timing (CONTRO, 14 days) → no signal', () async {
      // CONTRO efficacy: causalWindowDaysMin=7, causalWindowDaysMax=28
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'CONTRO');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 5, 27)); // 14 days before ✓

      final result = await makeWriter().checkAndRaise(ratingId: ratingId);

      expect(result, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('3 — early timing (CONTRO, 3 days < min 7) → signal raised', () async {
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'CONTRO');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 6, 7)); // 3 days before, < min 7

      final result = await makeWriter().checkAndRaise(ratingId: ratingId);

      expect(result, isNotNull);
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      final sig = signals.single;
      expect(sig.signalType, SignalType.causalContextFlag.dbValue);
      expect(sig.severity, SignalSeverity.review.dbValue);
      expect(sig.moment, SignalMoment.two.dbValue);
      expect(sig.consequenceText, contains('CONTRO'));
      expect(sig.consequenceText, contains('3d'));
      expect(sig.consequenceText, isNot(contains('invalid')));
      expect(sig.consequenceText, isNot(contains('unreliable')));
      expect(sig.consequenceText, isNot(contains('protocol failure')));
    });

    test('4 — late timing (CONTRO, 35 days > max 28) → signal raised', () async {
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'CONTRO');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 5, 6)); // 35 days before, > max 28

      final result = await makeWriter().checkAndRaise(ratingId: ratingId);

      expect(result, isNotNull);
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.causalContextFlag.dbValue);
      expect(signals.single.consequenceText, contains('35d'));
    });

    test('5 — no confirmed application events → no signal', () async {
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'CONTRO');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      // Only a pending application — should not be used for timing
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 5, 27),
          status: 'pending');

      final result = await makeWriter().checkAndRaise(ratingId: ratingId);

      expect(result, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('6 — duplicate run → no duplicate signal, existing id returned',
        () async {
      final s = await _seedScaffold(db);
      final assessmentId = await _seedAssessment(db, s.trialId);
      final taId = await _seedArmChain(db,
          trialId: s.trialId, ratingType: 'CONTRO');
      final ratingId = await _seedRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.plotPk,
          assessmentId: assessmentId,
          createdAt: DateTime.utc(2026, 6, 10),
          trialAssessmentId: taId);
      await _seedApplication(db,
          trialId: s.trialId,
          applicationDate: DateTime.utc(2026, 6, 7)); // 3 days, early

      final writer = makeWriter();
      final first = await writer.checkAndRaise(ratingId: ratingId);
      final second = await writer.checkAndRaise(ratingId: ratingId);

      expect(first, isNotNull);
      expect(first, equals(second));
      expect(await db.select(db.signals).get(), hasLength(1));
    });
  });
}
