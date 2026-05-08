import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/trial_overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Trial _trial() => Trial(
      id: 1,
      name: 'Summary Card Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialCoherenceDto _coherenceAligned() => TrialCoherenceDto(
      coherenceState: 'aligned',
      checks: const [],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCoherenceDto _coherenceWithIssue() => TrialCoherenceDto(
      coherenceState: 'review_needed',
      checks: const [
        TrialCoherenceCheckDto(
          checkKey: 'app_timing',
          label: 'Application timing deviation',
          status: 'review_needed',
          reason: 'Application T2 outside planned window.',
          sourceFields: [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialInterpretationRiskDto _riskLow() => TrialInterpretationRiskDto(
      riskLevel: 'low',
      factors: const [],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCtqDto _ctqReady() => const TrialCtqDto(
      trialId: 1,
      ctqItems: [],
      blockerCount: 0,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 3,
      overallStatus: 'ready_for_review',
    );

TrialCtqDto _ctqBlocked() => const TrialCtqDto(
      trialId: 1,
      ctqItems: [
        TrialCtqItemDto(
          factorKey: 'primary_endpoint_completeness',
          label: 'Primary endpoint data',
          importance: 'critical',
          status: 'blocked',
          evidenceSummary: '3/4 complete.',
          reason: 'Rep 2 for T3 missing.',
          source: 'system',
        ),
      ],
      blockerCount: 1,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 0,
      overallStatus: 'incomplete',
    );

TrialDecisionSummaryDto _noDecisions(int trialId) => TrialDecisionSummaryDto(
      trialId: trialId,
      signalDecisions: const [],
      ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
      hasAnyResearcherReasoning: false,
    );

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap({
  required Trial trial,
  required TrialCoherenceDto coherence,
  required TrialInterpretationRiskDto risk,
  required TrialCtqDto ctq,
  List<Signal> signals = const [],
}) {
  return ProviderScope(
    overrides: [
      environmentalEnsureTodayBackgroundEnabledProvider
          .overrideWithValue(false),
      trialCriticalToQualityProvider(trial.id)
          .overrideWith((_) => Stream.value(ctq)),
      trialCoherenceProvider(trial.id)
          .overrideWith((_) => Stream.value(coherence)),
      trialInterpretationRiskProvider(trial.id)
          .overrideWith((_) => Stream.value(risk)),
      openSignalsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(signals)),
      trialDecisionSummaryProvider(trial.id)
          .overrideWith((_) async => _noDecisions(trial.id)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrialReviewSummaryCard(trial: trial),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrialReviewSummaryCard', () {
    testWidgets('SC-1: problem state renders attention items', (tester) async {
      final trial = _trial();
      await tester.pumpWidget(_wrap(
        trial: trial,
        coherence: _coherenceWithIssue(),
        risk: _riskLow(),
        ctq: _ctqBlocked(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not export-ready'), findsOneWidget);
      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
      expect(
        find.textContaining('Primary endpoint data'),
        findsWidgets,
      );
    });

    testWidgets('SC-2: clean state renders export-ready chip', (tester) async {
      final trial = _trial();
      await tester.pumpWidget(_wrap(
        trial: trial,
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        signals: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready'), findsOneWidget);
      expect(find.textContaining('Trial is ready for export'), findsOneWidget);
      expect(find.text('No open signals.'), findsOneWidget);
    });

    testWidgets('SC-3: no layout exceptions during pump', (tester) async {
      final trial = _trial();
      await tester.pumpWidget(_wrap(
        trial: trial,
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
