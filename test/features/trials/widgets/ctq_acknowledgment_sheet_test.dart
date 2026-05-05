import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/features/trials/widgets/ctq_acknowledgment_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kItem = TrialCtqItemDto(
  factorKey: 'plot_completeness',
  label: 'Plot Completeness',
  importance: 'critical',
  status: 'review_needed',
  evidenceSummary: '4/8 plots rated.',
  reason: 'Rating evidence is partial; review before export.',
  source: 'system',
);

Widget _wrap({required AppDatabase db, int trialId = 1}) {
  return ProviderScope(
    overrides: [
      ctqFactorDefinitionRepositoryProvider
          .overrideWith((_) => CtqFactorDefinitionRepository(db)),
      trialCriticalToQualityProvider(trialId).overrideWith(
        (ref) async => const TrialCtqDto(
          trialId: 1,
          ctqItems: [],
          blockerCount: 0,
          warningCount: 0,
          reviewCount: 0,
          satisfiedCount: 0,
          overallStatus: 'unknown',
        ),
      ),
      trialDecisionSummaryProvider(trialId).overrideWith(
        (ref) async => throw UnimplementedError(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showCtqAcknowledgmentSheet(
              ctx,
              item: _kItem,
              trialId: trialId,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Acknowledge'),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Ensure trial row exists for the FK constraint
    await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
  });
  tearDown(() async => db.close());

  group('CtqAcknowledgmentSheet — save button state', () {
    testWidgets('CA-1: empty reason → save disabled', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('CA-2: reason < 10 chars → save disabled', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'short');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('CA-3: reason ≥ 10 chars → save enabled', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'Three plots excluded per protocol.');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('CA-4: sheet shows factor label, status, and evaluator reason',
        (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Plot Completeness'), findsOneWidget);
      expect(find.textContaining('Needs review'), findsOneWidget);
      expect(find.textContaining('Rating evidence is partial'), findsOneWidget);
    });
  });
}
