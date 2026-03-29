/// Carries unresolved ARM treatment rate / application metadata until component
/// import is specified. Not persisted.
class ArmTreatmentImportNote {
  const ArmTreatmentImportNote({
    required this.treatmentCode,
    required this.treatmentName,
    this.rawRate,
    this.rawRateUnit,
    this.applCode,
    this.note,
  });

  final String treatmentCode;
  final String treatmentName;
  final String? rawRate;
  final String? rawRateUnit;
  final String? applCode;
  final String? note;
}
