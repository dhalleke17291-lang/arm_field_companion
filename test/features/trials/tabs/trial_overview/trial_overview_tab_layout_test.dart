import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/core/workspace/workspace_config.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection.dart';
import 'package:arm_field_companion/domain/trial_cognition/environmental_window_evaluator.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_interpretation_risk_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
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

TrialReadinessStatement _statement({
  List<String> actionItems = const [],
  List<String> cautions = const [],
}) =>
    TrialReadinessStatement(
      statusLabel: actionItems.isEmpty
          ? 'Export ready'
          : 'In progress — review before export',
      summaryText: actionItems.isEmpty
          ? 'Trial is ready for export and analysis.'
          : 'Trial is not currently export-ready.',
      reasons: const [],
      actionItems: List.unmodifiable(actionItems),
      cautions: List.unmodifiable(cautions),
      isReadyForExport: actionItems.isEmpty,
    );

TrialPurposeDto _purpose() => const TrialPurposeDto(
      trialId: 1,
      purposeStatus: 'confirmed',
      claimBeingTested: null,
      missingIntentFields: [],
      provenanceSummary: 'test',
      canDriveReadinessClaims: true,
    );

TrialCtqItemDto _photoEvidenceMissing() => const TrialCtqItemDto(
      factorKey: 'photo_evidence',
      label: 'Photo Evidence',
      importance: 'critical',
      status: 'missing',
      evidenceSummary: 'No plot photos captured.',
      reason: 'Photo evidence is required before export.',
      source: 'system',
    );

TrialCtqDto _ctq([List<TrialCtqItemDto> items = const []]) => TrialCtqDto(
      trialId: 1,
      ctqItems: items,
      blockerCount: items.where((item) => item.status == 'blocked').length,
      warningCount: items.where((item) => item.status == 'missing').length,
      reviewCount: items.where((item) => item.status == 'review_needed').length,
      satisfiedCount: items.where((item) => item.status == 'satisfied').length,
      overallStatus: items.isEmpty ? 'ready_for_review' : 'review_needed',
    );

TrialCoherenceDto _coherence() => TrialCoherenceDto(
      coherenceState: 'aligned',
      checks: const [
        TrialCoherenceCheckDto(
          checkKey: 'design_alignment',
          label: 'Design alignment',
          status: 'aligned',
          reason: '',
          sourceFields: [],
        ),
      ],
      computedAt: DateTime(2026, 1, 1),
    );

TrialInterpretationRiskDto _risk({
  List<TrialRiskFactorDto> factors = const [],
}) =>
    TrialInterpretationRiskDto(
      riskLevel: factors.any((factor) => factor.severity == 'high')
          ? 'high'
          : factors.any((factor) => factor.severity == 'moderate')
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

EnvironmentalSeasonSummaryDto _environment({
  String confidence = 'measured',
}) =>
    EnvironmentalSeasonSummaryDto(
      totalPrecipitationMm: 12,
      totalFrostEvents: 0,
      totalExcessiveRainfallEvents: 0,
      daysWithData: 10,
      daysExpected: 10,
      overallConfidence: confidence,
    );

Widget _wrapSized({
  required double width,
  required double height,
  required Trial trial,
  TrialReadinessStatement? statement,
  TrialCtqDto? ctq,
  TrialInterpretationRiskDto? risk,
  void Function(TrialTab tab)? onSwitchTab,
}) {
  final resolvedStatement = statement ?? _statement();
  return MediaQuery(
    data: MediaQueryData(size: Size(width, height)),
    child: ProviderScope(
      overrides: [
        environmentalEnsureTodayBackgroundEnabledProvider
            .overrideWithValue(false),
        trialReadinessStatementProvider((
          trialId: trial.id,
          trialState: trial.status,
        )).overrideWith((_) => AsyncValue.data(resolvedStatement)),
        amendedRatingCountForTrialProvider(trial.id)
            .overrideWith((_) => Stream.value(0)),
        trialPurposeProvider(trial.id).overrideWith(
          (_) => Stream.value(_purpose()),
        ),
        trialCriticalToQualityProvider(trial.id).overrideWith(
          (_) => Stream.value(ctq ?? _ctq()),
        ),
        trialCoherenceProvider(trial.id).overrideWith(
          (_) => Stream.value(_coherence()),
        ),
        trialInterpretationRiskProvider(trial.id).overrideWith(
          (_) => Stream.value(risk ?? _risk()),
        ),
        projectedOpenSignalGroupsForTrialProvider(trial.id).overrideWith(
          (_) => Stream.value(const <SignalReviewGroupProjection>[]),
        ),
        openSignalsForTrialProvider(trial.id).overrideWith(
          (_) => Stream.value(const <Signal>[]),
        ),
        trialEnvironmentalSummaryProvider(trial.id).overrideWith(
          (_) => Stream.value(_environment()),
        ),
        trialEnvironmentalProvenanceProvider(trial.id).overrideWith(
          (_) => Stream.value(null),
        ),
        assessmentDefinitionsProvider.overrideWith(
          (_) => Stream.value(const <AssessmentDefinition>[]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrialOverviewTab(
            trial: trial,
            onSwitchTab: onSwitchTab,
          ),
        ),
      ),
    ),
  );
}

void _expectTextOrder(WidgetTester tester, List<String> labels) {
  var previousY = double.negativeInfinity;
  for (final label in labels) {
    // findRichText: true ensures RichText nodes (not just Text widgets) are
    // matched; .first handles cases where the same substring appears in both
    // a parent label (e.g. "Add: Photo Evidence") and the block heading.
    final finder = find.textContaining(label, findRichText: true).first;
    final y = tester.getTopLeft(finder).dy;
    expect(y, greaterThan(previousY), reason: '$label should render in order.');
    previousY = y;
  }
}

void main() {
  group('TrialOverviewTab responsive layout', () {
    testWidgets('phone and tablet viewports have no synchronous exceptions', (
      WidgetTester tester,
    ) async {
      final trial = _trial();

      await tester.pumpWidget(
        _wrapSized(width: 390, height: 844, trial: trial),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _wrapSized(width: 834, height: 1194, trial: trial),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the four Trial Review blocks in order', (
      WidgetTester tester,
    ) async {
      final trial = _trial();
      await tester.pumpWidget(_wrapSized(
        width: 390,
        height: 844,
        trial: trial,
        statement: _statement(
          actionItems: const ['Add: Photo Evidence'],
          cautions: const ['Known site or season context needs review.'],
        ),
        ctq: _ctq([_photoEvidenceMissing()]),
        risk: _risk(factors: const [_highRisk]),
      ));
      await tester.pumpAndSettle();

      _expectTextOrder(tester, const [
        'In progress — review before export',
        'Photo Evidence',
        'Data variability',
        'Review pending checks',
      ]);
    });

    testWidgets('passes onSwitchTab through to RequiredBlock', (
      WidgetTester tester,
    ) async {
      final trial = _trial();
      TrialTab? selectedTab;
      await tester.pumpWidget(_wrapSized(
        width: 390,
        height: 844,
        trial: trial,
        statement: _statement(actionItems: const ['Add: Photo Evidence']),
        ctq: _ctq([_photoEvidenceMissing()]),
        onSwitchTab: (tab) => selectedTab = tab,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Photos'));
      await tester.pump();

      expect(selectedTab, TrialTab.photos);
    });
  });
}
