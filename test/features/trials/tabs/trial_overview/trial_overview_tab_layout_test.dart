import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_decision_summary_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_evidence_arc_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/trial_overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({int id = 1}) => Trial(
      id: id,
      name: 'Layout smoke trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialPurposeDto _purpose() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'unknown',
      claimBeingTested: null,
      missingIntentFields: [],
      provenanceSummary: 'test',
      canDriveReadinessClaims: false,
    );

TrialEvidenceArcDto _arc() => const TrialEvidenceArcDto(
      trialId: 1,
      evidenceState: 'no_evidence',
      plannedEvidenceSummary: '',
      actualEvidenceSummary: '',
      missingEvidenceItems: [],
      evidenceAnchors: [],
      riskFlags: [],
    );

const _ctq = TrialCtqDto(
  trialId: 1,
  ctqItems: [],
  blockerCount: 0,
  warningCount: 0,
  reviewCount: 0,
  satisfiedCount: 0,
  overallStatus: 'unknown',
);

final _coh = TrialCoherenceDto(
  coherenceState: 'aligned',
  checks: const [],
  computedAt: DateTime.utc(2026, 1, 1),
);

final _risk = TrialInterpretationRiskDto(
  riskLevel: 'low',
  factors: const [],
  computedAt: DateTime.utc(2026, 1, 1),
);

const _env = EnvironmentalSeasonSummaryDto(
  totalPrecipitationMm: null,
  totalFrostEvents: 0,
  totalExcessiveRainfallEvents: 0,
  daysWithData: 0,
  daysExpected: 1,
  overallConfidence: 'unavailable',
);

Widget _wrapSized({
  required double width,
  required double height,
  required Trial trial,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, height)),
    child: ProviderScope(
      overrides: [
        environmentalEnsureTodayBackgroundEnabledProvider
            .overrideWithValue(false),
        trialPurposeProvider(trial.id).overrideWith(
          (ref) => Stream.value(_purpose()),
        ),
        trialEvidenceArcProvider(trial.id).overrideWith(
              (ref) => Stream.value(_arc()),
        ),
        trialCriticalToQualityProvider(trial.id).overrideWith(
          (ref) => Stream.value(_ctq),
        ),
        trialCoherenceProvider(trial.id).overrideWith(
          (ref) => Stream.value(_coh),
        ),
        trialInterpretationRiskProvider(trial.id).overrideWith(
          (ref) => Stream.value(_risk),
        ),
        trialEnvironmentalSummaryProvider(trial.id).overrideWith(
          (ref) async => _env,
        ),
        trialApplicationsForTrialProvider(trial.id).overrideWith(
          (ref) => Stream.value(const <TrialApplicationEvent>[]),
        ),
        openSignalsForTrialProvider(trial.id).overrideWith(
          (ref) => Stream.value(<Signal>[]),
        ),
        trialDecisionSummaryProvider(trial.id).overrideWith(
          (ref) async => TrialDecisionSummaryDto(
            trialId: trial.id,
            signalDecisions: const [],
            ctqAcknowledgments: const <CtqFactorAcknowledgmentDto>[],
            hasAnyResearcherReasoning: false,
          ),
        ),
        treatmentsForTrialProvider(trial.id).overrideWith(
          (ref) => Stream.value(const <Treatment>[]),
        ),
        plotsForTrialProvider(trial.id).overrideWith(
          (ref) => Stream.value(const <Plot>[]),
        ),
        armTrialMetadataStreamProvider(trial.id).overrideWith(
          (ref) => Stream.value(null),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrialOverviewTab(trial: trial),
        ),
      ),
    ),
  );
}

void main() {
  group('TrialOverviewTab responsive smoke', () {
    testWidgets('phone viewport: no synchronous exceptions during layout', (
      WidgetTester tester,
    ) async {
      final trial = _trial();
      await tester.pumpWidget(_wrapSized(width: 390, height: 844, trial: trial));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet viewport: no synchronous exceptions during layout', (
      WidgetTester tester,
    ) async {
      final trial = _trial();
      await tester.pumpWidget(_wrapSized(width: 834, height: 1194, trial: trial));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
