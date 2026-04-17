import '../../core/database/app_database.dart';

/// Canonical resolved context for a plot.
/// Screens consume this — they never resolve plot/treatment truth themselves.
class PlotContext {
  final Plot plot;
  final Treatment? treatment;
  final List<TreatmentComponent> components;

  /// Set when a plot/assignment references a treatment id, including if that treatment is soft-deleted.
  final int? assignedTreatmentId;

  const PlotContext({
    required this.plot,
    required this.treatment,
    required this.components,
    this.assignedTreatmentId,
  });

  // Convenience getters
  String get plotId => plot.plotId;
  int? get rep => plot.rep;
  String get treatmentCode => treatment?.code ?? '—';
  String get treatmentName => treatment?.name ?? 'Unassigned';
  bool get hasTreatment => treatment != null;

  /// Assignment points at a treatment id that is not in the active protocol list (e.g. soft-deleted).
  bool get hasRemovedTreatment =>
      treatment == null && assignedTreatmentId != null;

  bool get hasComponents => components.isNotEmpty;

  /// True when this plot is an untreated check / control based on treatment
  /// code convention (CHK, UTC, CONTROL) or treatment type flag.
  bool get isUntreatedCheck {
    final code = treatment?.code.trim().toUpperCase();
    if (code == 'CHK' || code == 'UTC' || code == 'CONTROL') return true;
    final type = treatment?.treatmentType?.trim().toUpperCase();
    if (type == 'CHK' || type == 'UTC' || type == 'CONTROL') return true;
    return false;
  }

  /// Display label shown in field UI — e.g. "Plot 101 · T2"
  String get displayLabel {
    final tCode = treatment?.code;
    if (tCode != null) return '${plot.plotId} · $tCode';
    if (assignedTreatmentId != null) return '${plot.plotId} · (removed)';
    return plot.plotId;
  }
}
