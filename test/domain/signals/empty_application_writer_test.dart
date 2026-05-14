import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/empty_application_writer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _seedTrial(AppDatabase db, {String name = 'EmptyAppTest'}) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: name));

Future<int> _seedPlot(AppDatabase db,
    {required int trialId, required String plotId}) =>
    db.into(db.plots).insert(PlotsCompanion.insert(
          trialId: trialId,
          plotId: plotId,
        ));

Future<String> _seedApplicationEvent(
  AppDatabase db, {
  required int trialId,
  DateTime? applicationDate,
  String status = 'pending',
}) =>
    db.into(db.trialApplicationEvents).insertReturning(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate:
                applicationDate ?? DateTime(2026, 5, 13),
            status: Value(status),
          ),
        ).then((row) => row.id);

Future<void> _assignPlot(
  AppDatabase db, {
  required String applicationEventId,
  required String plotLabel,
}) =>
    db.into(db.applicationPlotAssignments).insert(
          ApplicationPlotAssignmentsCompanion.insert(
            applicationEventId: applicationEventId,
            plotLabel: plotLabel,
          ),
        );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EmptyApplicationWriter', () {
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

    test('1 — application with 0 plot assignments → signal raised', () async {
      final trialId = await _seedTrial(db);
      await _seedPlot(db, trialId: trialId, plotId: '101');
      await _seedPlot(db, trialId: trialId, plotId: '102');
      await _seedApplicationEvent(db, trialId: trialId);

      final repo = container.read(signalRepositoryProvider);
      final raised = await EmptyApplicationWriter(db, repo)
          .checkAndRaiseForTrial(trialId: trialId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      final s = signals.single;
      expect(s.signalType, SignalType.emptyApplication.dbValue);
      expect(s.severity, SignalSeverity.critical.dbValue);
      expect(s.moment, SignalMoment.three.dbValue);
      expect(s.sessionId, isNull);
      expect(s.plotId, isNull);
      expect(s.consequenceText, contains('13 May 2026'));
      expect(s.consequenceText, contains('0 of 2 plots'));
      expect(s.consequenceText, contains('assignment was lost'));
      final ctx = SignalReferenceContext.decodeJson(s.referenceContext);
      expect(ctx.reliabilityTier, 'HIGH');
    });

    test('2 — application with N>0 plot assignments → no signal', () async {
      final trialId = await _seedTrial(db);
      await _seedPlot(db, trialId: trialId, plotId: '101');
      final eventId =
          await _seedApplicationEvent(db, trialId: trialId);
      await _assignPlot(db,
          applicationEventId: eventId, plotLabel: '101');

      final repo = container.read(signalRepositoryProvider);
      final raised = await EmptyApplicationWriter(db, repo)
          .checkAndRaiseForTrial(trialId: trialId);

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test('3 — cancelled application → no signal, no crash', () async {
      final trialId = await _seedTrial(db);
      await _seedPlot(db, trialId: trialId, plotId: '101');
      await _seedApplicationEvent(db,
          trialId: trialId, status: 'cancelled');

      final repo = container.read(signalRepositoryProvider);
      final raised = await EmptyApplicationWriter(db, repo)
          .checkAndRaiseForTrial(trialId: trialId);

      expect(raised, isEmpty);
      expect(await db.select(db.signals).get(), isEmpty);
    });

    test(
        '4 — multiple applications, one empty → signal only for the empty one',
        () async {
      final trialId = await _seedTrial(db);
      await _seedPlot(db, trialId: trialId, plotId: '101');
      final eventWithPlots =
          await _seedApplicationEvent(db, trialId: trialId);
      final eventEmpty =
          await _seedApplicationEvent(db, trialId: trialId);
      await _assignPlot(db,
          applicationEventId: eventWithPlots, plotLabel: '101');

      final repo = container.read(signalRepositoryProvider);
      final raised = await EmptyApplicationWriter(db, repo)
          .checkAndRaiseForTrial(trialId: trialId);

      expect(raised, hasLength(1));
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      final ctx =
          SignalReferenceContext.decodeJson(signals.single.referenceContext);
      expect(ctx.seType, eventEmpty);
    });

    test('5 — dedupe: two calls → one signal, same id returned', () async {
      final trialId = await _seedTrial(db);
      await _seedPlot(db, trialId: trialId, plotId: '101');
      await _seedApplicationEvent(db, trialId: trialId);

      final repo = container.read(signalRepositoryProvider);
      final writer = EmptyApplicationWriter(db, repo);

      final first =
          await writer.checkAndRaiseForTrial(trialId: trialId);
      final second =
          await writer.checkAndRaiseForTrial(trialId: trialId);

      final allSignals = await db.select(db.signals).get();
      expect(allSignals, hasLength(1));
      expect(first, equals(second));
    });

    test(
        '6 — two trials with empty applications → signals raised per trial independently',
        () async {
      final trial1 = await _seedTrial(db, name: 'Trial A');
      final trial2 = await _seedTrial(db, name: 'Trial B');
      await _seedPlot(db, trialId: trial1, plotId: '101');
      await _seedPlot(db, trialId: trial2, plotId: '201');
      await _seedApplicationEvent(db, trialId: trial1);
      await _seedApplicationEvent(db, trialId: trial2);

      final repo = container.read(signalRepositoryProvider);
      final writer = EmptyApplicationWriter(db, repo);

      final r1 = await writer.checkAndRaiseForTrial(trialId: trial1);
      final r2 = await writer.checkAndRaiseForTrial(trialId: trial2);

      expect(r1, hasLength(1));
      expect(r2, hasLength(1));
      expect(r1.single, isNot(equals(r2.single)));
      final allSignals = await db.select(db.signals).get();
      expect(allSignals, hasLength(2));
      final trialIds = allSignals.map((s) => s.trialId).toSet();
      expect(trialIds, containsAll([trial1, trial2]));
    });
  });
}
