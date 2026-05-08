import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_event.dart';
import 'package:arm_field_companion/domain/trial_story/trial_story_provider.dart';
import 'package:arm_field_companion/features/trials/trial_story_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial() => Trial(
      id: 1,
      name: 'Responsive Smoke Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

List<Override> _overrides(int trialId) => [
      trialStoryProvider(trialId).overrideWith(
        (ref) async => const <TrialStoryEvent>[],
      ),
      trialPurposeProvider(trialId).overrideWith(
        (ref) => Stream.value(TrialPurposeDto(
          trialId: trialId,
          purposeStatus: 'unknown',
          claimBeingTested: null,
          missingIntentFields: const [],
          provenanceSummary: 'test',
          canDriveReadinessClaims: false,
        )),
      ),
      trialEvidenceArcProvider(trialId).overrideWith(
        (ref) => Stream.value(
          TrialEvidenceArcDto(
            trialId: trialId,
            evidenceState: 'no_evidence',
            plannedEvidenceSummary: '',
            actualEvidenceSummary: '',
            missingEvidenceItems: const [],
            evidenceAnchors: const [],
            riskFlags: const [],
          ),
        ),
      ),
      trialCriticalToQualityProvider(trialId).overrideWith(
        (ref) => Stream.value(
          const TrialCtqDto(
            trialId: 1,
            overallStatus: 'unknown',
            blockerCount: 0,
            warningCount: 0,
            reviewCount: 0,
            satisfiedCount: 0,
            ctqItems: [],
          ),
        ),
      ),
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
    ];

Widget _wrap(double width, double height) => MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: ProviderScope(
        overrides: _overrides(1),
        child: MaterialApp(
          home: Scaffold(body: TrialStoryScreen(trial: _trial())),
        ),
      ),
    );

void main() {
  group('TrialStoryScreen responsive smoke', () {
    testWidgets('phone (390×844): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(390, 844));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet (834×1194): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(834, 1194));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large tablet (1024×1366): no layout exceptions', (tester) async {
      await tester.pumpWidget(_wrap(1024, 1366));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
