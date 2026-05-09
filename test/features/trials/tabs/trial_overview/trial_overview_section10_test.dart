import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection_mapper.dart';
import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/readiness_criteria_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
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

SignalReviewProjection _projectedSignal({
  int id = 1,
  String type = 'scale_violation',
  String status = 'open',
  String severity = 'review',
  String consequenceText = 'Raw generated signal text.',
}) {
  return projectSignalForReview(
    Signal(
      id: id,
      trialId: 1,
      sessionId: 20,
      plotId: 30,
      signalType: type,
      moment: 2,
      severity: severity,
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: '{}',
      magnitudeContext: null,
      consequenceText: consequenceText,
      status: status,
      createdAt: 1000,
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TrialPurposeDto _purposeEmpty() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'unknown',
      missingIntentFields: [],
      provenanceSummary: 'No purpose captured.',
      canDriveReadinessClaims: false,
    );

Widget _wrap({
  required Trial trial,
  required TrialCoherenceDto coherence,
  required TrialInterpretationRiskDto risk,
  required TrialCtqDto ctq,
  TrialPurposeDto? purpose,
  List<SignalReviewProjection> projectedSignals = const [],
}) {
  final resolvedPurpose = purpose ?? _purposeEmpty();
  return ProviderScope(
    overrides: [
      environmentalEnsureTodayBackgroundEnabledProvider
          .overrideWithValue(false),
      trialCoherenceProvider(trial.id)
          .overrideWith((_) => Stream.value(coherence)),
      trialInterpretationRiskProvider(trial.id)
          .overrideWith((_) => Stream.value(risk)),
      trialCriticalToQualityProvider(trial.id)
          .overrideWith((_) => Stream.value(ctq)),
      trialPurposeProvider(trial.id)
          .overrideWith((_) => Stream.value(resolvedPurpose)),
      projectedOpenSignalsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(projectedSignals)),
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
    testWidgets('S10-W1: clean variant renders export-ready chip and summary',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready'), findsOneWidget);
      expect(find.textContaining('Trial is ready for export'), findsOneWidget);
      // WHY section is suppressed when export-ready
      expect(find.text('WHY'), findsNothing);
    });

    testWidgets(
        'S10-W2: problem variant renders not-ready chip, action items, and cautions',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceWithIssue(),
        risk: _riskModerate(),
        ctq: _ctqBlocked(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('In progress — review before export'), findsOneWidget);
      expect(
        find.textContaining('Trial is not currently export-ready.'),
        findsOneWidget,
      );
      expect(find.text('ITEMS REQUIRING ACTION'), findsOneWidget);
      expect(find.textContaining('Primary endpoint data'), findsWidgets);
      // Moderate risk should appear as a caution
      expect(find.text('CAUTIONS'), findsOneWidget);
    });

    testWidgets('S10-W3: subtitle is rendered', (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('What must be resolved before export'),
        findsOneWidget,
      );
    });
  });

  group('Section10Readiness — projected signal action items', () {
    testWidgets('open projected signal appears in Items Requiring Action',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        projectedSignals: [
          _projectedSignal(
            status: 'open',
            consequenceText: 'Raw value out of range copy.',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ITEMS REQUIRING ACTION'), findsOneWidget);
      expect(find.text('Recorded values may need review'), findsOneWidget);
      expect(
        find.text(
          'This signal is still open and should be reviewed before readiness is confirmed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Raw value out of range copy.'), findsNothing);
    });

    testWidgets(
        'investigating and deferred projected signals do not appear yet',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        projectedSignals: [
          _projectedSignal(
            id: 1,
            type: 'rater_drift',
            status: 'investigating',
            consequenceText: 'Raw investigating text.',
          ),
          _projectedSignal(
            id: 2,
            type: 'replication_warning',
            status: 'deferred',
            consequenceText: 'Raw deferred text.',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ITEMS REQUIRING ACTION'), findsNothing);
      expect(find.text('Rating consistency may need review'), findsNothing);
      expect(find.text('Replication pattern may affect results'), findsNothing);
      expect(find.text('Raw investigating text.'), findsNothing);
      expect(find.text('Raw deferred text.'), findsNothing);
    });

    testWidgets('historical projected signals do not appear', (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        projectedSignals: [
          _projectedSignal(
            id: 1,
            status: 'resolved',
            consequenceText: 'Raw resolved text.',
          ),
          _projectedSignal(
            id: 2,
            status: 'suppressed',
            consequenceText: 'Raw suppressed text.',
          ),
          _projectedSignal(
            id: 3,
            status: 'expired',
            consequenceText: 'Raw expired text.',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ITEMS REQUIRING ACTION'), findsNothing);
      expect(find.text('Recorded values may need review'), findsNothing);
      expect(find.text('Raw resolved text.'), findsNothing);
      expect(find.text('Raw suppressed text.'), findsNothing);
      expect(find.text('Raw expired text.'), findsNothing);
    });
  });

  group('Section10Readiness — readiness criteria display', () {
    testWidgets(
        'S10-C1: no criteria section when readinessCriteriaSummary is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('READINESS CRITERIA'), findsNothing);
    });

    testWidgets('S10-C2: criteria section shown when minEfficacyPercent set',
        (tester) async {
      final json = ReadinessCriteriaCodec.serialize(ReadinessCriteriaDto(
        minEfficacyPercent: 80,
        efficacyAt: 'primary_endpoint_only',
        setBy: 'researcher',
        setAt: DateTime(2026, 5, 1),
      ));
      final purpose = TrialPurposeDto(
        trialId: 1,
        purposeStatus: 'confirmed',
        missingIntentFields: const [],
        provenanceSummary: 'Confirmed.',
        canDriveReadinessClaims: true,
        readinessCriteriaSummary: json,
      );

      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        purpose: purpose,
      ));
      await tester.pumpAndSettle();

      expect(find.text('READINESS CRITERIA'), findsOneWidget);
      expect(find.textContaining('80%'), findsOneWidget);
      expect(find.textContaining('primary endpoint'), findsOneWidget);
    });

    testWidgets('S10-C3: phytotoxicity threshold displayed when set',
        (tester) async {
      final json = ReadinessCriteriaCodec.serialize(ReadinessCriteriaDto(
        phytotoxicityThresholdPercent: 10,
        setBy: 'researcher',
        setAt: DateTime(2026, 5, 1),
      ));
      final purpose = TrialPurposeDto(
        trialId: 1,
        purposeStatus: 'confirmed',
        missingIntentFields: const [],
        provenanceSummary: 'Confirmed.',
        canDriveReadinessClaims: true,
        readinessCriteriaSummary: json,
      );

      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        purpose: purpose,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('10%'), findsOneWidget);
    });

    testWidgets('S10-C4: malformed criteria JSON renders no criteria section',
        (tester) async {
      const purpose = TrialPurposeDto(
        trialId: 1,
        purposeStatus: 'confirmed',
        missingIntentFields: [],
        provenanceSummary: 'Confirmed.',
        canDriveReadinessClaims: true,
        readinessCriteriaSummary: 'not-valid-json',
      );

      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        purpose: purpose,
      ));
      await tester.pumpAndSettle();

      expect(find.text('READINESS CRITERIA'), findsNothing);
    });
  });

  group('Section10Readiness — known site/season cautions', () {
    testWidgets(
        'S10-K1: null knownInterpretationFactors produces no site cautions',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Site/season condition noted'), findsNothing);
    });

    testWidgets(
        'S10-K2: empty factors (none selected) produces no site cautions',
        (tester) async {
      final purpose = TrialPurposeDto(
        trialId: 1,
        purposeStatus: 'unknown',
        missingIntentFields: const [],
        provenanceSummary: 'No purpose.',
        canDriveReadinessClaims: false,
        knownInterpretationFactors: InterpretationFactorsCodec.serialize([]),
      );

      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        purpose: purpose,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Site/season condition noted'), findsNothing);
    });

    testWidgets('S10-K3: selected factor produces caution text',
        (tester) async {
      final purpose = TrialPurposeDto(
        trialId: 1,
        purposeStatus: 'unknown',
        missingIntentFields: const [],
        provenanceSummary: 'No purpose.',
        canDriveReadinessClaims: false,
        knownInterpretationFactors:
            InterpretationFactorsCodec.serialize(['drought_stress']),
      );

      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        purpose: purpose,
      ));
      await tester.pumpAndSettle();

      expect(find.text('CAUTIONS'), findsOneWidget);
      expect(
        find.textContaining('drought stress this season'),
        findsOneWidget,
      );
    });
  });
}
