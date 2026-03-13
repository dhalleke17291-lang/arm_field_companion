/// Holds the seven CSV file contents for a full trial export.
/// All values are human-readable; no internal IDs in column values.
class TrialExportBundle {
  const TrialExportBundle({
    required this.observationsCsv,
    required this.treatmentsCsv,
    required this.plotAssignmentsCsv,
    required this.applicationsCsv,
    required this.seedingCsv,
    required this.sessionsCsv,
    required this.dataDictionaryCsv,
  });

  final String observationsCsv;
  final String treatmentsCsv;
  final String plotAssignmentsCsv;
  final String applicationsCsv;
  final String seedingCsv;
  final String sessionsCsv;
  final String dataDictionaryCsv;
}
