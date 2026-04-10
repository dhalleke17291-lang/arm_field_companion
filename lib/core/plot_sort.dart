import 'database/app_database.dart';

/// Data plots only — guard rows ([Plot.isGuardRow]) are excluded from walk / rating order.
List<Plot> plotsForWalkOrder(List<Plot> plots) =>
    plots.where((p) => !p.isGuardRow).toList();

/// Walk order mode for session plot navigation (numbering is unchanged; only navigation order).
enum WalkOrderMode {
  /// 101 → 102 → 103 → 201 → 202... (rep asc, then plot order within rep).
  numeric,

  /// Odd reps forward, even reps backward: 101→102→105, 205→204→201, 301→...
  serpentine,

  /// User-defined order (placeholder: same as serpentine until custom UI exists).
  custom,
}

/// Sorts plots in numeric order: rep ascending, then plot order within rep (plotSortIndex / numeric plotId).
/// Does not change plot IDs or labels; only the sequence used for navigation.
/// Excludes [Plot.isGuardRow] plots (layout-only; not part of the rating walk).
List<Plot> sortPlotsNumeric(List<Plot> plots) {
  final sorted = [...plotsForWalkOrder(plots)];
  sorted.sort((a, b) {
    final repCmp = (a.rep ?? 999).compareTo(b.rep ?? 999);
    if (repCmp != 0) return repCmp;
    return _comparePlotOrderWithinRep(a, b);
  });
  return sorted;
}

/// Returns plots in the requested walk order.
/// For [WalkOrderMode.custom], pass [customPlotIds] (ordered plot PKs); if null or empty, falls back to serpentine.
/// Excludes guard rows — see [plotsForWalkOrder].
List<Plot> sortPlotsByWalkOrder(
  List<Plot> plots,
  WalkOrderMode mode, {
  List<int>? customPlotIds,
}) {
  final dataPlots = plotsForWalkOrder(plots);
  switch (mode) {
    case WalkOrderMode.numeric:
      return sortPlotsNumeric(dataPlots);
    case WalkOrderMode.serpentine:
      return sortPlotsSerpentine(dataPlots);
    case WalkOrderMode.custom:
      if (customPlotIds != null && customPlotIds.isNotEmpty) {
        return sortPlotsByCustomOrder(dataPlots, customPlotIds);
      }
      return sortPlotsSerpentine(dataPlots);
  }
}

/// Sorts plots to match [orderedPlotIds] (plot PKs). Plots not in the list are appended at the end in existing order.
/// Expects [plots] to already exclude guard rows (call via [sortPlotsByWalkOrder]).
List<Plot> sortPlotsByCustomOrder(List<Plot> plots, List<int> orderedPlotIds) {
  final idToPlot = {for (final p in plots) p.id: p};
  final result = <Plot>[];
  for (final id in orderedPlotIds) {
    final p = idToPlot[id];
    if (p != null) result.add(p);
  }
  for (final p in plots) {
    if (!orderedPlotIds.contains(p.id)) result.add(p);
  }
  return result;
}

/// Sorts plots into serpentine field-walking order.
///
/// When fieldRow/fieldColumn exist: row 1 forward, row 2 backward, row 3 forward, etc.
/// When not: group by rep, sort within rep by plotSortIndex/plotId; odd reps forward, even reps backward.
/// Excludes [Plot.isGuardRow] when [plots] is the full trial list — prefer [plotsForWalkOrder] first.
List<Plot> sortPlotsSerpentine(List<Plot> plots) {
  plots = plotsForWalkOrder(plots);
  final hasGrid = plots.any(
    (p) => p.fieldRow != null && p.fieldColumn != null,
  );

  if (!hasGrid) {
    return _serpentineByRep(plots);
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

  // Append non-grid plots at the end in rep-based serpentine order
  result.addAll(_serpentineByRep(nonGridPlots));
  return result;
}

/// Serpentine by rep: group by rep, sort reps by ascending rep number (position in list = 1st, 2nd, 3rd rep).
/// Sort plots within each rep by plotSortIndex then numeric plotId; alternate direction by rep position:
/// 1st rep forward, 2nd reverse, 3rd forward, etc. Handles uneven rep sizes and missing plots.
List<Plot> _serpentineByRep(List<Plot> plots) {
  final repMap = <int?, List<Plot>>{};
  for (final p in plots) {
    repMap.putIfAbsent(p.rep, () => []).add(p);
  }
  final repKeys = repMap.keys.toList()
    ..sort((a, b) => (a ?? 999).compareTo(b ?? 999));
  final out = <Plot>[];
  for (var i = 0; i < repKeys.length; i++) {
    final row = repMap[repKeys[i]]!;
    row.sort(_comparePlotOrderWithinRep);
    if (i.isOdd) {
      out.addAll(row.reversed);
    } else {
      out.addAll(row);
    }
  }
  return out;
}

/// Stable order within a rep: prefer plotSortIndex, then numeric plotId, then string plotId.
/// Avoids string sort giving 101, 102, 110, 111, 103.
int _comparePlotOrderWithinRep(Plot a, Plot b) {
  final idxCmp = (a.plotSortIndex ?? 999).compareTo(b.plotSortIndex ?? 999);
  if (idxCmp != 0) return idxCmp;
  final na = int.tryParse(a.plotId);
  final nb = int.tryParse(b.plotId);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.plotId.compareTo(b.plotId);
}

/// Returns the index of a plot in a walk-ordered list. Returns -1 if not found.
int walkOrderIndexOf(List<Plot> orderedPlots, int plotPk) {
  return orderedPlots.indexWhere((p) => p.id == plotPk);
}
