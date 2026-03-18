import '../../core/database/app_database.dart';

/// One planned insert for a rep flank guard plot.
class RepGuardPlotPlan {
  const RepGuardPlotPlan({
    required this.plotId,
    required this.layoutRep,
    required this.plotSortIndex,
  });

  final String plotId;
  final int layoutRep;
  final int plotSortIndex;
}

/// Groups plots by layout rep (same rules as [buildRepBasedLayout]).
Map<int, List<Plot>> groupPlotsByLayoutRep(List<Plot> plots) {
  if (plots.isEmpty) return {};
  final sorted = List<Plot>.from(plots)
    ..sort((a, b) {
      final ra = a.rep ?? 0;
      final rb = b.rep ?? 0;
      if (ra != rb) return ra.compareTo(rb);
      final sa = a.plotSortIndex ?? a.id;
      final sb = b.plotSortIndex ?? b.id;
      if (sa != sb) return sa.compareTo(sb);
      return a.id.compareTo(b.id);
    });

  final hasRep = sorted.any((p) => p.rep != null);
  final map = <int, List<Plot>>{};
  if (hasRep) {
    for (final p in sorted) {
      final r = p.rep ?? 1;
      map.putIfAbsent(r, () => []).add(p);
    }
  } else {
    map[1] = sorted;
  }
  return map;
}

String repGuardPlotIdLeft(int layoutRep) => 'G$layoutRep-L';
String repGuardPlotIdRight(int layoutRep) => 'G$layoutRep-R';

int _sortKey(Plot p) => p.plotSortIndex ?? p.id;

/// Plans v1 rep flank guards: [G{rep}-L] and [G{rep}-R] per rep with research plots.
/// Skips reps with no research plots. Idempotent by plotId.
List<RepGuardPlotPlan> planRepGuardPlotInserts(List<Plot> plots) {
  final byRep = groupPlotsByLayoutRep(plots);
  final plans = <RepGuardPlotPlan>[];

  for (final entry in byRep.entries) {
    final layoutRep = entry.key;
    final repPlots = entry.value;
    final leftId = repGuardPlotIdLeft(layoutRep);
    final rightId = repGuardPlotIdRight(layoutRep);

    final research = repPlots
        .where((p) => p.plotId != leftId && p.plotId != rightId)
        .toList();
    if (research.isEmpty) continue;

    final usedKeys = repPlots.map(_sortKey).toSet();
    final minR = research.map(_sortKey).reduce((a, b) => a < b ? a : b);
    final maxR = research.map(_sortKey).reduce((a, b) => a > b ? a : b);

    final hasL = repPlots.any((p) => p.plotId == leftId);
    final hasR = repPlots.any((p) => p.plotId == rightId);

    if (!hasL) {
      var leftIdx = minR - 1;
      while (usedKeys.contains(leftIdx)) {
        leftIdx--;
      }
      usedKeys.add(leftIdx);
      plans.add(RepGuardPlotPlan(
        plotId: leftId,
        layoutRep: layoutRep,
        plotSortIndex: leftIdx,
      ));
    }

    if (!hasR) {
      var rightIdx = maxR + 1;
      while (usedKeys.contains(rightIdx)) {
        rightIdx++;
      }
      plans.add(RepGuardPlotPlan(
        plotId: rightId,
        layoutRep: layoutRep,
        plotSortIndex: rightIdx,
      ));
    }
  }

  return plans;
}
