import 'package:arm_field_companion/core/database/app_database.dart';

/// User-facing plot number: rep * 100 + positionInRep (e.g. 101, 102, … 106, 201, …).
/// Plot position and treatment assignment are separate; this is position only.
///
/// Uses only **non–guard** plots in the rep for [positionInRep], so experimental
/// numbers stay stable when guard rows are present in [sameTrialPlots] or when
/// the UI passes a guard-filtered list. Guard rows use [getGuardDisplayLabel]
/// instead (see [getDisplayPlotLabel]).
int? getDisplayPlotNumber(Plot plot, List<Plot> sameTrialPlots) {
  final rep = plot.rep;
  if (rep == null) return null;
  if (plot.isGuardRow) return null;
  final inRep = sameTrialPlots
      .where((p) => p.rep == rep && !p.isGuardRow)
      .toList()
    ..sort((a, b) {
      final sa = a.plotSortIndex ?? a.id;
      final sb = b.plotSortIndex ?? b.id;
      if (sa != sb) return sa.compareTo(sb);
      return a.id.compareTo(b.id);
    });
  final idx = inRep.indexWhere((p) => p.id == plot.id);
  if (idx < 0) return null;
  final positionInRep = idx + 1;
  return rep * 100 + positionInRep;
}

/// Fallback when rep or position cannot be computed: show plotId or "P{id}".
/// Do not use for layout ordering; only for display when getDisplayPlotNumber returns null.
String getDisplayPlotNumberFallback(Plot plot) {
  if (plot.plotId.isNotEmpty) return plot.plotId;
  return 'P${plot.id}';
}

int _nonGuardPlotCountInRep(List<Plot> sameTrialPlots, int rep) {
  return sameTrialPlots.where((p) => p.rep == rep && !p.isGuardRow).length;
}

/// Display label for guard rows from stored [plot.plotId] patterns:
/// - `G{rep}-S{n}` / `G{rep}-E{n}` (wizard layout) → returned as-is by
///   [getDisplayPlotLabel]; this function returns null for those.
/// - `G{rep}-L` → **G{rep×100}** (left / rep-flank guard)
/// - `G{rep}-R` → **G{rep×100 + N + 1}** where **N** is the count of non-guard
///   plots in that rep in [sameTrialPlots] (same rep membership as
///   [getDisplayPlotNumber]; not affected by guard visibility when the list
///   contains every data plot for the trial).
///
/// Returns null if [plot] is not a guard row, [plotId] is empty, or pattern unknown.
String? getGuardDisplayLabel(Plot plot, List<Plot> sameTrialPlots) {
  if (!plot.isGuardRow) return null;
  final id = plot.plotId.trim();
  if (id.isEmpty) return null;
  if (RegExp(r'^G\d+-S\d+$').hasMatch(id) ||
      RegExp(r'^G\d+-E\d+$').hasMatch(id)) {
    return null;
  }
  final leftMatch = RegExp(r'^G(\d+)-L$').firstMatch(id);
  if (leftMatch != null) {
    final rep = int.tryParse(leftMatch.group(1) ?? '') ?? 0;
    return 'G${rep * 100}';
  }
  final rightMatch = RegExp(r'^G(\d+)-R$').firstMatch(id);
  if (rightMatch != null) {
    final rep = int.tryParse(rightMatch.group(1) ?? '') ?? 0;
    final n = _nonGuardPlotCountInRep(sameTrialPlots, rep);
    return 'G${rep * 100 + n + 1}';
  }
  return null;
}

/// Title Case list / app bar title for guard rows (`G{rep}-S{n}` / `G{rep}-E{n}`,
/// or legacy `G{rep}-L` / `G{rep}-R`).
String getGuardRowListTitle(Plot plot) {
  if (!plot.isGuardRow) return '';
  final id = plot.plotId.trim();
  if (RegExp(r'^G\d+-S\d+$').hasMatch(id)) return 'Guard (Start)';
  if (RegExp(r'^G\d+-E\d+$').hasMatch(id)) return 'Guard (End)';
  if (RegExp(r'^G\d+-L$').hasMatch(id)) return 'Guard (Start)';
  if (RegExp(r'^G\d+-R$').hasMatch(id)) return 'Guard (End)';
  return 'Guard Row';
}

/// Single label for UI badge/chip: wizard guards show [plot.plotId] (`G1-S1`, …);
/// rep-flank guards use [getGuardDisplayLabel] (e.g. G100, G107); legacy numeric
/// guard [plotId]s show `Guard`. Non-guard: experimental number or fallback.
String getDisplayPlotLabel(Plot plot, List<Plot> sameTrialPlots) {
  if (plot.isGuardRow) {
    final id = plot.plotId.trim();
    if (RegExp(r'^G\d+-S\d+$').hasMatch(id) ||
        RegExp(r'^G\d+-E\d+$').hasMatch(id)) {
      return id;
    }
    return getGuardDisplayLabel(plot, sameTrialPlots) ??
        (RegExp(r'^\d+$').hasMatch(id) ? 'Guard' : (id.isNotEmpty ? id : 'Guard'));
  }
  final n = getDisplayPlotNumber(plot, sameTrialPlots);
  return n != null ? '$n' : getDisplayPlotNumberFallback(plot);
}

/// Treatment label for UI: treatment code, '(removed)' if [tid] is set but the
/// treatment is missing (e.g. soft-deleted), or "Unassigned" when no treatment.
/// Use [treatmentIdOverride] when resolution is via Assignments (Plot → Assignment → Treatment).
String getTreatmentDisplayLabel(Plot plot, Map<int, Treatment> treatmentById,
    {int? treatmentIdOverride}) {
  final tid = treatmentIdOverride ?? plot.treatmentId;
  if (tid == null) return 'Unassigned';
  final t = treatmentById[tid];
  return t?.code ?? '(removed)';
}

/// Assignment source label: Imported | Manual | Unassigned | Unknown.
/// Pass [assignmentSource] from Plot.assignmentSource when available (schema v9+).
String getAssignmentSourceLabel({
  required int? treatmentId,
  String? assignmentSource,
}) {
  if (treatmentId == null) return 'Unassigned';
  if (assignmentSource == null || assignmentSource.isEmpty) return 'Unknown';
  switch (assignmentSource.toLowerCase()) {
    case 'imported':
      return 'Imported';
    case 'manual':
      return 'Manual';
    default:
      return 'Unknown';
  }
}
