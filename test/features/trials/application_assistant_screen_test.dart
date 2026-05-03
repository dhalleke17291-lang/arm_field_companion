import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/application_assistant_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Plot _plot(int id, {int? treatmentId, int rep = 1, bool isGuardRow = false}) {
  return Plot(
    id: id,
    trialId: 1,
    plotId: '$id',
    isGuardRow: isGuardRow,
    isDeleted: false,
    excludeFromAnalysis: false,
    treatmentId: treatmentId,
    rep: rep,
    plotSortIndex: id,
  );
}

void main() {
  // ─── plotsForTreatment ─────────────────────────────────────────────────────

  group('plotsForTreatment', () {
    final p1 = _plot(1, treatmentId: 10);
    final p2 = _plot(2, treatmentId: 11);
    final p3 = _plot(3, treatmentId: 10);

    test('1 — returns plots matching targetTreatmentId via plot.treatmentId',
        () {
      final result = plotsForTreatment(
        allTrialPlots: [p1, p2, p3],
        plotIdToTreatmentId: {},
        targetTreatmentId: 10,
      );
      expect(result.map((p) => p.id).toList()..sort(), [1, 3]);
    });

    test('2 — uses assignment map override over plot.treatmentId', () {
      // p2 has treatmentId 11 on the plot row, but assignment says 10
      final result = plotsForTreatment(
        allTrialPlots: [p1, p2, p3],
        plotIdToTreatmentId: {p2.id: 10},
        targetTreatmentId: 10,
      );
      expect(result.map((p) => p.id).toList()..sort(), [1, 2, 3]);
    });

    test('3 — returns empty list when targetTreatmentId is null', () {
      final result = plotsForTreatment(
        allTrialPlots: [p1, p2, p3],
        plotIdToTreatmentId: {},
        targetTreatmentId: null,
      );
      expect(result, isEmpty);
    });

    test('4 — returns empty list when no plot matches target treatment', () {
      final result = plotsForTreatment(
        allTrialPlots: [p1, p2, p3],
        plotIdToTreatmentId: {},
        targetTreatmentId: 99,
      );
      expect(result, isEmpty);
    });
  });

  // ─── assistantProgressCount ────────────────────────────────────────────────

  group('assistantProgressCount', () {
    final current = [_plot(1, treatmentId: 10), _plot(3, treatmentId: 10)];

    test('5 — returns 0 when nothing is tapped', () {
      expect(assistantProgressCount({}, current), 0);
    });

    test('6 — returns count of tapped plots that are in currentTreatmentPlots',
        () {
      expect(assistantProgressCount({1}, current), 1);
      expect(assistantProgressCount({1, 3}, current), 2);
    });

    test('7 — does not count tapped PKs outside currentTreatmentPlots', () {
      // plot PK 2 is not in current treatment plots
      expect(assistantProgressCount({2}, current), 0);
      expect(assistantProgressCount({1, 2}, current), 1);
    });

    test('8 — returns full count when all current-treatment plots are tapped',
        () {
      expect(assistantProgressCount({1, 3}, current), current.length);
    });
  });

  // ─── applyAssistantFilter ──────────────────────────────────────────────────

  group('applyAssistantFilter', () {
    final all = [
      _plot(1, treatmentId: 10),
      _plot(2, treatmentId: 11),
      _plot(3, treatmentId: 10),
    ];
    final current = [all[0], all[2]]; // plots 1 and 3

    test('9 — filter all returns every trial plot', () {
      final result = applyAssistantFilter(
        filter: AssistantFilter.all,
        allTrialPlots: all,
        currentTreatmentPlots: current,
        tappedPks: {1},
      );
      expect(result, all);
    });

    test('10 — filter remaining returns untapped current-treatment plots', () {
      final result = applyAssistantFilter(
        filter: AssistantFilter.remaining,
        allTrialPlots: all,
        currentTreatmentPlots: current,
        tappedPks: {1},
      );
      expect(result.map((p) => p.id).toList(), [3]);
    });

    test('11 — filter done returns tapped current-treatment plots', () {
      final result = applyAssistantFilter(
        filter: AssistantFilter.done,
        allTrialPlots: all,
        currentTreatmentPlots: current,
        tappedPks: {1},
      );
      expect(result.map((p) => p.id).toList(), [1]);
    });

    test('12 — filter remaining returns empty when all current plots tapped',
        () {
      final result = applyAssistantFilter(
        filter: AssistantFilter.remaining,
        allTrialPlots: all,
        currentTreatmentPlots: current,
        tappedPks: {1, 3},
      );
      expect(result, isEmpty);
    });

    test('13 — filter done returns empty when no current plots tapped', () {
      final result = applyAssistantFilter(
        filter: AssistantFilter.done,
        allTrialPlots: all,
        currentTreatmentPlots: current,
        tappedPks: {},
      );
      expect(result, isEmpty);
    });
  });
}
