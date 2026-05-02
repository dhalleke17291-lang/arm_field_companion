import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_plot_predicates.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RatingRecord _rating({
  required int id,
  required int plotPk,
  String status = 'RECORDED',
  bool amended = false,
  int? previousId,
}) {
  final now = DateTime.now().toUtc();
  return RatingRecord(
    id: id,
    trialId: 1,
    sessionId: 1,
    plotPk: plotPk,
    assessmentId: 1,
    resultStatus: status,
    isCurrent: true,
    createdAt: now,
    amended: amended,
    previousId: previousId,
    isDeleted: false,
  );
}

Plot _plot(int id, {int? rep}) => Plot(
      id: id,
      trialId: 1,
      plotId: 'P$id',
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: false,
      rep: rep,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── plotHasRatingIssues ────────────────────────────────────────────────────

  group('plotHasRatingIssues', () {
    test('empty list → false', () {
      expect(plotHasRatingIssues([]), isFalse);
    });

    test('all RECORDED → false', () {
      expect(
        plotHasRatingIssues([
          _rating(id: 1, plotPk: 1),
          _rating(id: 2, plotPk: 1),
        ]),
        isFalse,
      );
    });

    test('VOID → true', () {
      expect(
        plotHasRatingIssues([_rating(id: 1, plotPk: 1, status: 'VOID')]),
        isTrue,
      );
    });

    test('any non-RECORDED → true', () {
      expect(
        plotHasRatingIssues([
          _rating(id: 1, plotPk: 1),
          _rating(id: 2, plotPk: 1, status: 'DEFERRED'),
        ]),
        isTrue,
      );
    });
  });

  // ── plotHasEdits ───────────────────────────────────────────────────────────

  group('plotHasEdits', () {
    test('no amendments, no correction → false', () {
      expect(
        plotHasEdits([_rating(id: 1, plotPk: 1)], hasCorrection: false),
        isFalse,
      );
    });

    test('amended rating → true', () {
      expect(
        plotHasEdits(
          [_rating(id: 1, plotPk: 1, amended: true)],
          hasCorrection: false,
        ),
        isTrue,
      );
    });

    test('previousId set → true', () {
      expect(
        plotHasEdits(
          [_rating(id: 2, plotPk: 1, previousId: 1)],
          hasCorrection: false,
        ),
        isTrue,
      );
    });

    test('correction flag alone → true', () {
      expect(
        plotHasEdits([], hasCorrection: true),
        isTrue,
      );
    });

    test('empty ratings, no correction → false', () {
      expect(plotHasEdits([], hasCorrection: false), isFalse);
    });
  });

  // ── plotIsRated ────────────────────────────────────────────────────────────

  group('plotIsRated', () {
    test('pk in set → true', () {
      expect(plotIsRated(1, {1, 2}), isTrue);
    });

    test('pk not in set → false', () {
      expect(plotIsRated(3, {1, 2}), isFalse);
    });

    test('empty set → false', () {
      expect(plotIsRated(1, {}), isFalse);
    });
  });

  // ── plotIsFlagged ──────────────────────────────────────────────────────────

  group('plotIsFlagged', () {
    test('pk in set → true', () {
      expect(plotIsFlagged(5, {5, 6}), isTrue);
    });

    test('pk not in set → false', () {
      expect(plotIsFlagged(7, {5, 6}), isFalse);
    });
  });

  // ── countPlotStatus ────────────────────────────────────────────────────────

  group('countPlotStatus', () {
    test('all-clean session returns correct counts', () {
      final plots = [_plot(1), _plot(2), _plot(3)];
      final ratingsByPlot = {
        1: [_rating(id: 1, plotPk: 1)],
        2: [_rating(id: 2, plotPk: 2)],
        3: [_rating(id: 3, plotPk: 3)],
      };
      final ratedPks = {1, 2, 3};
      final counts = countPlotStatus(
        plots: plots,
        ratingsByPlot: ratingsByPlot,
        ratedPks: ratedPks,
        flaggedIds: {},
        correctionPlotPks: {},
      );

      expect(counts.total, 3);
      expect(counts.rated, 3);
      expect(counts.unrated, 0);
      expect(counts.flagged, 0);
      expect(counts.withIssues, 0);
      expect(counts.edited, 0);
    });

    test('mixed session accumulates each dimension correctly', () {
      final plots = [_plot(1), _plot(2), _plot(3), _plot(4)];
      final ratingsByPlot = {
        1: [_rating(id: 1, plotPk: 1)],
        2: [_rating(id: 2, plotPk: 2, status: 'VOID')],
        3: [_rating(id: 3, plotPk: 3, amended: true)],
        // plot 4: no ratings (unrated)
      };
      final ratedPks = {1, 2, 3}; // plot 4 unrated
      final flaggedIds = {2, 4};
      final correctionPlotPks = {1};

      final counts = countPlotStatus(
        plots: plots,
        ratingsByPlot: ratingsByPlot,
        ratedPks: ratedPks,
        flaggedIds: flaggedIds,
        correctionPlotPks: correctionPlotPks,
      );

      expect(counts.total, 4);
      expect(counts.rated, 3);
      expect(counts.unrated, 1);
      expect(counts.flagged, 2);   // plots 2 and 4
      expect(counts.withIssues, 1); // plot 2 is VOID
      expect(counts.edited, 2);    // plot 3 (amended) + plot 1 (correction)
    });

    test('empty plot list returns all zeros', () {
      final counts = countPlotStatus(
        plots: [],
        ratingsByPlot: {},
        ratedPks: {},
        flaggedIds: {},
        correctionPlotPks: {},
      );

      expect(counts.total, 0);
      expect(counts.rated, 0);
      expect(counts.unrated, 0);
      expect(counts.flagged, 0);
      expect(counts.withIssues, 0);
      expect(counts.edited, 0);
    });
  });

  // ── applyPlotQueueFilters ──────────────────────────────────────────────────

  group('applyPlotQueueFilters', () {
    final plots = [
      _plot(1, rep: 1),
      _plot(2, rep: 1),
      _plot(3, rep: 2),
      _plot(4, rep: 2),
    ];
    final ratingsByPlot = {
      1: [_rating(id: 1, plotPk: 1)],
      2: [_rating(id: 2, plotPk: 2, status: 'VOID')],
      3: [_rating(id: 3, plotPk: 3, amended: true)],
      // plot 4: unrated
    };
    final ratedPks = {1, 2, 3};
    final flaggedIds = {3};
    final correctionPlotPks = <int>{};

    List<Plot> run({
      int? repFilter,
      bool unratedOnly = false,
      bool issuesOnly = false,
      bool editedOnly = false,
      bool flaggedOnly = false,
    }) =>
        applyPlotQueueFilters(
          plotsInWalkOrder: plots,
          ratedPks: ratedPks,
          ratingsByPlot: ratingsByPlot,
          flaggedIds: flaggedIds,
          correctionPlotPks: correctionPlotPks,
          repFilter: repFilter,
          unratedOnly: unratedOnly,
          issuesOnly: issuesOnly,
          editedOnly: editedOnly,
          flaggedOnly: flaggedOnly,
        );

    test('no filters → all plots returned in input order', () {
      expect(run().map((p) => p.id), [1, 2, 3, 4]);
    });

    test('repFilter=1 → only rep-1 plots', () {
      expect(run(repFilter: 1).map((p) => p.id), [1, 2]);
    });

    test('repFilter=2 → only rep-2 plots', () {
      expect(run(repFilter: 2).map((p) => p.id), [3, 4]);
    });

    test('unratedOnly → only plot 4', () {
      expect(run(unratedOnly: true).map((p) => p.id), [4]);
    });

    test('issuesOnly → only plot 2 (VOID)', () {
      expect(run(issuesOnly: true).map((p) => p.id), [2]);
    });

    test('editedOnly → only plot 3 (amended)', () {
      expect(run(editedOnly: true).map((p) => p.id), [3]);
    });

    test('flaggedOnly → only plot 3', () {
      expect(run(flaggedOnly: true).map((p) => p.id), [3]);
    });

    test('rep=1 + unratedOnly → empty (both rep-1 plots are rated)', () {
      expect(run(repFilter: 1, unratedOnly: true), isEmpty);
    });

    test('rep=2 + unratedOnly → only plot 4', () {
      expect(run(repFilter: 2, unratedOnly: true).map((p) => p.id), [4]);
    });
  });
}
