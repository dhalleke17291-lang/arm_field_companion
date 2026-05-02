import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/diagnostics/completeness_dashboard_screen.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [TrialReadinessReport] with exactly the provided checks.
TrialReadinessReport _report(List<TrialReadinessCheck> checks) =>
    TrialReadinessReport(checks: checks);

/// Pumps [CompletenessDashboardScreen] with the given report override.
Future<void> _pumpScreen(
  WidgetTester tester,
  TrialReadinessReport report,
  Trial trial,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trialReadinessProvider(trial.id)
            .overrideWith((ref) => Stream.value(report)),
      ],
      child: MaterialApp(
        home: CompletenessDashboardScreen(trial: trial),
      ),
    ),
  );
  await tester.pump();
}

Trial _trial() => Trial(
      id: 1,
      name: 'T',
      crop: null,
      location: null,
      season: null,
      status: 'active',
      workspaceType: 'efficacy',
      region: 'eppo_eu',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );

void main() {
  group('CompletenessDashboardScreen _sectionRows', () {
    testWidgets(
        'mixed section: blockers and warnings visible flat, '
        'info and passed collapsed', (tester) async {
      final trial = _trial();
      // All four codes belong to the Ratings section so they land in one section.
      final report = _report([
        const TrialReadinessCheck(
          code: 'bbch_missing',
          label: 'BBCH blocker',
          severity: TrialCheckSeverity.blocker,
        ),
        const TrialReadinessCheck(
          code: 'crop_injury_missing',
          label: 'Crop injury warning',
          severity: TrialCheckSeverity.warning,
        ),
        const TrialReadinessCheck(
          code: 'sessions_ok',
          label: 'Sessions exist',
          severity: TrialCheckSeverity.pass,
        ),
        const TrialReadinessCheck(
          code: 'ratings_ok',
          label: 'Ratings recorded',
          severity: TrialCheckSeverity.pass,
        ),
      ]);

      await _pumpScreen(tester, report, trial);

      // Blocker and warning labels are visible without tapping anything.
      expect(find.text('BBCH blocker'), findsOneWidget);
      expect(find.text('Crop injury warning'), findsOneWidget);

      // Passed checks are behind a collapsed tile — label hidden.
      expect(find.text('Sessions exist'), findsNothing);
      expect(find.text('Ratings recorded'), findsNothing);

      // Collapsed tile header shows correct count.
      expect(find.text('2 passed'), findsOneWidget);
    });

    testWidgets(
        'section with only passed checks: single collapsed tile, '
        'no flat rows', (tester) async {
      final trial = _trial();
      final report = _report([
        const TrialReadinessCheck(
          code: 'sessions_ok',
          label: 'Sessions exist',
          severity: TrialCheckSeverity.pass,
        ),
        const TrialReadinessCheck(
          code: 'ratings_ok',
          label: 'Ratings recorded',
          severity: TrialCheckSeverity.pass,
        ),
        const TrialReadinessCheck(
          code: 'all_rated_ok',
          label: 'All plots rated',
          severity: TrialCheckSeverity.pass,
        ),
      ]);

      await _pumpScreen(tester, report, trial);

      // No flat rows — all three are collapsed.
      expect(find.text('Sessions exist'), findsNothing);
      expect(find.text('Ratings recorded'), findsNothing);
      expect(find.text('All plots rated'), findsNothing);

      // Single collapsed tile with correct count.
      expect(find.text('3 passed'), findsOneWidget);

      // No info tile.
      expect(find.textContaining('informational'), findsNothing);
    });
  });
}
