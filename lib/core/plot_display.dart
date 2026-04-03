import 'package:arm_field_companion/core/database/app_database.dart';

/// User-facing plot number: rep * 100 + positionInRep (e.g. 101, 102, … 109, 201, …).
/// Plot position and treatment assignment are separate; this is position only.
/// Use [sameTrialPlots] sorted by rep, then plotSortIndex, then id (repository order).
int? getDisplayPlotNumber(Plot plot, List<Plot> sameTrialPlots) {
  final rep = plot.rep;
  if (rep == null) return null;
  final inRep = sameTrialPlots.where((p) => p.rep == rep).toList()
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

/// Display label for guard rows: G{rep}-L → G{rep*100}, G{rep}-R → G{rep*100+10}.
/// Returns null if [plot] is not a guard row or plotId does not match.
String? getGuardDisplayLabel(Plot plot) {
  if (!plot.isGuardRow || plot.plotId.isEmpty) return null;
  final id = plot.plotId;
  final leftMatch = RegExp(r'^G(\d+)-L$').firstMatch(id);
  if (leftMatch != null) {
    final rep = int.tryParse(leftMatch.group(1) ?? '') ?? 0;
    return 'G${rep * 100}';
  }
  final rightMatch = RegExp(r'^G(\d+)-R$').firstMatch(id);
  if (rightMatch != null) {
    final rep = int.tryParse(rightMatch.group(1) ?? '') ?? 0;
    return 'G${rep * 100 + 10}';
  }
  return null;
}

/// Single label for UI: for guard rows G100/G110; else "101" or fallback (plotId / P{id}).
String getDisplayPlotLabel(Plot plot, List<Plot> sameTrialPlots) {
  final guardLabel = getGuardDisplayLabel(plot);
  if (guardLabel != null) return guardLabel;
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
