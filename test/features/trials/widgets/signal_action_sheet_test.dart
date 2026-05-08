import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/widgets/standard_form_bottom_sheet.dart';
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
      signalRepositoryProvider.overrideWith((_) => SignalRepository.attach(db)),
      openSignalsForTrialProvider(trialId).overrideWith(
        (ref) => Stream.value(const <Signal>[]),
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

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Record Decision'),
    );

/// Opens the sheet using bounded pumps. `pumpAndSettle` hangs because the
/// underlying DraggableScrollableSheet's snap simulation never settles.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}

void main() {
  late AppDatabase db;
  late Signal scaleSignal;
  late Signal raterSignal;
  late Signal criticalSignal;

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

    final trialId3 =
        await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T3'));
    final criticalId = await repo.raiseSignal(
      trialId: trialId3,
      signalType: SignalType.replicationWarning,
      moment: SignalMoment.two,
      severity: SignalSeverity.critical,
      referenceContext: const SignalReferenceContext(treatmentId: 1),
      consequenceText: 'Raw critical replication text.',
    );
    criticalSignal = await (db.select(db.signals)
          ..where((s) => s.id.equals(criticalId)))
        .getSingle();
  });

  tearDown(() async => db.close());

  group('SignalActionSheet — projection language', () {
    testWidgets(
        'uses projected title and summary while keeping raw detail collapsed',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      expect(find.text('Recorded values may need review'), findsOneWidget);
      expect(
        find.text(
            'A recorded value was outside the expected assessment range.'),
        findsOneWidget,
      );
      expect(find.text('Value out of range.'), findsNothing);

      await _scrollUntilVisible(tester, find.text('Original signal detail'));
      await tester.tap(find.text('Original signal detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Value out of range.'), findsOneWidget);
    });

    testWidgets('uses projection severity label instead of raw Critical',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: criticalSignal, db: db));
      await _openSheet(tester);

      expect(find.text('Needs review before export'), findsOneWidget);
      expect(find.text('Critical'), findsNothing);
    });
  });

  group('SignalActionSheet — save button state', () {
    testWidgets(
        'SA-1: Investigate selected with < 10 char reason → save disabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await _scrollUntilVisible(tester, find.textContaining('Investigate'));
      await tester.tap(find.textContaining('Investigate'));
      await tester.pump();
      // Scroll the lazy ListView so the TextField below the fold gets built.
      await _scrollUntilVisible(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'short');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('SA-2: Confirm selected with no reason → save enabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await _scrollUntilVisible(tester, find.textContaining('Confirm'));
      await tester.tap(find.textContaining('Confirm'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('SA-3: Defer with empty reason → save enabled', (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await _scrollUntilVisible(tester, find.textContaining('Defer'));
      await tester.tap(find.textContaining('Defer'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('SA-4: Suppress selected with empty reason → save disabled',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      await _scrollUntilVisible(tester, find.textContaining('Suppress'));
      await tester.tap(find.textContaining('Suppress'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('SA-5: no option selected → save disabled', (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('SA-6: Re-rate option only shown for rater_drift signal',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: raterSignal, db: db));
      await _openSheet(tester);

      // Re-rate is the 5th decision option (below the visible fold).
      // Scroll the lazy ListView so it gets built.
      await _scrollUntilVisible(tester, find.textContaining('Re-rate'));

      expect(find.textContaining('Re-rate'), findsOneWidget);
    });

    testWidgets('SA-7: Re-rate option not shown for scale_violation signal',
        (tester) async {
      await tester.pumpWidget(_wrap(signal: scaleSignal, db: db));
      await _openSheet(tester);

      expect(find.textContaining('Re-rate'), findsNothing);
    });

    testWidgets(
        'SA-8: constrained width on tablet-class viewport avoids full-bleed form',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(900, 1200)),
          child: _wrap(signal: scaleSignal, db: db),
        ),
      );
      await _openSheet(tester);
      await tester.pump();

      final renderObject =
          tester.renderObject(find.byType(StandardFormBottomSheetLayout));
      final rb = renderObject as RenderBox;
      expect(rb.size.width, lessThanOrEqualTo(561));
      expect(rb.size.width, greaterThan(200));
      expect(tester.takeException(), isNull);
    });
  });
}
