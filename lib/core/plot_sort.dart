import 'database/app_database.dart';

/// Sorts plots into serpentine field-walking order using fieldRow / fieldColumn.
///
/// Serpentine pattern (Range × Column grid):
///   Row 1: C1 → C2 → C3 → C4  (ascending)
///   Row 2: C4 → C3 → C2 → C1  (descending)
///   Row 3: C1 → C2 → C3 → C4  (ascending)
///
/// Falls back to rep → plotSortIndex → plotId if fieldRow/fieldColumn are null.
List<Plot> sortPlotsSerpentine(List<Plot> plots) {
  // Check if any plots have grid coordinates
  final hasGrid = plots.any(
    (p) => p.fieldRow != null && p.fieldColumn != null,
  );

  if (!hasGrid) {
    // Fallback: original sort
    final sorted = [...plots];
    sorted.sort((a, b) {
      final repCmp = (a.rep ?? 999).compareTo(b.rep ?? 999);
      if (repCmp != 0) return repCmp;
      final idxCmp = (a.plotSortIndex ?? 999).compareTo(b.plotSortIndex ?? 999);
      if (idxCmp != 0) return idxCmp;
      return a.plotId.compareTo(b.plotId);
    });
    return sorted;
  }

  // Separate plots with and without grid coordinates
  final gridPlots =
      plots.where((p) => p.fieldRow != null && p.fieldColumn != null).toList();
  final nonGridPlots =
      plots.where((p) => p.fieldRow == null || p.fieldColumn == null).toList();

  // Group by fieldRow
  final rowMap = <int, List<Plot>>{};
  for (final plot in gridPlots) {
    rowMap.putIfAbsent(plot.fieldRow!, () => []).add(plot);
  }

  // Sort rows ascending
  final sortedRowKeys = rowMap.keys.toList()..sort();

  final result = <Plot>[];
  for (var i = 0; i < sortedRowKeys.length; i++) {
    final rowPlots = rowMap[sortedRowKeys[i]]!;
    // Sort columns within row
    rowPlots.sort((a, b) => (a.fieldColumn!).compareTo(b.fieldColumn!));
    // Even index rows (0, 2, 4...) = ascending, odd = descending
    if (i.isOdd) {
      result.addAll(rowPlots.reversed);
    } else {
      result.addAll(rowPlots);
    }
  }

  // Append non-grid plots at the end using fallback sort
  nonGridPlots.sort((a, b) {
    final repCmp = (a.rep ?? 999).compareTo(b.rep ?? 999);
    if (repCmp != 0) return repCmp;
    final idxCmp = (a.plotSortIndex ?? 999).compareTo(b.plotSortIndex ?? 999);
    if (idxCmp != 0) return idxCmp;
    return a.plotId.compareTo(b.plotId);
  });
  result.addAll(nonGridPlots);

  return result;
}

/// Returns the serpentine index of a plot within a sorted list.
/// Returns -1 if not found.
int serpentineIndexOf(List<Plot> sortedPlots, int plotPk) {
  return sortedPlots.indexWhere((p) => p.id == plotPk);
}
