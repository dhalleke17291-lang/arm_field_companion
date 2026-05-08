import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/features/sessions/interpretation_factors_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Pure logic ──────────────────────────────────────────────────────────────

void main() {
  group('shouldShowInterpretationFactorsPrompt', () {
    test('no sessions + null factors → show prompt', () {
      expect(
        shouldShowInterpretationFactorsPrompt(
          existingSessionCount: 0,
          knownInterpretationFactors: null,
        ),
        isTrue,
      );
    });

    test('no sessions + non-null factors (answered) → suppress', () {
      expect(
        shouldShowInterpretationFactorsPrompt(
          existingSessionCount: 0,
          knownInterpretationFactors: '[]',
        ),
        isFalse,
      );
    });

    test('one existing session + null factors → suppress (not first session)', () {
      expect(
        shouldShowInterpretationFactorsPrompt(
          existingSessionCount: 1,
          knownInterpretationFactors: null,
        ),
        isFalse,
      );
    });

    test('multiple existing sessions + null factors → suppress', () {
      expect(
        shouldShowInterpretationFactorsPrompt(
          existingSessionCount: 5,
          knownInterpretationFactors: null,
        ),
        isFalse,
      );
    });

    test('factors with actual keys → suppress', () {
      expect(
        shouldShowInterpretationFactorsPrompt(
          existingSessionCount: 0,
          knownInterpretationFactors:
              InterpretationFactorsCodec.serialize(['drought_stress']),
        ),
        isFalse,
      );
    });
  });

  // ── Codec invariants (sheet-relevant write-path) ─────────────────────────

  group('InterpretationFactorsCodec — sheet write-path', () {
    test('None of the above writes empty array, not null', () {
      final json = InterpretationFactorsCodec.serialize([]);
      expect(json, '[]');
      final result = InterpretationFactorsCodec.parse(json)!;
      expect(result.noneSelected, isTrue);
      expect(result.wasAnswered, isTrue);
    });

    test('selecting multiple factors writes expected JSON', () {
      final json = InterpretationFactorsCodec.serialize(
        ['drought_stress', 'frost_risk', 'atypical_season'],
      );
      final result = InterpretationFactorsCodec.parse(json)!;
      expect(result.selectedKeys,
          containsAll(['drought_stress', 'frost_risk', 'atypical_season']));
      expect(result.selectedKeys.length, 3);
    });

    test('Other with trimmed text writes {"other":"..."} object', () {
      final json = InterpretationFactorsCodec.serialize(
        [],
        otherText: '  Unexpected flooding  ',
      );
      final result = InterpretationFactorsCodec.parse(json)!;
      expect(result.otherText, 'Unexpected flooding');
    });

    test('Other with empty string after trim does not write other object', () {
      final json = InterpretationFactorsCodec.serialize(
        [],
        otherText: '   ',
      );
      final result = InterpretationFactorsCodec.parse(json)!;
      expect(result.otherText, isNull);
      expect(result.noneSelected, isTrue);
    });

    test('Other text is clamped to 200 characters', () {
      final long = 'x' * 300;
      final json = InterpretationFactorsCodec.serialize([], otherText: long);
      final result = InterpretationFactorsCodec.parse(json)!;
      expect(result.otherText!.length, 200);
    });
  });

  // ── Widget tests ─────────────────────────────────────────────────────────

  Widget buildHarness({
    required Future<void> Function(String?) onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              final result = await showInterpretationFactorsSheet(ctx);
              await onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('sheet renders all 10 factor options', (tester) async {
    await tester.pumpWidget(buildHarness(onResult: (_) async {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final label in kInterpretationFactorLabels.values) {
      expect(find.text(label, skipOffstage: false), findsOneWidget,
          reason: 'Expected factor "$label" to be in the tree');
    }
  });

  testWidgets('None of the above returns empty-array JSON', (tester) async {
    String? captured;
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('None of the above'));
    await tester.pumpAndSettle();

    expect(captured, '[]');
  });

  testWidgets('Done with no selection returns empty-array JSON', (tester) async {
    String? captured;
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(captured, '[]');
  });

  testWidgets('selecting factors and pressing Done returns correct JSON',
      (tester) async {
    String? captured;
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('factor_drought_stress')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('factor_frost_risk')));
    await tester.pump();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    final result = InterpretationFactorsCodec.parse(captured)!;
    expect(result.selectedKeys, containsAll(['drought_stress', 'frost_risk']));
  });

  testWidgets('selecting Other reveals text field', (tester) async {
    await tester.pumpWidget(buildHarness(onResult: (_) async {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('factor_other')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('factor_other')));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Other with text writes other object in JSON', (tester) async {
    String? captured;
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('factor_other')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('factor_other')));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hail damage on NW corner');
    await tester.pump();

    // "Done" button may have scrolled off-screen after TextField appeared;
    // use skipOffstage: false to tap it regardless.
    await tester.tap(find.text('Done', skipOffstage: false));
    await tester.pumpAndSettle();

    final result = InterpretationFactorsCodec.parse(captured)!;
    expect(result.otherText, 'Hail damage on NW corner');
  });

  testWidgets('Other checked but empty text does not write other object',
      (tester) async {
    String? captured;
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('factor_other')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('factor_other')));
    await tester.pump();
    // TextField left empty.
    await tester.tap(find.text('Done', skipOffstage: false));
    await tester.pumpAndSettle();

    final result = InterpretationFactorsCodec.parse(captured)!;
    expect(result.otherText, isNull);
    expect(result.noneSelected, isTrue);
  });

  testWidgets('dismissing sheet without action returns null', (tester) async {
    String? captured = 'sentinel';
    await tester.pumpWidget(buildHarness(onResult: (r) async => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the scrim to dismiss the bottom sheet.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });
}
