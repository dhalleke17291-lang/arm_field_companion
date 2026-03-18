import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/plot_sort.dart';

// Minimal Plot factory for tests — only fields used by sortPlotsSerpentine
Plot _plot({
  required int id,
  required String plotId,
  int? fieldRow,
  int? fieldColumn,
  int? rep,
  int? plotSortIndex,
}) =>
    Plot(
      id: id,
      trialId: 1,
      plotId: plotId,
      fieldRow: fieldRow,
      fieldColumn: fieldColumn,
      rep: rep,
      plotSortIndex: plotSortIndex,
      treatmentId: null,
      row: null,
      column: null,
      notes: null,
      assignmentSource: null,
      assignmentUpdatedAt: null,
      isGuardRow: false,
      isDeleted: false,
    );

void main() {
  group('sortPlotsSerpentine — grid plots', () {
    test('single row sorts columns ascending', () {
      final plots = [
        _plot(id: 3, plotId: '003', fieldRow: 1, fieldColumn: 3),
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3]);
    });

    test('two rows — row 1 ascending, row 2 descending (serpentine)', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
        _plot(id: 3, plotId: '003', fieldRow: 1, fieldColumn: 3),
        _plot(id: 4, plotId: '004', fieldRow: 2, fieldColumn: 1),
        _plot(id: 5, plotId: '005', fieldRow: 2, fieldColumn: 2),
        _plot(id: 6, plotId: '006', fieldRow: 2, fieldColumn: 3),
      ];
      final sorted = sortPlotsSerpentine(plots);
      // Row 1 (index 0, even): C1→C2→C3
      // Row 2 (index 1, odd): C3→C2→C1
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3, 6, 5, 4]);
    });

    test('three rows — alternating direction', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
        _plot(id: 3, plotId: '003', fieldRow: 2, fieldColumn: 1),
        _plot(id: 4, plotId: '004', fieldRow: 2, fieldColumn: 2),
        _plot(id: 5, plotId: '005', fieldRow: 3, fieldColumn: 1),
        _plot(id: 6, plotId: '006', fieldRow: 3, fieldColumn: 2),
      ];
      final sorted = sortPlotsSerpentine(plots);
      // Row 1 (even): 1→2
      // Row 2 (odd):  4→3
      // Row 3 (even): 5→6
      expect(sorted.map((p) => p.id).toList(), [1, 2, 4, 3, 5, 6]);
    });

    test('input order does not affect output — always serpentine', () {
      final plots = [
        _plot(id: 6, plotId: '006', fieldRow: 2, fieldColumn: 3),
        _plot(id: 3, plotId: '003', fieldRow: 1, fieldColumn: 3),
        _plot(id: 4, plotId: '004', fieldRow: 2, fieldColumn: 1),
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 5, plotId: '005', fieldRow: 2, fieldColumn: 2),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3, 6, 5, 4]);
    });

    test('single plot returns single plot', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.length, 1);
      expect(sorted.first.id, 1);
    });

    test('empty list returns empty list', () {
      final sorted = sortPlotsSerpentine([]);
      expect(sorted, isEmpty);
    });
  });

  group('sortPlotsSerpentine — fallback (no grid coordinates)', () {
    test('falls back to rep → plotSortIndex → plotId when no fieldRow', () {
      final plots = [
        _plot(id: 3, plotId: '003', rep: 2, plotSortIndex: 1),
        _plot(id: 1, plotId: '001', rep: 1, plotSortIndex: 1),
        _plot(id: 2, plotId: '002', rep: 1, plotSortIndex: 2),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.map((p) => p.id).toList(), [1, 2, 3]);
    });

    test('fallback sorts by plotId when rep and sortIndex equal', () {
      final plots = [
        _plot(id: 3, plotId: '003', rep: 1, plotSortIndex: 1),
        _plot(id: 1, plotId: '001', rep: 1, plotSortIndex: 1),
        _plot(id: 2, plotId: '002', rep: 1, plotSortIndex: 1),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.map((p) => p.plotId).toList(), ['001', '002', '003']);
    });
  });

  group('sortPlotsSerpentine — mixed (some with grid, some without)', () {
    test('grid plots come first in serpentine order, non-grid appended', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
        _plot(id: 99, plotId: '099'), // no grid coords
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(sorted.first.id, 1);
      expect(sorted[1].id, 2);
      expect(sorted.last.id, 99);
    });
  });

  group('walkOrderIndexOf', () {
    test('returns correct index for known plot', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
        _plot(id: 2, plotId: '002', fieldRow: 1, fieldColumn: 2),
        _plot(id: 3, plotId: '003', fieldRow: 2, fieldColumn: 2),
        _plot(id: 4, plotId: '004', fieldRow: 2, fieldColumn: 1),
      ];
      final sorted = sortPlotsSerpentine(plots);
      expect(walkOrderIndexOf(sorted, 3), 2);
      expect(walkOrderIndexOf(sorted, 4), 3);
    });

    test('returns -1 for unknown plotPk', () {
      final plots = [
        _plot(id: 1, plotId: '001', fieldRow: 1, fieldColumn: 1),
      ];
      expect(walkOrderIndexOf(plots, 999), -1);
    });
  });
}
