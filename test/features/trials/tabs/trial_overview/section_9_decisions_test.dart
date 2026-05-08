import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/section_9_decisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial() => Trial(
      id: 1,
      name: 'Test Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

Signal _signal({
  required int id,
  String type = 'replication_warning',
  int? sessionId = 7,
  int? plotId,
  String status = 'open',
  String severity = 'review',
  String referenceContext = '{}',
  String consequenceText = 'Raw generated signal text.',
}) =>
    Signal(
      id: id,
      trialId: 1,
      sessionId: sessionId,
      plotId: plotId,
      signalType: type,
      moment: 2,
      severity: severity,
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: referenceContext,
      magnitudeContext: null,
      consequenceText: consequenceText,
      status: status,
      createdAt: 1000,
    );

Widget _wrap({
  required Trial trial,
  required List<Signal> signals,
}) {
  return ProviderScope(
    overrides: [
      openSignalsForTrialProvider(trial.id).overrideWith(
        (ref) => Stream.value(signals),
      ),
      trialDecisionSummaryProvider(trial.id).overrideWith(
        (ref) async => TrialDecisionSummaryDto(
          trialId: trial.id,
          signalDecisions: const [],
          ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
          hasAnyResearcherReasoning: false,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Section9Decisions(trial: trial),
        ),
      ),
    ),
  );
}

void main() {
  group('Section9Decisions grouped signal review', () {
    testWidgets('related signals render as one group', (tester) async {
      final trial = _trial();

      await tester.pumpWidget(_wrap(
        trial: trial,
        signals: [
          _signal(
            id: 1,
            plotId: 101,
            consequenceText: 'Raw replication text one.',
          ),
          _signal(
            id: 2,
            plotId: 102,
            consequenceText: 'Raw replication text two.',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('Replication pattern may affect results'), findsOneWidget);
      expect(find.text('2 signals'), findsOneWidget);
      expect(find.text('1 session · 2 plots'), findsOneWidget);
      expect(find.text('Raw replication text one.'), findsNothing);
      expect(find.text('Raw replication text two.'), findsNothing);

      await tester.tap(find.text('Review context'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Why this matters'), findsOneWidget);
      expect(find.text('Effect on results'), findsOneWidget);
      expect(find.text('Question to resolve'), findsOneWidget);
      expect(
        find.text(
          'Replication helps distinguish treatment effects from field variability.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Irregular replication patterns may weaken treatment comparison reliability.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Are treatment comparisons still interpretable?'),
        findsOneWidget,
      );
      expect(find.text('Raw replication text one.'), findsNothing);
      expect(find.text('Raw replication text two.'), findsNothing);
    });

    testWidgets('singleton signal still renders normally', (tester) async {
      final trial = _trial();

      await tester.pumpWidget(_wrap(
        trial: trial,
        signals: [
          _signal(
            id: 3,
            type: 'scale_violation',
            plotId: 101,
            consequenceText: 'Raw scale text.',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recorded values may need review'), findsOneWidget);
      expect(find.text('Needs review'), findsWidgets);
      expect(find.text('Decide'), findsOneWidget);
      expect(find.text('1 signals'), findsNothing);
      expect(
        find.text('This review item should be considered on its own.'),
        findsNothing,
      );
      expect(find.text('Raw scale text.'), findsNothing);

      await tester.tap(find.text('Review context'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('This review item should be considered on its own.'),
        findsOneWidget,
      );
      expect(
        find.text('Its effect depends on the specific review context.'),
        findsOneWidget,
      );
      expect(
        find.text('Does this item need action before review or export?'),
        findsOneWidget,
      );
      expect(find.text('Raw scale text.'), findsNothing);
    });

    testWidgets('member signal IDs are preserved and actionable',
        (tester) async {
      final trial = _trial();

      await tester.pumpWidget(_wrap(
        trial: trial,
        signals: [
          _signal(id: 1, plotId: 101),
          _signal(id: 2, plotId: 102),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review 2 signals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Signal #1'), findsOneWidget);
      expect(find.text('Signal #2'), findsOneWidget);

      await tester.tap(find.text('Signal #2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Signal Decision'), findsOneWidget);
    });
  });
}
