import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/plots/rep_guard_plot_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Plot _p(
  int id,
  String plotId, {
  int? rep,
  int? plotSortIndex,
  bool isGuardRow = false,
}) {
  return Plot(
    id: id,
    trialId: 1,
    plotId: plotId,
    plotSortIndex: plotSortIndex,
    rep: rep,
    treatmentId: null,
    row: null,
    column: null,
    fieldRow: null,
    fieldColumn: null,
    assignmentSource: null,
    assignmentUpdatedAt: null,
    plotLengthM: null,
    plotWidthM: null,
    plotAreaM2: null,
    harvestLengthM: null,
    harvestWidthM: null,
    harvestAreaM2: null,
    plotDirection: null,
    soilSeries: null,
    plotNotes: null,
    isGuardRow: isGuardRow,
    isDeleted: false,
    deletedAt: null,
    deletedBy: null,
    excludeFromAnalysis: false,
  );
}

void main() {
  test('one rep two research plots plans left and right flanks', () {
    final plots = [
      _p(1, '101', rep: 1, plotSortIndex: 10),
      _p(2, '102', rep: 1, plotSortIndex: 20),
    ];
    final plan = planRepGuardPlotInserts(plots);
    expect(plan.length, 2);
    expect(plan.map((e) => e.plotId).toSet(), {'G1-L', 'G1-R'});
    final left = plan.firstWhere((e) => e.plotId == 'G1-L');
    final right = plan.firstWhere((e) => e.plotId == 'G1-R');
    expect(left.plotSortIndex, lessThan(10));
    expect(right.plotSortIndex, greaterThan(20));
    expect(left.layoutRep, 1);
    expect(right.layoutRep, 1);
  });

  test('idempotent when guards already present', () {
    final plots = [
      _p(1, '101', rep: 1, plotSortIndex: 10),
      _p(2, '102', rep: 1, plotSortIndex: 20),
      _p(3, 'G1-L', rep: 1, plotSortIndex: 5, isGuardRow: true),
      _p(4, 'G1-R', rep: 1, plotSortIndex: 25, isGuardRow: true),
    ];
    expect(planRepGuardPlotInserts(plots), isEmpty);
  });

  test('two reps yields four plans', () {
    final plots = [
      _p(1, 'A', rep: 1, plotSortIndex: 1),
      _p(2, 'B', rep: 2, plotSortIndex: 1),
    ];
    final plan = planRepGuardPlotInserts(plots);
    expect(plan.length, 4);
    expect(plan.map((e) => e.plotId).toSet(),
        {'G1-L', 'G1-R', 'G2-L', 'G2-R'});
  });

  test('skip rep with only guard plots', () {
    final plots = [
      _p(1, 'G1-L', rep: 1, plotSortIndex: 1, isGuardRow: true),
      _p(2, 'G1-R', rep: 1, plotSortIndex: 2, isGuardRow: true),
    ];
    expect(planRepGuardPlotInserts(plots), isEmpty);
  });

  test('fills missing right guard only', () {
    final plots = [
      _p(1, '101', rep: 1, plotSortIndex: 10),
      _p(2, 'G1-L', rep: 1, plotSortIndex: 5, isGuardRow: true),
    ];
    final plan = planRepGuardPlotInserts(plots);
    expect(plan.length, 1);
    expect(plan.single.plotId, 'G1-R');
    expect(plan.single.plotSortIndex, greaterThan(10));
  });

  test('all null rep groups as rep 1', () {
    final plots = [
      _p(1, 'X', rep: null, plotSortIndex: 1),
      _p(2, 'Y', rep: null, plotSortIndex: 2),
    ];
    final plan = planRepGuardPlotInserts(plots);
    expect(plan.length, 2);
    expect(plan.map((e) => e.plotId), containsAll(['G1-L', 'G1-R']));
  });
}
