import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/rater_drift_writer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<({int trialId, int sessionId, int assessmentId, int p1, int p2})>
    _seedSessionTwoPlots(AppDatabase db, {Value<String>? sessionRaterName}) async {
  final trialId =
      await db.into(db.trials).insert(TrialsCompanion.insert(name: 'RD Test'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-06-10',
          raterName: sessionRaterName ?? const Value.absent(),
        ),
      );
  final assessmentId =
      await db.into(db.assessments).insert(AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'A1',
          ));
  final p1 = await db
      .into(db.plots)
      .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
  final p2 = await db
      .into(db.plots)
      .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P2'));
  return (
    trialId: trialId,
    sessionId: sessionId,
    assessmentId: assessmentId,
    p1: p1,
    p2: p2,
  );
}

Future<int> _insertRating(
  AppDatabase db, {
  required int trialId,
  required int sessionId,
  required int plotPk,
  required int assessmentId,
  String? raterName,
  bool isCurrent = true,
  bool isDeleted = false,
  String resultStatus = 'RECORDED',
}) =>
    db.into(db.ratingRecords).insert(
          RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessmentId,
            sessionId: sessionId,
            resultStatus: Value(resultStatus),
            numericValue: const Value(1.0),
            raterName: raterName != null ? Value(raterName) : const Value.absent(),
            isCurrent: Value(isCurrent),
            isDeleted: Value(isDeleted),
          ),
        );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RaterDriftWriter', () {
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

    RaterDriftWriter makeWriter() =>
        RaterDriftWriter(db, container.read(signalRepositoryProvider));

    test('1 — multiple non-null raterName values → signal', () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId,
          raterName: 'Alice');
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'Bob');

      final id = await makeWriter().checkAndRaiseForSession(sessionId: s.sessionId);

      expect(id, isNotNull);
      final rows = await db.select(db.signals).get();
      expect(rows, hasLength(1));
      expect(rows.single.signalType, SignalType.raterDrift.dbValue);
      expect(rows.single.severity, SignalSeverity.review.dbValue);
      expect(rows.single.moment, SignalMoment.three.dbValue);
      expect(rows.single.consequenceText, contains('"Alice"'));
      expect(rows.single.consequenceText, contains('"Bob"'));
    });

    test('2 — same raterName on all current recorded ratings → no signal',
        () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId,
          raterName: 'Sam');
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'Sam');

      final id = await makeWriter().checkAndRaiseForSession(sessionId: s.sessionId);

      expect(id, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('3 — mixed null + non-null raterName → signal', () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'Pat');

      final id = await makeWriter().checkAndRaiseForSession(sessionId: s.sessionId);

      expect(id, isNotNull);
      expect(await db.select(db.signals).get(), hasLength(1));
      final sig = (await db.select(db.signals).get()).single;
      expect(
        sig.consequenceText,
        contains('Some recorded ratings include a rater name'),
      );
    });

    test('4 — all null raterName + session rater null/absent → no signal',
        () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId);

      final id = await makeWriter().checkAndRaiseForSession(sessionId: s.sessionId);

      expect(id, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('5 — non-current, deleted, non-RECORDED rows ignored', () async {
      final s = await _seedSessionTwoPlots(db);
      final asm2 =
          await db.into(db.assessments).insert(AssessmentsCompanion.insert(
                trialId: s.trialId,
                name: 'A2',
              ));
      // Ignored legacy row (different plot vs counted row below).
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: asm2,
          raterName: 'Zed',
          isCurrent: false);
      // Ignored deleted.
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId,
          raterName: 'Trash',
          isDeleted: true);
      // Ignored VOID.
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: asm2,
          raterName: 'Ghost',
          resultStatus: 'VOID');
      // Sole counted rating.
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'Only');

      final id = await makeWriter().checkAndRaiseForSession(sessionId: s.sessionId);

      expect(id, isNull);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('6 — dedupe blocks duplicate open/deferred/investigating signal',
        () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId,
          raterName: 'A');
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'B');

      final writer = makeWriter();
      final first = await writer.checkAndRaiseForSession(sessionId: s.sessionId);
      final second = await writer.checkAndRaiseForSession(sessionId: s.sessionId);

      expect(first, isNotNull);
      expect(second, first);
      expect(await db.select(db.signals).get(), hasLength(1));

      await container.read(signalRepositoryProvider).recordDecisionEvent(
            signalId: first!,
            eventType: SignalDecisionEventType.defer,
            occurredAt: DateTime.now().millisecondsSinceEpoch,
          );

      final third = await writer.checkAndRaiseForSession(sessionId: s.sessionId);
      expect(third, first);
      expect(await db.select(db.signals).get(), hasLength(1));
    });

    test('7 — resolved signal allows a new signal on next check', () async {
      final s = await _seedSessionTwoPlots(db);
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p1,
          assessmentId: s.assessmentId,
          raterName: 'A');
      await _insertRating(db,
          trialId: s.trialId,
          sessionId: s.sessionId,
          plotPk: s.p2,
          assessmentId: s.assessmentId,
          raterName: 'B');

      final repo = container.read(signalRepositoryProvider);
      final writer = makeWriter();
      final first = await writer.checkAndRaiseForSession(sessionId: s.sessionId);

      await repo.recordDecisionEvent(
        signalId: first!,
        eventType: SignalDecisionEventType.confirm,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
      );

      final second = await writer.checkAndRaiseForSession(sessionId: s.sessionId);
      expect(second, isNotNull);
      expect(second, isNot(equals(first)));

      final all = await db.select(db.signals).get();
      expect(all.length, equals(2));
      expect(all.where((r) => r.status == SignalStatus.resolved.dbValue).length,
          equals(1));
      expect(all.where((r) => r.status == SignalStatus.open.dbValue).length,
          equals(1));
    });
  });
}
