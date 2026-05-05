import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/section_10_readiness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

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

TrialCoherenceDto _coherenceAligned() => TrialCoherenceDto(
      coherenceState: 'aligned',
      checks: const [],
      computedAt: DateTime(2026, 1, 1),
    );

TrialCoherenceDto _coherenceWithIssue() => TrialCoherenceDto(
      coherenceState: 'review_needed',
      checks: const [
        TrialCoherenceCheckDto(
          checkKey: 'arc',
          label: 'Application timing',
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

TrialInterpretationRiskDto _riskModerate() => TrialInterpretationRiskDto(
      riskLevel: 'moderate',
      factors: const [
        TrialRiskFactorDto(
          factorKey: 'cv',
          label: 'Data variability',
          severity: 'moderate',
          reason: 'CV on primary endpoint is 31%.',
          sourceFields: [],
        ),
      ],
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  required Trial trial,
  required TrialCoherenceDto coherence,
  required TrialInterpretationRiskDto risk,
  required TrialCtqDto ctq,
}) {
  return ProviderScope(
    overrides: [
      environmentalEnsureTodayBackgroundEnabledProvider
          .overrideWithValue(false),
      trialCoherenceProvider(trial.id).overrideWith((_) async => coherence),
      trialInterpretationRiskProvider(trial.id)
          .overrideWith((_) async => risk),
      trialCriticalToQualityProvider(trial.id).overrideWith((_) async => ctq),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Section10Readiness(trial: trial),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section10Readiness widget', () {
    testWidgets('S10-W1: clean variant renders export-ready chip', (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready'), findsOneWidget);
      expect(find.textContaining('Trial is ready for export'), findsOneWidget);
    });

    testWidgets('S10-W2: problem variant renders not-ready chip and action items',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceWithIssue(),
        risk: _riskModerate(),
        ctq: _ctqBlocked(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not export-ready'), findsOneWidget);
      expect(
        find.textContaining('Trial is not currently export-ready.'),
        findsOneWidget,
      );
      expect(find.text('ITEMS REQUIRING ACTION'), findsOneWidget);
      expect(
        find.textContaining('Primary endpoint data'),
        findsWidgets,
      );
    });
  });
}
