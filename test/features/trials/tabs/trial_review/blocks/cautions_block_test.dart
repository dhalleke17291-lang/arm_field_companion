import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/design/app_design_tokens.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection.dart';
import 'package:arm_field_companion/domain/trial_cognition/ctq_factor_acknowledgment_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_review/blocks/cautions_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({
  double? latitude = 49.8951,
  double? longitude = -97.1384,
}) =>
    Trial(
      id: 1,
      name: 'Cautions Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      latitude: latitude,
      longitude: longitude,
      isDeleted: false,
    );

TrialReadinessStatement _statement(List<String> cautions) =>
    TrialReadinessStatement(
      statusLabel: 'Export ready',
      summaryText: 'Trial is ready for export and analysis.',
      reasons: const [],
      actionItems: const [],
      cautions: List.unmodifiable(cautions),
      isReadyForExport: true,
    );

TrialInterpretationRiskDto _risk(List<TrialRiskFactorDto> factors) =>
    TrialInterpretationRiskDto(
      riskLevel: factors.any((f) => f.severity == 'high')
          ? 'high'
          : factors.any((f) => f.severity == 'moderate')
              ? 'moderate'
              : 'low',
      factors: factors,
      computedAt: DateTime(2026, 1, 1),
    );

const _highRisk = TrialRiskFactorDto(
  factorKey: 'data_variability',
  label: 'Data variability',
  severity: 'high',
  reason: 'Primary endpoint data variability HIGH.',
  sourceFields: [],
);

const _moderateRisk = TrialRiskFactorDto(
  factorKey: 'environmental_conditions',
  label: 'Environmental conditions',
  severity: 'moderate',
  reason: 'One excessive rainfall event recorded.',
  sourceFields: [],
);

TrialCtqDto _ctq(List<TrialCtqItemDto> items) => TrialCtqDto(
      trialId: 1,
      ctqItems: items,
      blockerCount: 0,
      warningCount: 0,
      reviewCount: items.where((i) => i.status == 'review_needed').length,
      satisfiedCount: 0,
      overallStatus: items.isEmpty ? 'ready_for_review' : 'review_needed',
    );

TrialCtqItemDto _ackCtq({CtqFactorAcknowledgmentDto? acknowledgment}) =>
    TrialCtqItemDto(
      factorKey: 'rater_consistency',
      label: 'Rater Consistency',
      importance: 'critical',
      status: 'review_needed',
      evidenceSummary: 'Open rater signal acknowledged.',
      reason: 'Researcher acknowledged rater consistency context.',
      source: 'system',
      isAcknowledged: true,
      latestAcknowledgment: acknowledgment,
    );

EnvironmentalSeasonSummaryDto _environment({
  String confidence = 'measured',
  int daysWithData = 10,
}) =>
    EnvironmentalSeasonSummaryDto(
      totalPrecipitationMm: 12,
      totalFrostEvents: 0,
      totalExcessiveRainfallEvents: 0,
      daysWithData: daysWithData,
      daysExpected: 10,
      overallConfidence: confidence,
    );

AssessmentDefinition _assessment(int id, String name) => AssessmentDefinition(
      id: id,
      code: 'A$id',
      name: name,
      category: 'efficacy',
      dataType: 'numeric',
      isSystem: false,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      resultDirection: 'higher_better',
    );

Signal _signal({
  int id = 10,
  int sessionId = 7,
  String consequenceText =
      'All plots in Treatment A have the same value for Disease Severity.',
}) =>
    Signal(
      id: id,
      trialId: 1,
      sessionId: sessionId,
      plotId: null,
      signalType: 'aov_prediction',
      moment: 3,
      severity: 'review',
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: '{"seType":"101"}',
      magnitudeContext: null,
      consequenceText: consequenceText,
      status: 'open',
      createdAt: 1000,
    );

SignalReviewProjection _projection({
  int signalId = 10,
  String title = 'Analysis pattern may need review',
  bool blocksExport = false,
  String? reliabilityTier,
}) =>
    SignalReviewProjection(
      signalId: signalId,
      type: 'aov_prediction',
      status: 'open',
      severity: 'review',
      operationalState: SignalOperationalState.needsAction,
      displayTitle: title,
      shortSummary:
          'The current data pattern may limit statistical comparison.',
      detailText: 'Raw signal detail.',
      whyItMatters:
          'Some data patterns make treatment comparisons less reliable.',
      recommendedAction:
          'Review the affected assessment before relying on analysis.',
      statusLabel: 'Needs review',
      severityLabel: 'Needs review',
      isActive: true,
      isNeedsAction: true,
      isUnderReview: false,
      isHistorical: false,
      requiresReadinessAction: true,
      readinessActionReason:
          'This signal is still open and should be reviewed before readiness is confirmed.',
      blocksExport: blocksExport,
      blocksExportReason: blocksExport
          ? 'Export is blocked until this critical signal is reviewed.'
          : null,
      reliabilityTier: reliabilityTier,
    );

SignalReviewGroupProjection _group({
  int signalId = 10,
  int sessionId = 7,
  List<int> assessmentIds = const [101],
  String groupingBasis = 'Grouped because raw seType 101 shares assessment.',
  String title = 'Analysis pattern may need review',
  String? reliabilityTier,
}) =>
    SignalReviewGroupProjection(
      groupId: 'group-$signalId',
      groupType: 'aov_prediction',
      familyKey: SignalFamilyKey.untreatedCheckVariance,
      familyDefinition:
          'Multiple review items point to the same untreated-check reliability concern.',
      groupingBasis: groupingBasis,
      familyScientificRole:
          'Untreated checks establish the baseline used for treatment comparison.',
      familyInterpretationImpact:
          'Low untreated-check variation across related assessments may reduce confidence.',
      reviewQuestion: 'Are these assessments reliable enough?',
      displayTitle: title,
      shortSummary:
          'The current data pattern may limit statistical comparison.',
      whyItMatters:
          'Some data patterns make treatment comparisons less reliable.',
      recommendedAction:
          'Review the affected assessment before relying on analysis.',
      statusLabel: 'Needs review',
      severityLabel: 'Needs review',
      signalCount: 1,
      affectedAssessmentIds: assessmentIds,
      affectedPlotIds: const [],
      affectedSessionIds: [sessionId],
      memberSignals: [
        _projection(signalId: signalId, title: title, reliabilityTier: reliabilityTier)
      ],
    );

Widget _wrapBody({
  Trial? trial,
  TrialReadinessStatement? statement,
  TrialInterpretationRiskDto? risk,
  List<SignalReviewGroupProjection> signalGroups = const [],
  List<Signal> rawSignals = const [],
  EnvironmentalSeasonSummaryDto? environmentalSummary,
  TrialCtqDto? ctq,
  List<AssessmentDefinition> assessmentDefinitions = const [],
  void Function(Signal signal)? onOpenSignalAction,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CautionsBlockBody(
          trial: trial ?? _trial(),
          statement: statement ?? _statement(const []),
          risk: risk ?? _risk(const []),
          signalGroups: signalGroups,
          rawSignals: rawSignals,
          environmentalSummary: environmentalSummary ?? _environment(),
          ctq: ctq ?? _ctq(const []),
          assessmentDefinitions: assessmentDefinitions,
          onOpenSignalAction: onOpenSignalAction,
        ),
      ),
    ),
  );
}

Widget _wrapProvider({
  required AsyncValue<TrialReadinessStatement> statementValue,
}) {
  final trial = _trial();
  return ProviderScope(
    overrides: [
      trialReadinessStatementProvider((
        trialId: trial.id,
        trialState: trial.status,
      )).overrideWith((_) => statementValue),
      trialInterpretationRiskProvider(trial.id)
          .overrideWith((_) => Stream.value(_risk(const []))),
      projectedOpenSignalGroupsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(const [])),
      openSignalsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(const [])),
      trialEnvironmentalSummaryProvider(trial.id)
          .overrideWith((_) => Stream.value(_environment())),
      trialEnvironmentalProvenanceProvider(trial.id)
          .overrideWith((_) => Stream.value(null)),
      trialCriticalToQualityProvider(trial.id)
          .overrideWith((_) => Stream.value(_ctq(const []))),
      assessmentDefinitionsProvider.overrideWith((_) => Stream.value(const [])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CautionsBlock(trial: trial),
      ),
    ),
  );
}

void _expectTextOrder(WidgetTester tester, List<String> labels) {
  var previousY = double.negativeInfinity;
  for (final label in labels) {
    final y = tester.getTopLeft(find.text(label)).dy;
    expect(y, greaterThan(previousY), reason: '$label should render in order.');
    previousY = y;
  }
}

void main() {
  group('CautionsBlock', () {
    testWidgets('CB-1: empty state hides the block', (tester) async {
      await tester.pumpWidget(_wrapBody());

      expect(find.byKey(const ValueKey('cautions-block-list')), findsNothing);
    });

    testWidgets('CB-2: provider loading renders overview loading',
        (tester) async {
      await tester.pumpWidget(_wrapProvider(
        statementValue: const AsyncValue.loading(),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('CB-3: provider error renders overview error', (tester) async {
      await tester.pumpWidget(_wrapProvider(
        statementValue: AsyncValue.error(Exception('boom'), StackTrace.current),
      ));

      expect(find.text('Unable to load.'), findsOneWidget);
    });

    testWidgets('CB-4: one statement caution renders', (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement:
            _statement(const ['Site/season condition noted: drought stress.']),
      ));

      expect(find.text('Caution'), findsOneWidget);
      expect(
        find.text('Site/season condition noted: drought stress.'),
        findsOneWidget,
      );
    });

    testWidgets('CB-5: three statement cautions render in order',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: _statement(
            const ['First caution', 'Second caution', 'Third caution']),
      ));

      _expectTextOrder(
          tester, ['First caution', 'Second caution', 'Third caution']);
    });

    testWidgets('CB-6: risk factors render high and moderate badges',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        risk: _risk(const [_highRisk, _moderateRisk]),
      ));

      expect(find.text('Data variability'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Environmental conditions'), findsOneWidget);
      expect(find.text('MODERATE'), findsOneWidget);
    });

    testWidgets('CB-7: risk-sourced caution is deduped against risk DTO',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const [
          'Interpretation risk is high — Primary endpoint data variability HIGH.',
          'Site/season condition noted: drought stress this season.',
        ]),
        risk: _risk(const [_highRisk]),
      ));

      expect(
        find.text(
            'Interpretation risk is high — Primary endpoint data variability HIGH.'),
        findsNothing,
      );
      expect(find.text('Data variability'), findsOneWidget);
      expect(
          find.text('Primary endpoint data variability HIGH.'), findsOneWidget);
      expect(
        find.text('Site/season condition noted: drought stress this season.'),
        findsOneWidget,
      );
    });

    testWidgets('CB-8: signal card renders assessment name and reason',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_group()],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.text('Disease Severity'), findsOneWidget);
      expect(
        find.text(
            'All plots in Treatment A have the same value for Disease Severity.'),
        findsOneWidget,
      );
    });

    testWidgets('CB-9: groupingBasis is never rendered', (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_group()],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.textContaining('Grouped because'), findsNothing);
    });

    testWidgets('CB-10: raw seType is never rendered', (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [
          _group(groupingBasis: 'Grouped because seType 101 is shared.')
        ],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.textContaining('seType'), findsNothing);
      expect(find.text('101'), findsNothing);
    });

    testWidgets(
        'CB-11: one-member untreated-check group renders without grouping language',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_group()],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.text('Disease Severity'), findsOneWidget);
      expect(find.textContaining('Multiple review items'), findsNothing);
      expect(find.textContaining('Grouped because'), findsNothing);
    });

    testWidgets(
        'CB-12: multiple same-session untreated groups collapse with assessment chips',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [
          _group(signalId: 10, assessmentIds: const [101]),
          _group(signalId: 11, assessmentIds: const [102]),
        ],
        rawSignals: [_signal(id: 10), _signal(id: 11)],
        assessmentDefinitions: [
          _assessment(101, 'Disease Severity'),
          _assessment(102, 'Crop Injury'),
        ],
      ));

      expect(find.text('Untreated check reliability may need review'),
          findsOneWidget);
      expect(find.text('Disease Severity'), findsOneWidget);
      expect(find.text('Crop Injury'), findsOneWidget);
      expect(find.text('Analysis pattern may need review'), findsNothing);
    });

    testWidgets('CB-13: environmental estimated and unavailable render',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        environmentalSummary: _environment(confidence: 'estimated'),
      ));
      expect(find.text('Environmental evidence is estimated.'), findsOneWidget);
      expect(find.text('Estimated'), findsOneWidget);

      await tester.pumpWidget(_wrapBody(
        environmentalSummary:
            _environment(confidence: 'unavailable', daysWithData: 0),
      ));
      expect(
        find.text('Environmental evidence not available yet.'),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('CB-14: environmental measured is hidden', (tester) async {
      await tester.pumpWidget(_wrapBody(
        environmentalSummary: _environment(confidence: 'measured'),
      ));

      expect(find.textContaining('Environmental evidence'), findsNothing);
    });

    testWidgets('CB-15: acknowledged review CTQ renders acknowledgment marker',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctq: _ctq([
          _ackCtq(
            acknowledgment: CtqFactorAcknowledgmentDto(
              id: 1,
              factorKey: 'rater_consistency',
              acknowledgedAt: DateTime(2026, 2, 3),
              actorName: 'Researcher',
              reason: 'Reviewed and acceptable.',
              factorStatusAtAcknowledgment: 'review_needed',
            ),
          ),
        ]),
      ));

      expect(find.text('Rater Consistency'), findsOneWidget);
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(
          find.text('Acknowledged Feb 3, 2026 by Researcher'), findsOneWidget);
    });

    testWidgets('CB-16: all content types render in agreed order',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement:
            _statement(const ['Site/season condition noted: drought stress.']),
        risk: _risk(const [_moderateRisk]),
        signalGroups: [_group()],
        rawSignals: [_signal()],
        environmentalSummary: _environment(confidence: 'estimated'),
        ctq: _ctq([_ackCtq()]),
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      _expectTextOrder(tester, [
        'Site/season condition noted: drought stress.',
        'Environmental conditions',
        'Disease Severity',
        'Environmental evidence is estimated.',
        'Rater Consistency',
      ]);
    });

    testWidgets(
        'CB-17: signal with reliabilityTier HIGH shows HIGH chip with warning color',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_group(reliabilityTier: 'HIGH')],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Needs review'), findsNothing);

      final chipContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('HIGH'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = chipContainer.decoration as BoxDecoration;
      expect(decoration.color, AppDesignTokens.warningBg);
    });

    testWidgets(
        'CB-18: signal with null reliabilityTier falls back to severity label',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_group()],
        rawSignals: [_signal()],
        assessmentDefinitions: [_assessment(101, 'Disease Severity')],
      ));

      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('HIGH'), findsNothing);
      expect(find.text('MEDIUM'), findsNothing);

      final chipContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Needs review'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = chipContainer.decoration as BoxDecoration;
      expect(decoration.color, AppDesignTokens.partialBg);
    });
  });
}
