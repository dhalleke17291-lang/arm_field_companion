import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/trials/widgets/signal_action_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// All drift writes happen in setUp. Writing inside a `testWidgets` body
// causes db.close() in tearDown to hang — likely a drift/FakeAsync interaction
// in the widget-test runner. Keep all signals pre-built before pumpWidget runs.

Widget _wrap({
  required Signal signal,
  required AppDatabase db,
}) {
  final trialId = signal.trialId;
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      signalRepositoryProvider
          .overrideWith((_) => SignalRepository.attach(db)),
      openSignalsForTrialProvider(trialId).overrideWith(
        (ref) async => const <Signal>[],
      ),
      trialDecisionSummaryProvider(trialId).overrideWith(
        (ref) async => TrialDecisionSummaryDto(
          trialId: trialId,
          signalDecisions: const [],
          ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
          hasAnyResearcherReasoning: false,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () =>
                showSignalActionSheet(ctx, signal: signal, trialId: trialId),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Record Decision'),
    );

/// Opens the sheet using bounded pumps. `pumpAndSettle` hangs because the
/// underlying DraggableScrollableSheet's snap simulation never settles.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late AppDatabase db;
  late Signal scaleSignal;
  late Signal raterSignal;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = SignalRepository.attach(db);

    // Default scale-violation signal used by most tests.
    final trialId =
        await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));
    final scaleId = await repo.raiseSignal(
      trialId: trialId,
      signalType: SignalType.scaleViolation,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext: const SignalReferenceContext(
        seType: 'PHYGEN',
        scaleMin: 0,
        scaleMax: 100,
        enteredValue: 110,
      ),
      consequenceText: 'Value out of range.',
    );
    scaleSignal = await (db.select(db.signals)
          ..where((s) => s.id.equals(scaleId)))
        .getSingle();

    // Rater-drift signal for SA-6 (Re-rate option visibility).
    final trialId2 =
        await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T2'));
    final raterId = await repo.raiseSignal(
      trialId: trialId2,
      signalType: SignalType.raterDrift,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext:
          const SignalReferenceContext(seType: 'session_attribution'),
      consequenceText: 'Rater attribution inconsistency.',
    );
    raterSignal = await (db.select(db.signals)
          ..where((s) => s.id.equals(raterId)))
        .getSingle();
  });

  tearDown(() async => db.close());

  group('SignalActionSheet — save button state', () {
    testWidgets(
        'SA-1: Confirm selected with < 10 char reason → save disabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await tester.tap(find.textContaining('Confirm'));
      await tester.pump();
      // Scroll the lazy ListView so the TextField below the fold gets built.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'short');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets(
        'SA-2: Confirm selected with ≥ 10 char reason → save enabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await tester.tap(find.textContaining('Confirm'));
      await tester.pump();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pump();
      await tester.enterText(
          find.byType(TextField), 'Confirmed after field review.');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('SA-3: Defer with empty reason → save enabled', (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await tester.tap(find.textContaining('Defer'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets(
        'SA-4: Suppress selected with empty reason → save disabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await tester.tap(find.textContaining('Suppress'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('SA-5: no option selected → save disabled', (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets(
        'SA-6: Re-rate option only shown for rater_drift signal',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: raterSignal, db: db));
      await _openSheet(tester);

      // Re-rate is the 5th decision option (below the visible fold).
      // Scroll the lazy ListView so it gets built.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('Re-rate'), findsOneWidget);
    });

    testWidgets(
        'SA-7: Re-rate option not shown for scale_violation signal',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      expect(find.textContaining('Re-rate'), findsNothing);
    });
  });
}
