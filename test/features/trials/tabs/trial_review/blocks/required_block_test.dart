import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/core/workspace/workspace_config.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_review_projection.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_review/blocks/required_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({String status = 'active'}) => Trial(
      id: 1,
      name: 'Required Trial',
      status: status,
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialReadinessStatement _statement(List<String> actionItems) =>
    TrialReadinessStatement(
      statusLabel: actionItems.isEmpty
          ? 'Export ready'
          : 'In progress — review before export',
      summaryText: actionItems.isEmpty
          ? 'Trial is ready for export and analysis.'
          : 'Trial is not currently export-ready.',
      reasons: const [],
      actionItems: List.unmodifiable(actionItems),
      cautions: const [],
      isReadyForExport: actionItems.isEmpty,
    );

TrialCtqItemDto _ctqItem({
  required String factorKey,
  required String label,
  required String status,
  String reason = 'Required evidence needs attention.',
  bool isAcknowledged = false,
}) =>
    TrialCtqItemDto(
      factorKey: factorKey,
      label: label,
      importance: 'critical',
      status: status,
      evidenceSummary: 'Test evidence summary.',
      reason: reason,
      source: 'system',
      isAcknowledged: isAcknowledged,
    );

TrialCtqDto _ctq(List<TrialCtqItemDto> items) => TrialCtqDto(
      trialId: 1,
      ctqItems: items,
      blockerCount: items.where((i) => i.status == 'blocked').length,
      warningCount: items.where((i) => i.status == 'missing').length,
      reviewCount: items.where((i) => i.status == 'review_needed').length,
      satisfiedCount: items.where((i) => i.status == 'satisfied').length,
      overallStatus: items.isEmpty ? 'ready_for_review' : 'review_needed',
    );

TrialCoherenceCheckDto _coherenceCheck({
  required String label,
  required String status,
  String reason = 'Coherence check needs attention.',
}) =>
    TrialCoherenceCheckDto(
      checkKey: label.toLowerCase().replaceAll(' ', '_'),
      label: label,
      status: status,
      reason: reason,
      sourceFields: const [],
    );

TrialCoherenceDto _coherence(
        [List<TrialCoherenceCheckDto> checks = const []]) =>
    TrialCoherenceDto(
      coherenceState: checks.isEmpty ? 'aligned' : 'review_needed',
      checks: checks,
      computedAt: DateTime(2026, 1, 1),
    );

TrialPurposeDto _purpose({bool requiresConfirmation = false}) =>
    TrialPurposeDto(
      trialId: 1,
      purposeStatus: requiresConfirmation ? 'draft' : 'confirmed',
      missingIntentFields: const [],
      provenanceSummary: 'Test purpose.',
      canDriveReadinessClaims: !requiresConfirmation,
      requiresConfirmation: requiresConfirmation,
    );

Signal _signal({
  int id = 10,
  String type = 'replication_warning',
  String severity = 'critical',
}) =>
    Signal(
      id: id,
      trialId: 1,
      sessionId: 7,
      plotId: null,
      signalType: type,
      moment: 2,
      severity: severity,
      raisedAt: 1000,
      raisedBy: null,
      referenceContext: '{}',
      magnitudeContext: null,
      consequenceText: 'Raw signal text.',
      status: 'open',
      createdAt: 1000,
    );

SignalReviewProjection _projection({
  int signalId = 10,
  String title = 'Replication pattern may affect results',
  bool blocksExport = true,
}) =>
    SignalReviewProjection(
      signalId: signalId,
      type: 'replication_warning',
      status: 'open',
      severity: blocksExport ? 'critical' : 'review',
      operationalState: SignalOperationalState.needsAction,
      displayTitle: title,
      shortSummary: 'The rated plot pattern may limit result confidence.',
      detailText: 'Raw signal text.',
      whyItMatters: 'Replication helps distinguish treatment effects.',
      recommendedAction: 'Review whether enough plots were rated.',
      statusLabel: 'Needs review',
      severityLabel:
          blocksExport ? 'Needs review before export' : 'Needs review',
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
    );

SignalReviewGroupProjection _signalGroup({
  int signalId = 10,
  String title = 'Replication pattern may affect results',
  bool blocksExport = true,
}) =>
    SignalReviewGroupProjection(
      groupId: 'group-$signalId',
      groupType: 'replication_warning',
      familyKey: SignalFamilyKey.replicationPattern,
      familyDefinition:
          'Multiple review items point to the same replication-pattern concern.',
      groupingBasis: 'Grouped for test.',
      familyScientificRole:
          'Replication helps distinguish treatment effects from field variability.',
      familyInterpretationImpact:
          'Irregular replication patterns may weaken treatment comparison reliability.',
      reviewQuestion: 'Are treatment comparisons still interpretable?',
      displayTitle: title,
      shortSummary: 'The rated plot pattern may limit result confidence.',
      whyItMatters: 'Replication helps distinguish treatment effects.',
      recommendedAction: 'Review whether enough plots were rated.',
      statusLabel: 'Needs review',
      severityLabel:
          blocksExport ? 'Needs review before export' : 'Needs review',
      signalCount: 1,
      affectedAssessmentIds: const [],
      affectedPlotIds: const [],
      affectedSessionIds: const [7],
      memberSignals: [_projection(signalId: signalId, title: title)],
    );

Widget _wrapBody({
  Trial? trial,
  TrialReadinessStatement? statement,
  TrialCtqDto? ctq,
  TrialCoherenceDto? coherence,
  List<SignalReviewGroupProjection> signalGroups = const [],
  List<Signal> rawSignals = const [],
  TrialPurposeDto? purpose,
  void Function(TrialTab tab)? onSwitchTab,
  void Function(TrialCtqItemDto item)? onOpenCtqAcknowledgment,
  void Function(Signal signal)? onOpenSignalAction,
  VoidCallback? onOpenIntent,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return ProviderScope(
    child: MaterialApp(
      navigatorObservers: navigatorObservers,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RequiredBlockBody(
            trial: trial ?? _trial(),
            statement: statement ?? _statement(const []),
            ctq: ctq ?? _ctq(const []),
            coherence: coherence ?? _coherence(),
            signalGroups: signalGroups,
            rawSignals: rawSignals,
            purpose: purpose ?? _purpose(),
            onSwitchTab: onSwitchTab ?? (_) {},
            onOpenCtqAcknowledgment: onOpenCtqAcknowledgment,
            onOpenSignalAction: onOpenSignalAction,
            onOpenIntent: onOpenIntent,
          ),
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
      trialCriticalToQualityProvider(trial.id)
          .overrideWith((_) => Stream.value(_ctq(const []))),
      trialCoherenceProvider(trial.id)
          .overrideWith((_) => Stream.value(_coherence())),
      projectedOpenSignalGroupsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(const [])),
      openSignalsForTrialProvider(trial.id)
          .overrideWith((_) => Stream.value(const [])),
      trialPurposeProvider(trial.id)
          .overrideWith((_) => Stream.value(_purpose())),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: RequiredBlock(
          trial: trial,
          onSwitchTab: (_) {},
        ),
      ),
    ),
  );
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('required-action-$label')));
  await tester.pump();
}

void _expectTextOrder(WidgetTester tester, List<String> labels) {
  var previousY = double.negativeInfinity;
  for (final label in labels) {
    final y = tester.getTopLeft(find.text(label)).dy;
    expect(y, greaterThan(previousY), reason: '$label should render in order.');
    previousY = y;
  }
}

class _PushCountingObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  group('RequiredBlock', () {
    testWidgets('RB-1: empty state hides the block', (tester) async {
      await tester.pumpWidget(_wrapBody());

      expect(find.byKey(const ValueKey('required-block-list')), findsNothing);
    });

    testWidgets('RB-2: plot completeness routes to Plots tab', (tester) async {
      TrialTab? selected;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Complete: Plot Completeness']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'plot_completeness',
            label: 'Plot Completeness',
            status: 'missing',
          ),
        ]),
        onSwitchTab: (tab) => selected = tab,
      ));

      await _tapAction(tester, 'Open Plots');

      expect(selected, TrialTab.plots);
    });

    testWidgets('RB-3: treatment identity routes to Treatments tab',
        (tester) async {
      TrialTab? selected;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Define: Treatment Identity']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'treatment_identity',
            label: 'Treatment Identity',
            status: 'missing',
          ),
        ]),
        onSwitchTab: (tab) => selected = tab,
      ));

      await _tapAction(tester, 'Open Treatments');

      expect(selected, TrialTab.treatments);
    });

    testWidgets('RB-4: photo evidence routes to Photos tab', (tester) async {
      TrialTab? selected;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Add: Photo Evidence']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'photo_evidence',
            label: 'Photo Evidence',
            status: 'missing',
          ),
        ]),
        onSwitchTab: (tab) => selected = tab,
      ));

      await _tapAction(tester, 'Open Photos');

      expect(selected, TrialTab.photos);
    });

    testWidgets('RB-5: application timing routes to Applications tab',
        (tester) async {
      TrialTab? selected;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Record: Application Timing']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'application_timing',
            label: 'Application Timing',
            status: 'missing',
          ),
        ]),
        onSwitchTab: (tab) => selected = tab,
      ));

      await _tapAction(tester, 'Open Applications');

      expect(selected, TrialTab.applications);
    });

    testWidgets('RB-6: rating window routes to Assessments tab',
        (tester) async {
      TrialTab? selected;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Record: Rating Window']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'rating_window',
            label: 'Rating Window',
            status: 'missing',
          ),
        ]),
        onSwitchTab: (tab) => selected = tab,
      ));

      await _tapAction(tester, 'Open Assessments');

      expect(selected, TrialTab.assessments);
    });

    testWidgets('RB-7: GPS evidence pushes the Data screen', (tester) async {
      final observer = _PushCountingObserver();
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Enable: GPS Evidence']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'gps_evidence',
            label: 'GPS Evidence',
            status: 'missing',
          ),
        ]),
        navigatorObservers: [observer],
      ));
      expect(observer.pushCount, 1);

      final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('required-action-View Data')),
      );
      button.onPressed!();

      expect(observer.pushCount, 2);
    });

    testWidgets('RB-8: CTQ review opens the acknowledgment sheet action',
        (tester) async {
      TrialCtqItemDto? opened;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Review: Plot Completeness']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'plot_completeness',
            label: 'Plot Completeness',
            status: 'review_needed',
          ),
        ]),
        onOpenCtqAcknowledgment: (item) => opened = item,
      ));

      await _tapAction(tester, 'Review');

      expect(opened?.factorKey, 'plot_completeness');
    });

    testWidgets('RB-9: signal-blocked group opens the signal action sheet',
        (tester) async {
      Signal? opened;
      final signal = _signal(id: 33);
      await tester.pumpWidget(_wrapBody(
        signalGroups: [_signalGroup(signalId: 33)],
        rawSignals: [signal],
        onOpenSignalAction: (signal) => opened = signal,
      ));

      await _tapAction(tester, 'Review signal');

      expect(opened?.id, 33);
    });

    testWidgets('RB-10: intent unconfirmed opens the intent sheet action',
        (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrapBody(
        purpose: _purpose(requiresConfirmation: true),
        onOpenIntent: () => opened = true,
      ));

      await _tapAction(tester, 'Confirm intent');

      expect(opened, isTrue);
    });

    testWidgets(
        'RB-11: rater consistency has disabled signal button without raw signal',
        (tester) async {
      Signal? opened;
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const ['Resolve: Rating Consistency']),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'rater_consistency',
            label: 'Rating Consistency',
            status: 'blocked',
          ),
        ]),
        onOpenSignalAction: (signal) => opened = signal,
      ));

      final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('required-action-Review signal')),
      );

      expect(button.onPressed, isNull);
      expect(find.byTooltip('No matching rater signal available.'),
          findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('required-action-Review signal')));
      await tester.pump();
      expect(opened, isNull);
    });

    testWidgets('RB-12: coherence actions render without action buttons',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const [
          'Review deviation: Application timing',
          'Provide missing input for: Primary endpoint',
        ]),
        coherence: _coherence([
          _coherenceCheck(
            label: 'Application timing',
            status: 'review_needed',
            reason: 'Application timing deviates from the claim window.',
          ),
          _coherenceCheck(
            label: 'Primary endpoint',
            status: 'cannot_evaluate',
            reason: 'Primary endpoint is not captured.',
          ),
        ]),
      ));

      expect(find.text('Application timing'), findsOneWidget);
      expect(
        find.text('Application timing deviates from the claim window.'),
        findsOneWidget,
      );
      expect(find.text('Primary endpoint'), findsOneWidget);
      expect(find.text('Primary endpoint is not captured.'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('RB-13: multiple CTQ items render in action order',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const [
          'Resolve: Plot Completeness',
          'Add: Photo Evidence',
          'Review: Treatment Identity',
        ]),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'treatment_identity',
            label: 'Treatment Identity',
            status: 'review_needed',
          ),
          _ctqItem(
            factorKey: 'photo_evidence',
            label: 'Photo Evidence',
            status: 'missing',
          ),
          _ctqItem(
            factorKey: 'plot_completeness',
            label: 'Plot Completeness',
            status: 'blocked',
          ),
        ]),
      ));

      expect(find.text('Plot Completeness'), findsOneWidget);
      expect(find.text('Photo Evidence'), findsOneWidget);
      expect(find.text('Treatment Identity'), findsOneWidget);
      _expectTextOrder(tester, [
        'Plot Completeness',
        'Photo Evidence',
        'Treatment Identity',
      ]);
    });

    testWidgets('RB-14: provider error renders overview error', (tester) async {
      await tester.pumpWidget(_wrapProvider(
        statementValue: AsyncValue.error(Exception('boom'), StackTrace.current),
      ));

      expect(find.text('Unable to load.'), findsOneWidget);
    });

    testWidgets('RB-15: provider loading renders overview loading',
        (tester) async {
      await tester.pumpWidget(_wrapProvider(
        statementValue: const AsyncValue.loading(),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('RB-16: render order is preserved through action types',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        statement: _statement(const [
          'Add: Photo Evidence',
          'Provide missing input for: Primary endpoint',
        ]),
        ctq: _ctq([
          _ctqItem(
            factorKey: 'photo_evidence',
            label: 'Photo Evidence',
            status: 'missing',
          ),
        ]),
        coherence: _coherence([
          _coherenceCheck(
            label: 'Primary endpoint',
            status: 'cannot_evaluate',
          ),
        ]),
        signalGroups: [
          _signalGroup(title: 'Critical signal group'),
        ],
        rawSignals: [_signal()],
        purpose: _purpose(requiresConfirmation: true),
      ));

      _expectTextOrder(tester, [
        'Photo Evidence',
        'Primary endpoint',
        'Critical signal group',
        'Intent — not yet confirmed',
      ]);
    });
  });
}
