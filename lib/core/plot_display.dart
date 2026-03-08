import 'package:arm_field_companion/core/database/app_database.dart';

/// User-facing plot number: rep * 100 + positionInRep (e.g. 101, 102, … 109, 201, …).
/// Plot position and treatment assignment are separate; this is position only.
/// Use [sameTrialPlots] sorted by rep, then plotSortIndex, then id (repository order).
int? getDisplayPlotNumber(Plot plot, List<Plot> sameTrialPlots) {
  final rep = plot.rep;
  if (rep == null) return null;
  final inRep = sameTrialPlots
      .where((p) => p.rep == rep)
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

/// Single label for UI: "101" or fallback (plotId / P{id}).
String getDisplayPlotLabel(Plot plot, List<Plot> sameTrialPlots) {
  final n = getDisplayPlotNumber(plot, sameTrialPlots);
  return n != null ? '$n' : getDisplayPlotNumberFallback(plot);
}

/// Treatment label for UI: treatment code or "Unassigned".
String getTreatmentDisplayLabel(Plot plot, Map<int, Treatment> treatmentById) {
  if (plot.treatmentId == null) return 'Unassigned';
  final t = treatmentById[plot.treatmentId];
  return t?.code ?? 'Unassigned';
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
