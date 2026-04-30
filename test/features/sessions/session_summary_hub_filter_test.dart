import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/sessions/session_summary_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 4, 29);

Trial _trial({int id = 1}) => Trial(
      id: id,
      name: 'Hub Filter Trial',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: _now,
      updatedAt: _now,
      isDeleted: false,
    );

Session _session({int id = 1, int trialId = 1}) => Session(
      id: id,
      trialId: trialId,
      name: 'Session 1',
      startedAt: _now,
      sessionDateLocal: '2026-04-29',
      status: 'open',
      isDeleted: false,
    );

Plot _plot(int id, {int trialId = 1, int? rep}) => Plot(
      id: id,
      trialId: trialId,
      plotId: 'P$id',
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: false,
      rep: rep,
    );

Plot _guardPlot(int id) => Plot(
      id: id,
      trialId: 1,
      plotId: 'G$id',
      isGuardRow: true,
      isDeleted: false,
      excludeFromAnalysis: false,
    );

Plot _excludedPlot(int id) => Plot(
      id: id,
      trialId: 1,
      plotId: 'X$id',
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: true,
    );

// ---------------------------------------------------------------------------
// Widget pump helper
// ---------------------------------------------------------------------------

/// Pumps [SessionSummaryScreen] with provider overrides for the given plots
/// and ratedPks. All other providers return empty-data / loading (graceful
/// fallbacks are used throughout the screen).
Future<void> _pumpScreen(
  WidgetTester tester, {
  required Trial trial,
  required Session session,
  required List<Plot> plots,
  required Set<int> ratedPks,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        plotsForTrialProvider(trial.id).overrideWith(
          (ref) => Stream.value(plots),
        ),
        sessionAssessmentsProvider(session.id).overrideWith(
          (ref) => Stream.value(<Assessment>[]),
        ),
        sessionRatingsProvider(session.id).overrideWith(
          (ref) => Stream.value(<RatingRecord>[]),
        ),
        ratedPlotPksProvider(session.id).overrideWith(
          (ref) => Stream.value(ratedPks),
        ),
      ],
      child: MaterialApp(
        home: SessionSummaryScreen(trial: trial, session: session),
      ),
    ),
  );
  // Let async providers resolve and widget rebuild.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final trial = _trial();
  final session = _session();
  final plot1 = _plot(1, rep: 1); // will be rated
  final plot2 = _plot(2, rep: 1); // will be unrated

  group('SessionSummaryScreen hub filter strip', () {
    testWidgets('default state — filter strip renders with Unrated chip',
        (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id},
      );

      // Filter strip should be visible in Plots view (default).
      expect(find.text('Unrated'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
      expect(find.text('Flagged'), findsOneWidget);

      // No count label when no filter is active.
      expect(find.textContaining('Showing'), findsNothing);
      // No Reset pill when inactive.
      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('tapping Unrated shows filtered count', (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id}, // plot1 rated, plot2 unrated
      );

      await tester.tap(find.text('Unrated'));
      await tester.pump();

      // Count label appears.
      expect(find.textContaining('Showing 1 of 2 plots'), findsOneWidget);
      // Reset pill appears.
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Reset clears filter and hides count label', (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id},
      );

      // Activate filter.
      await tester.tap(find.text('Unrated'));
      await tester.pump();
      expect(find.textContaining('Showing'), findsOneWidget);

      // Reset.
      await tester.tap(find.text('Reset'));
      await tester.pump();

      // Count label gone.
      expect(find.textContaining('Showing'), findsNothing);
      // Reset pill gone.
      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('all-filtered-out shows empty state message', (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id, plot2.id}, // both rated → Unrated returns zero
      );

      await tester.tap(find.text('Unrated'));
      await tester.pump();

      expect(
        find.text('No plots match these filters.'),
        findsOneWidget,
      );
      // Clear filters button inside empty state.
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('rep chips appear when plots have reps', (tester) async {
      final p1 = _plot(1, rep: 1);
      final p2 = _plot(2, rep: 2);

      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [p1, p2],
        ratedPks: {},
      );

      expect(find.text('Rep 1'), findsOneWidget);
      expect(find.text('Rep 2'), findsOneWidget);
    });

    testWidgets('rep filter limits visible count', (tester) async {
      final p1 = _plot(1, rep: 1);
      final p2 = _plot(2, rep: 2);

      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [p1, p2],
        ratedPks: {},
      );

      await tester.tap(find.text('Rep 1'));
      await tester.pump();

      expect(find.textContaining('Showing 1 of 2 plots'), findsOneWidget);
    });

    testWidgets('switching to Treatments view hides filter strip',
        (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id},
      );

      // Filter strip visible initially.
      expect(find.text('Unrated'), findsOneWidget);

      // Switch to Treatments view.
      await tester.tap(find.text('Treatments'));
      await tester.pump();

      // Filter strip no longer rendered.
      expect(find.text('Unrated'), findsNothing);
    });

    testWidgets(
        'hub filter denominator matches header data plot count when guard row present',
        (tester) async {
      final guard = _guardPlot(99);
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [guard, plot1, plot2],
        ratedPks: {plot1.id},
      );

      expect(find.textContaining('· 2 plots'), findsOneWidget);

      await tester.tap(find.text('Unrated'));
      await tester.pump();

      expect(find.textContaining('Showing 1 of 2 plots'), findsOneWidget);
    });

    testWidgets(
        'hub filter denominator matches header when excludeFromAnalysis plot present',
        (tester) async {
      final excluded = _excludedPlot(98);
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [excluded, plot1, plot2],
        ratedPks: {plot1.id},
      );

      expect(find.textContaining('· 2 plots'), findsOneWidget);

      await tester.tap(find.text('Unrated'));
      await tester.pump();

      expect(find.textContaining('Showing 1 of 2 plots'), findsOneWidget);
    });

    // ── Stats footer tests ───────────────────────────────────────────────────

    testWidgets('stats footer shows rated and unrated counts', (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id}, // 1 rated, 1 unrated
      );

      // Footer must mention both dimensions.
      expect(find.textContaining('1 rated'), findsOneWidget);
      expect(find.textContaining('1 unrated'), findsOneWidget);
    });

    testWidgets('stats footer counts reflect active Unrated filter',
        (tester) async {
      // Three plots: plot1 rated, plot2 unrated, plot3 unrated.
      final plot3 = _plot(3, rep: 1);
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2, plot3],
        ratedPks: {plot1.id},
      );

      // Before filter: footer shows full set (1 rated, 2 unrated).
      expect(find.textContaining('1 rated'), findsOneWidget);
      expect(find.textContaining('2 unrated'), findsOneWidget);

      // Activate Unrated filter → only 2 plots visible.
      await tester.tap(find.text('Unrated'));
      await tester.pump();

      // Footer now reflects the filtered set (0 rated, 2 unrated).
      expect(find.textContaining('0 rated'), findsOneWidget);
      expect(find.textContaining('2 unrated'), findsOneWidget);
    });

    testWidgets('stats footer is absent in Treatments view', (tester) async {
      await _pumpScreen(
        tester,
        trial: trial,
        session: session,
        plots: [plot1, plot2],
        ratedPks: {plot1.id},
      );

      // Footer visible initially (Plots view) — use count-prefixed text to
      // avoid false match on the "Unrated" filter pill.
      expect(find.textContaining('1 rated'), findsOneWidget);

      // Switch to Treatments view.
      await tester.tap(find.text('Treatments'));
      await tester.pump();

      // Footer no longer rendered.
      expect(find.textContaining('1 rated'), findsNothing);
    });
  });
}
