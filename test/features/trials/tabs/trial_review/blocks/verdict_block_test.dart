import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/interpretation_factors_codec.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_review/blocks/verdict_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({String status = 'active'}) => Trial(
      id: 1,
      name: 'Verdict Trial',
      status: status,
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

TrialInterpretationRiskDto _riskLow() => TrialInterpretationRiskDto(
      riskLevel: 'low',
      factors: const [],
      computedAt: DateTime(2026, 1, 1),
    );

TrialInterpretationRiskDto _riskModerate() => TrialInterpretationRiskDto(
      riskLevel: 'moderate',
      factors: const [
        TrialRiskFactorDto(
          factorKey: 'data_variability',
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

TrialPurposeDto _purpose({String? knownInterpretationFactors}) =>
    TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'unknown',
      knownInterpretationFactors: knownInterpretationFactors,
      missingIntentFields: const [],
      provenanceSummary: 'No purpose captured.',
      canDriveReadinessClaims: false,
    );

Widget _wrap({
  required Trial trial,
  required TrialCoherenceDto coherence,
  required TrialInterpretationRiskDto risk,
  required TrialCtqDto ctq,
  TrialPurposeDto? purpose,
  int amendmentCount = 0,
  List<NavigatorObserver> navigatorObservers = const [],
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
      trialPurposeProvider(trial.id)
          .overrideWith((_) => Stream.value(purpose ?? _purpose())),
      amendedRatingCountForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(amendmentCount)),
    ],
    child: MaterialApp(
      navigatorObservers: navigatorObservers,
      home: Scaffold(
        body: SingleChildScrollView(
          child: VerdictBlock(trial: trial),
        ),
      ),
    ),
  );
}

Widget _wrapBody({
  required TrialReadinessStatement statement,
  int amendmentCount = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: VerdictBlockBody(
        statement: statement,
        trial: _trial(),
        amendmentCount: amendmentCount,
      ),
    ),
  );
}

class _PushCountingObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

class _DegenerateReadyWithNoCautionsStatement extends TrialReadinessStatement {
  const _DegenerateReadyWithNoCautionsStatement()
      : super(
          statusLabel: 'Export ready',
          summaryText: 'Trial is ready for export and analysis.',
          reasons: const [],
          actionItems: const [],
          cautions: const [],
          isReadyForExport: true,
        );

  @override
  String get readinessLevel => 'ready_with_cautions';
}

void main() {
  group('VerdictBlock', () {
    testWidgets('VB-1: ready renders status and summary only', (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready'), findsOneWidget);
      expect(
        find.text('Trial is ready for export and analysis.'),
        findsOneWidget,
      );
      expect(find.textContaining('caution to review'), findsNothing);
      expect(find.textContaining('Resolve:'), findsNothing);
    });

    testWidgets('VB-2: ready with one caution renders singular headline',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskModerate(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready · 1 caution to review'), findsOneWidget);
      expect(
          find.textContaining('CV on primary endpoint is 31%'), findsNothing);
      expect(find.textContaining('Resolve:'), findsNothing);
    });

    testWidgets('VB-3: ready with multiple cautions renders plural headline',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskModerate(),
        ctq: _ctqReady(),
        purpose: _purpose(
          knownInterpretationFactors:
              InterpretationFactorsCodec.serialize(['drought_stress']),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Export ready · 2 cautions to review'), findsOneWidget);
      expect(find.textContaining('drought stress this season'), findsNothing);
    });

    testWidgets('VB-4: not ready renders every action item as bullets',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqBlocked(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('In progress — review before export'), findsOneWidget);
      expect(find.text('Resolve: Primary endpoint data'), findsOneWidget);
      expect(
        find.text('Trial is not currently export-ready.'),
        findsNothing,
      );
    });

    testWidgets(
        'VB-5: not ready without action items renders summary as context',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(status: 'draft'),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not export-ready'), findsOneWidget);
      expect(
        find.text('Trial is not currently export-ready.'),
        findsOneWidget,
      );
    });

    testWidgets('VB-6: amendment line is hidden when count is zero',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        amendmentCount: 0,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('amendments on record'), findsNothing);
    });

    testWidgets('VB-7: amendment line is visible when count is positive',
        (tester) async {
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        amendmentCount: 2,
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('2 amendments on record — view in Data'),
        findsOneWidget,
      );
    });

    testWidgets('VB-8: tapping amendment line pushes the Data screen route',
        (tester) async {
      final observer = _PushCountingObserver();
      await tester.pumpWidget(_wrap(
        trial: _trial(),
        coherence: _coherenceAligned(),
        risk: _riskLow(),
        ctq: _ctqReady(),
        amendmentCount: 2,
        navigatorObservers: [observer],
      ));
      await tester.pumpAndSettle();

      expect(observer.pushCount, 1);
      final inkWell = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('2 amendments on record — view in Data'),
          matching: find.byType(InkWell),
        ),
      );
      inkWell.onTap!();
      expect(observer.pushCount, 2);
      Navigator.of(
        tester.element(find.text('2 amendments on record — view in Data')),
      ).pop();
      await tester.pump();
    });

    testWidgets(
        'VB-9: defensive ready-with-cautions branch falls through when count is zero',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: const _DegenerateReadyWithNoCautionsStatement(),
      ));

      expect(find.text('Export ready'), findsOneWidget);
      expect(find.textContaining('caution to review'), findsNothing);
      expect(
        find.text('Trial is ready for export and analysis.'),
        findsOneWidget,
      );
    });
  });
}
