import '../../core/database/app_database.dart';

/// Canonical resolved context for a plot.
/// Screens consume this — they never resolve plot/treatment truth themselves.
class PlotContext {
  final Plot plot;
  final Treatment? treatment;
  final List<TreatmentComponent> components;

  const PlotContext({
    required this.plot,
    required this.treatment,
    required this.components,
  });

  // Convenience getters
  String get plotId => plot.plotId;
  int? get rep => plot.rep;
  String get treatmentCode => treatment?.code ?? '—';
  String get treatmentName => treatment?.name ?? 'Unassigned';
  bool get hasTreatment => treatment != null;
  bool get hasComponents => components.isNotEmpty;

  /// Display label shown in field UI — e.g. "Plot 101 · T2"
  String get displayLabel {
    final tCode = treatment?.code;
    return tCode != null ? '${plot.plotId} · $tCode' : plot.plotId;
  }
}
