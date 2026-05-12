import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/trials/tabs/plots_tab.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

TrialApplicationEvent _event(
  String id, {
  required int? treatmentId,
  required String status,
}) {
  return TrialApplicationEvent(
    id: id,
    trialId: 1,
    treatmentId: treatmentId,
    applicationDate: DateTime(2026, 1, 1),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

Plot _plot({
  required int id,
  required String plotId,
  required int rep,
  required int fieldColumn,
}) =>
    Plot(
      id: id,
      trialId: 1,
      plotId: plotId,
      fieldRow: rep,
      fieldColumn: fieldColumn,
      rep: rep,
      plotSortIndex: null,
      treatmentId: null,
      row: null,
      column: null,
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
      isGuardRow: false,
      isDeleted: false,
      deletedAt: null,
      deletedBy: null,
      excludeFromAnalysis: false,
      exclusionReason: null,
      damageType: null,
      armPlotNumber: null,
      armImportDataRowIndex: null,
    );

void main() {
  // ─── buildTreatmentAppState ────────────────────────────────────────────────

  group('buildTreatmentAppState', () {
    test('1 — returns empty map for empty event list', () {
      expect(buildTreatmentAppState([]), isEmpty);
    });

    test('2 — single pending event maps treatment to "pending"', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
      ]);
      expect(result, {10: 'pending'});
    });

    test('3 — single applied event maps treatment to "applied"', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'applied'),
      ]);
      expect(result, {10: 'applied'});
    });

    test('4 — applied wins when pending comes first for same treatmentId', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
        _event('e2', treatmentId: 10, status: 'applied'),
      ]);
      expect(result[10], 'applied');
    });

    test('5 — applied is not overwritten by a later pending event', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'applied'),
        _event('e2', treatmentId: 10, status: 'pending'),
      ]);
      expect(result[10], 'applied');
    });

    test('6 — events with null treatmentId are skipped', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: null, status: 'applied'),
      ]);
      expect(result, isEmpty);
    });

    test('7 — distinct treatment IDs are tracked independently', () {
      final result = buildTreatmentAppState([
        _event('e1', treatmentId: 10, status: 'pending'),
        _event('e2', treatmentId: 11, status: 'applied'),
      ]);
      expect(result[10], 'pending');
      expect(result[11], 'applied');
    });
  });

  group('shared plot layout geometry', () {
    test('uses treatment-layout width geometry for rep-based grids', () {
      final plots = [
        _plot(id: 1, plotId: '101', rep: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '102', rep: 1, fieldColumn: 2),
        _plot(id: 3, plotId: '103', rep: 1, fieldColumn: 3),
        _plot(id: 4, plotId: '201', rep: 2, fieldColumn: 1),
        _plot(id: 5, plotId: '202', rep: 2, fieldColumn: 2),
        _plot(id: 6, plotId: '203', rep: 2, fieldColumn: 3),
      ];

      // 52 rep label + 6 gutter + three 56px cells + two 6px gaps
      // + 24 horizontal grid padding + 8 rounding buffer.
      expect(plotLayoutContentWidthForTesting(plots, 0), 270);
    });

    test('does not shrink below the visible viewport width', () {
      final plots = [
        _plot(id: 1, plotId: '101', rep: 1, fieldColumn: 1),
      ];

      expect(plotLayoutContentWidthForTesting(plots, 400), 400);
    });
  });
}
