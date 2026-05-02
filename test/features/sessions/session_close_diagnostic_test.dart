import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/features/sessions/widgets/session_close_diagnostic.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Signal _signal({
  required int id,
  required String severity,
  String signalType = 'scale_violation',
  String consequenceText = 'A value was outside the expected range.',
}) {
  return Signal(
    id: id,
    trialId: 1,
    sessionId: 1,
    plotId: 1,
    signalType: signalType,
    moment: 1,
    severity: severity,
    raisedAt: 0,
    referenceContext: '{}',
    consequenceText: consequenceText,
    status: 'open',
    createdAt: 0,
  );
}

Widget _wrap({
  required List<Signal> signals,
  required VoidCallback onAllClear,
  required VoidCallback onProceedAnyway,
  int sessionId = 1,
}) {
  return ProviderScope(
    overrides: [
      openSignalsForSessionProvider(sessionId).overrideWith(
        (_) async => signals,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SessionCloseDiagnostic(
          sessionId: sessionId,
          trialId: 1,
          onAllClear: onAllClear,
          onProceedAnyway: onProceedAnyway,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SessionCloseDiagnostic', () {
    testWidgets('1 — empty signals list → onAllClear called immediately',
        (tester) async {
      var allClearCalled = false;

      await tester.pumpWidget(_wrap(
        signals: [],
        onAllClear: () => allClearCalled = true,
        onProceedAnyway: () {},
      ));
      await tester.pumpAndSettle();

      expect(allClearCalled, isTrue);
      expect(find.text('Before you leave'), findsNothing);
    });

    testWidgets('2 — one critical signal → shown, Close session button present',
        (tester) async {
      var proceedCalled = false;

      await tester.pumpWidget(_wrap(
        signals: [_signal(id: 1, severity: 'critical')],
        onAllClear: () {},
        onProceedAnyway: () => proceedCalled = true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Before you leave'), findsOneWidget);
      expect(find.text('A value was outside the expected range.'), findsOneWidget);
      expect(find.text('Scale check'), findsOneWidget);
      expect(find.text('Close session'), findsOneWidget);
      expect(proceedCalled, isFalse);
    });

    testWidgets(
        '2b — causal_context_flag review → Timing context label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        signals: [
          _signal(
            id: 1,
            severity: 'review',
            signalType: 'causal_context_flag',
            consequenceText: 'Rating timing is outside the window.',
          ),
        ],
        onAllClear: () {},
        onProceedAnyway: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Before you leave'), findsOneWidget);
      expect(find.text('Timing context'), findsOneWidget);
      expect(find.text('Field observation'), findsNothing);
    });

    testWidgets(
        '3 — 1 critical + 4 review → max limits applied, "and 1 more" shown',
        (tester) async {
      final signals = [
        _signal(id: 1, severity: 'critical'),
        _signal(id: 2, severity: 'review', consequenceText: 'R1'),
        _signal(id: 3, severity: 'review', consequenceText: 'R2'),
        _signal(id: 4, severity: 'review', consequenceText: 'R3'),
        _signal(id: 5, severity: 'review', consequenceText: 'R4'), // over limit
      ];

      await tester.pumpWidget(_wrap(
        signals: signals,
        onAllClear: () {},
        onProceedAnyway: () {},
      ));
      await tester.pumpAndSettle();

      // 1 critical + 3 review shown, 4th review hidden
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('R3'), findsOneWidget);
      expect(find.text('R4'), findsNothing);
      expect(
        find.text('and 1 more — review in trial health'),
        findsOneWidget,
      );
    });

    testWidgets('4 — info-only signals → onAllClear called, nothing shown',
        (tester) async {
      var allClearCalled = false;

      await tester.pumpWidget(_wrap(
        signals: [
          _signal(id: 1, severity: 'info'),
          _signal(id: 2, severity: 'info'),
        ],
        onAllClear: () => allClearCalled = true,
        onProceedAnyway: () {},
      ));
      await tester.pumpAndSettle();

      expect(allClearCalled, isTrue);
      expect(find.text('Before you leave'), findsNothing);
    });

    testWidgets(
        '5 — "Review plots" tapped → onProceedAnyway NOT called',
        (tester) async {
      var proceedCalled = false;

      await tester.pumpWidget(_wrap(
        signals: [_signal(id: 1, severity: 'critical')],
        onAllClear: () {},
        onProceedAnyway: () => proceedCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review plots'));
      await tester.pumpAndSettle();

      expect(proceedCalled, isFalse);
    });

    test('6 — logSessionCloseDeferEvents: shown signal → defer event written',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T1'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-28',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));
      final signalId = await db.into(db.signals).insert(
            SignalsCompanion.insert(
              trialId: trialId,
              sessionId: Value(sessionId),
              plotId: Value(plotPk),
              signalType: 'scale_violation',
              moment: 1,
              severity: 'critical',
              raisedAt: 0,
              referenceContext: '{}',
              consequenceText: 'Out of range.',
              status: const Value('open'),
              createdAt: 0,
            ),
          );

      final repo = SignalRepository.attach(db);
      await logSessionCloseDeferEvents(
        repo: repo,
        userId: null,
        shown: [_signal(id: signalId, severity: 'critical')],
        hidden: [],
      );

      final events = await db.select(db.signalDecisionEvents).get();
      expect(events, hasLength(1));
      expect(events.single.signalId, signalId);
      expect(events.single.eventType, 'defer');
      expect(events.single.note, 'Proceeded at session close');
    });

    test(
        '7 — logSessionCloseDeferEvents: hidden signal → defer event with cap note',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T2'));
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-28',
            ),
          );
      final plotPk = await db
          .into(db.plots)
          .insert(PlotsCompanion.insert(trialId: trialId, plotId: 'P1'));

      Future<int> insertSignal(int idx, String severity) => db
          .into(db.signals)
          .insert(SignalsCompanion.insert(
            trialId: trialId,
            sessionId: Value(sessionId),
            plotId: Value(plotPk),
            signalType: 'scale_violation',
            moment: idx,
            severity: severity,
            raisedAt: 0,
            referenceContext: '{}',
            consequenceText: 'Item $idx.',
            status: const Value('open'),
            createdAt: 0,
          ));

      // 1 critical + 4 review → only 3 review shown, 4th is hidden
      final critId = await insertSignal(1, 'critical');
      final r1 = await insertSignal(2, 'review');
      final r2 = await insertSignal(3, 'review');
      final r3 = await insertSignal(4, 'review');
      final r4Hidden = await insertSignal(5, 'review');

      final repo = SignalRepository.attach(db);
      await logSessionCloseDeferEvents(
        repo: repo,
        userId: null,
        shown: [
          _signal(id: critId, severity: 'critical'),
          _signal(id: r1, severity: 'review'),
          _signal(id: r2, severity: 'review'),
          _signal(id: r3, severity: 'review'),
        ],
        hidden: [_signal(id: r4Hidden, severity: 'review')],
      );

      final events = await db.select(db.signalDecisionEvents).get();
      expect(events, hasLength(5));

      final shownNotes =
          events.where((e) => e.note == 'Proceeded at session close').toList();
      final hiddenNotes = events
          .where((e) =>
              e.note == 'Not shown at session close — exceeded display limit')
          .toList();
      expect(shownNotes, hasLength(4));
      expect(hiddenNotes, hasLength(1));
      expect(hiddenNotes.single.signalId, r4Hidden);
    });

    test('8 — logSessionCloseDeferEvents not called → no events written',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Simulate "Review plots" path: logSessionCloseDeferEvents is never
      // called so the decision events table stays empty.
      final events = await db.select(db.signalDecisionEvents).get();
      expect(events, isEmpty);
    });
  });
}
