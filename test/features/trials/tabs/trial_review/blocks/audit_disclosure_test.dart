import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/design/app_design_tokens.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_coherence_dto.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_ctq_dto.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_overview/_overview_card.dart';
import 'package:arm_field_companion/features/trials/tabs/trial_review/blocks/audit_disclosure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial() => Trial(
      id: 1,
      name: 'Audit Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      region: 'eppo_eu',
      isDeleted: false,
    );

TrialCtqItemDto _ctq({
  required String label,
  required String status,
  String reason = 'CTQ reason.',
  bool isAcknowledged = false,
}) =>
    TrialCtqItemDto(
      factorKey: label.toLowerCase().replaceAll(' ', '_'),
      label: label,
      importance: 'critical',
      status: status,
      evidenceSummary: 'Evidence summary.',
      reason: reason,
      source: 'system',
      isAcknowledged: isAcknowledged,
    );

TrialCoherenceCheckDto _check({
  required String label,
  required String status,
  String reason = 'Coherence reason.',
}) =>
    TrialCoherenceCheckDto(
      checkKey: label.toLowerCase().replaceAll(' ', '_'),
      label: label,
      status: status,
      reason: reason,
      sourceFields: const [],
    );

TrialCoherenceDto _coherenceDto(List<TrialCoherenceCheckDto> checks) =>
    TrialCoherenceDto(
      coherenceState: 'review_needed',
      checks: checks,
      computedAt: DateTime(2026, 1, 1),
    );

Widget _wrapBody({
  List<TrialCtqItemDto> ctqItems = const [],
  List<TrialCoherenceCheckDto> coherenceChecks = const [],
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AuditDisclosureBody(
          ctqItems: ctqItems,
          coherenceChecks: coherenceChecks,
        ),
      ),
    ),
  );
}

Widget _wrapProvider({
  required AsyncValue<TrialCtqDto> ctqValue,
  required AsyncValue<TrialCoherenceDto> coherenceValue,
}) {
  final trial = _trial();
  return ProviderScope(
    overrides: [
      trialCriticalToQualityProvider(trial.id).overrideWith((_) {
        return ctqValue.when(
          data: (value) => Stream.value(value),
          loading: () => const Stream<TrialCtqDto>.empty(),
          error: (error, stackTrace) =>
              Stream<TrialCtqDto>.error(error, stackTrace),
        );
      }),
      trialCoherenceProvider(trial.id).overrideWith((_) {
        return coherenceValue.when(
          data: (value) => Stream.value(value),
          loading: () => const Stream<TrialCoherenceDto>.empty(),
          error: (error, stackTrace) =>
              Stream<TrialCoherenceDto>.error(error, stackTrace),
        );
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AuditDisclosure(trial: trial),
      ),
    ),
  );
}

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.textContaining('Show all checks'));
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

OverviewStatusChip _chip(WidgetTester tester, String label) {
  return tester.widget<OverviewStatusChip>(find.widgetWithText(
    OverviewStatusChip,
    label,
  ));
}

void main() {
  group('AuditDisclosure', () {
    testWidgets('AD-1: empty state still renders the collapsed header',
        (tester) async {
      await tester.pumpWidget(_wrapBody());

      expect(
        find.text('Show all checks (0 satisfied, 0 pending)'),
        findsOneWidget,
      );

      await _expand(tester);

      expect(find.text('No checks evaluated yet.'), findsOneWidget);
    });

    testWidgets('AD-2: loading state renders overview loading', (tester) async {
      await tester.pumpWidget(_wrapProvider(
        ctqValue: const AsyncValue.loading(),
        coherenceValue: AsyncValue.data(_coherenceDto(const [])),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('AD-3: error state renders overview error', (tester) async {
      await tester.pumpWidget(_wrapProvider(
        ctqValue: AsyncValue.error(Exception('boom'), StackTrace.current),
        coherenceValue: AsyncValue.data(_coherenceDto(const [])),
      ));

      await tester.pump();

      expect(find.text('Unable to load.'), findsOneWidget);
    });

    testWidgets('AD-4: header counts satisfied and pending checks',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [
          for (var i = 1; i <= 5; i++)
            _ctq(label: 'Satisfied CTQ $i', status: 'satisfied'),
          _ctq(label: 'Missing CTQ 1', status: 'missing'),
          _ctq(label: 'Missing CTQ 2', status: 'missing'),
        ],
        coherenceChecks: [
          for (var i = 1; i <= 3; i++)
            _check(label: 'Aligned Check $i', status: 'aligned'),
          _check(label: 'Review Check', status: 'review_needed'),
        ],
      ));

      expect(
        find.text('Show all checks (8 satisfied, 3 pending)'),
        findsOneWidget,
      );
    });

    testWidgets('AD-5: list is collapsed by default', (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [_ctq(label: 'Plot Completeness', status: 'satisfied')],
      ));

      expect(find.text('Plot Completeness'), findsNothing);
      expect(find.textContaining('Show all checks'), findsOneWidget);
    });

    testWidgets('AD-6: tapping header expands the list', (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [_ctq(label: 'Plot Completeness', status: 'satisfied')],
      ));

      await _expand(tester);

      expect(find.text('Hide all checks'), findsOneWidget);
      expect(find.text('Plot Completeness'), findsOneWidget);
    });

    testWidgets('AD-7: tapping header again collapses the list',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [_ctq(label: 'Plot Completeness', status: 'satisfied')],
      ));

      await _expand(tester);
      await tester.tap(find.text('Hide all checks'));
      await tester.pump();

      expect(find.text('Plot Completeness'), findsNothing);
      expect(find.textContaining('Show all checks'), findsOneWidget);
    });

    testWidgets('AD-8: status pills render expected labels and colors',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [
          _ctq(label: 'Satisfied CTQ', status: 'satisfied'),
          _ctq(label: 'Missing CTQ', status: 'missing'),
          _ctq(label: 'Review CTQ', status: 'review_needed'),
          _ctq(label: 'Blocked CTQ', status: 'blocked'),
          _ctq(label: 'Unknown CTQ', status: 'unknown'),
        ],
        coherenceChecks: [
          _check(label: 'Aligned Coherence', status: 'aligned'),
          _check(label: 'Cannot Coherence', status: 'cannot_evaluate'),
        ],
      ));

      await _expand(tester);

      expect(_chip(tester, 'Satisfied').bg, AppDesignTokens.successBg);
      expect(_chip(tester, 'Missing').bg, AppDesignTokens.warningBg);
      expect(_chip(tester, 'Review needed').bg, AppDesignTokens.partialBg);
      expect(_chip(tester, 'Blocked').bg, AppDesignTokens.warningBg);
      expect(_chip(tester, 'Not evaluated').bg, AppDesignTokens.emptyBadgeBg);
      expect(_chip(tester, 'Aligned').bg, AppDesignTokens.successBg);
      expect(
        _chip(tester, 'Cannot evaluate').bg,
        AppDesignTokens.emptyBadgeBg,
      );
    });

    testWidgets('AD-9: reason text renders only when non-empty',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [
          _ctq(
            label: 'Has Reason',
            status: 'missing',
            reason: 'This reason should render.',
          ),
          _ctq(label: 'No Reason', status: 'satisfied', reason: ''),
        ],
      ));

      await _expand(tester);

      expect(find.text('This reason should render.'), findsOneWidget);
      expect(find.text(''), findsNothing);
    });

    testWidgets('AD-10: acknowledged marker renders only for acknowledged CTQ',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [
          _ctq(
            label: 'Acknowledged CTQ',
            status: 'review_needed',
            isAcknowledged: true,
          ),
          _ctq(label: 'Plain CTQ', status: 'review_needed'),
        ],
      ));

      await _expand(tester);

      expect(find.text('Acknowledged'), findsOneWidget);
    });

    testWidgets('AD-11: CTQ rows render before coherence rows', (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [_ctq(label: 'CTQ First', status: 'satisfied')],
        coherenceChecks: [_check(label: 'Coherence Second', status: 'aligned')],
      ));

      await _expand(tester);

      _expectTextOrder(tester, ['CTQ First', 'Coherence Second']);
    });

    testWidgets('AD-12: provider order is preserved within each group',
        (tester) async {
      await tester.pumpWidget(_wrapBody(
        ctqItems: [
          _ctq(label: 'CTQ A', status: 'satisfied'),
          _ctq(label: 'CTQ B', status: 'missing'),
        ],
        coherenceChecks: [
          _check(label: 'Coherence A', status: 'aligned'),
          _check(label: 'Coherence B', status: 'review_needed'),
        ],
      ));

      await _expand(tester);

      _expectTextOrder(tester, [
        'CTQ A',
        'CTQ B',
        'Coherence A',
        'Coherence B',
      ]);
    });
  });
}
