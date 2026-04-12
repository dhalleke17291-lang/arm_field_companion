/// Holds CSV file contents for a full trial export (flat bundle + companion files).
class TrialExportBundle {
  const TrialExportBundle({
    required this.observationsCsv,
    required this.observationsArmTransferCsv,
    required this.treatmentsCsv,
    required this.plotAssignmentsCsv,
    required this.applicationsCsv,
    required this.seedingCsv,
    required this.sessionsCsv,
    required this.notesCsv,
    required this.dataDictionaryCsv,
    this.statisticsCsv,
    this.warningMessage,
    this.preflightNotes,
  });

  /// Set when import compatibility confidence was low (warn path).
  final String? warningMessage;

  /// Export validation warnings/info (non-blocking) from preflight for flat CSV.
  final List<String>? preflightNotes;

  final String observationsCsv;
  /// ARM-aligned manual-transfer companion; does not replace observations.csv.
  final String observationsArmTransferCsv;
  final String treatmentsCsv;
  final String plotAssignmentsCsv;
  final String applicationsCsv;
  final String seedingCsv;
  final String sessionsCsv;
  final String notesCsv;
  final String dataDictionaryCsv;

  /// Statistical analysis CSV (ANOVA, means with letters). Standalone trials only.
  final String? statisticsCsv;
}
