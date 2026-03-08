import '../../core/database/app_database.dart';

/// Field layout model: position-only ordering.
/// Layout order is determined solely by rep and plot position (plotSortIndex).
/// Treatment assignment is separate and must never affect layout order or plot position.
/// Display numbers (101, 102, …) are field positions, not treatment identifiers.

/// One row of plots in the field layout (one rep).
class RepRow {
  final int repNumber;
  final List<Plot> plots;

  const RepRow({required this.repNumber, required this.plots});
}

/// One block: a group of rep rows (e.g. Rep 1–4).
class LayoutBlock {
  final int blockIndex;
  final List<RepRow> repRows;

  const LayoutBlock({required this.blockIndex, required this.repRows});
}

/// Rep-based bird's-eye layout: blocks → reps → plots per row.
/// Display number for a plot in a rep row: repNumber * 100 + positionInRep (101, 102, … 109, 201, …).
List<LayoutBlock> buildRepBasedLayout(
  List<Plot> plots, {
  int? repsPerBlock,
}) {
  if (plots.isEmpty) return [];

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
  final repToPlots = <int, List<Plot>>{};

  if (hasRep) {
    for (final p in sorted) {
      final r = p.rep ?? 1;
      repToPlots.putIfAbsent(r, () => []).add(p);
    }
  } else {
    repToPlots[1] = sorted;
  }

  final repNumbers = repToPlots.keys.toList()..sort();
  final repRows = repNumbers
      .map((r) => RepRow(repNumber: r, plots: repToPlots[r]!))
      .toList();

  if (repsPerBlock == null || repsPerBlock < 1) {
    return [LayoutBlock(blockIndex: 1, repRows: repRows)];
  }

  final blocks = <LayoutBlock>[];
  for (var i = 0; i < repRows.length; i += repsPerBlock) {
    final chunk = repRows.sublist(i, (i + repsPerBlock).clamp(0, repRows.length));
    if (chunk.isEmpty) continue;
    blocks.add(LayoutBlock(blockIndex: blocks.length + 1, repRows: chunk));
  }
  return blocks.isEmpty ? [LayoutBlock(blockIndex: 1, repRows: repRows)] : blocks;
}

/// Layout display number for a plot in a rep row: repNumber * 100 + position (1-based).
int layoutDisplayNumber(int repNumber, int positionInRep) {
  return repNumber * 100 + positionInRep;
}

/// Lightweight diagnostics for plot layout consistency (MVP).
/// Returns list of issue messages; empty if none.
List<String> checkPlotLayoutConsistency(List<Plot> plots) {
  final issues = <String>[];
  if (plots.isEmpty) return issues;

  final repToPlots = <int, List<Plot>>{};
  for (final p in plots) {
    final r = p.rep ?? 0;
    repToPlots.putIfAbsent(r, () => []).add(p);
  }

  for (final entry in repToPlots.entries) {
    final rep = entry.key;
    final list = entry.value;
    if (rep == 0) {
      issues.add('${list.length} plot(s) have no rep set');
      continue;
    }
    final sortIndices = list.map((p) => p.plotSortIndex ?? p.id).toList();
    final duplicates = sortIndices.length - sortIndices.toSet().length;
    if (duplicates > 0) {
      issues.add('Rep $rep: duplicate plotSortIndex or order (${duplicates + 1} plots share position)');
    }
  }

  final unassigned = plots.where((p) => p.treatmentId == null).length;
  if (unassigned > 0) {
    issues.add('$unassigned plot(s) unassigned (no treatment)');
  }

  return issues;
}

/// Block rule: schema does not yet model blocks. All trials are treated as single block.
/// When repsPerBlock is added to trial metadata, it can be wired here.
const bool kSingleBlockForNow = true;

/// Lightweight layout diagnostics: issues that may indicate broken or inconsistent plot setup.
class PlotLayoutDiagnostics {
  final List<String> noRep;
  final List<String> duplicatePositionInRep;
  final List<String> unassignedPlotLabels;
  final bool hasIssues;

  const PlotLayoutDiagnostics({
    this.noRep = const [],
    this.duplicatePositionInRep = const [],
    this.unassignedPlotLabels = const [],
  }) : hasIssues = false;

  PlotLayoutDiagnostics._({
    required this.noRep,
    required this.duplicatePositionInRep,
    required this.unassignedPlotLabels,
  }) : hasIssues = noRep.isNotEmpty ||
        duplicatePositionInRep.isNotEmpty ||
        unassignedPlotLabels.isNotEmpty;
}

PlotLayoutDiagnostics computePlotLayoutDiagnostics(
  List<Plot> plots,
  int? Function(Plot) displayNumber,
  String Function(Plot) displayLabel,
) {
  final noRep = <String>[];
  final duplicatePositionInRep = <String>[];
  final unassignedPlotLabels = <String>[];

  for (final p in plots) {
    if (p.rep == null) noRep.add(displayLabel(p));
  }

  final byRep = <int, List<Plot>>{};
  for (final p in plots) {
    final r = p.rep ?? 0;
    if (r > 0) byRep.putIfAbsent(r, () => []).add(p);
  }
  for (final entry in byRep.entries) {
    final nums = entry.value.map(displayNumber).whereType<int>().toList();
    final seen = <int>{};
    for (final n in nums) {
      if (!seen.add(n)) {
        duplicatePositionInRep.add('Rep ${entry.key}: duplicate position');
        break;
      }
    }
  }

  for (final p in plots) {
    if (p.treatmentId == null) unassignedPlotLabels.add(displayLabel(p));
  }

  return PlotLayoutDiagnostics._(
    noRep: noRep,
    duplicatePositionInRep: duplicatePositionInRep,
    unassignedPlotLabels: unassignedPlotLabels,
  );
}
