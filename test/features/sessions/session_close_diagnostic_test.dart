import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
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
  });
}
