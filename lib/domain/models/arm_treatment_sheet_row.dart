/// One parsed row from the ARM Rating Shell's **Treatments** sheet
/// (sheet 7 in `AgQuest_RatingShell.xlsx`).
///
/// Phase 2a — parser output only. No DB writes consume this yet; slice
/// 2b wires it into [ImportArmRatingShellUseCase] where universal fields
/// land in [Treatments] / [TreatmentComponents] and ARM-specific coding
/// lands in [ArmTreatmentMetadata].
///
/// Sheet layout (see `test/fixtures/arm_shells/README.md`):
///
/// | Col | Label           | Example       | Classification |
/// |-----|-----------------|---------------|----------------|
/// | A   | Trt No.         | `1`, `2`      | universal (treatment code) |
/// | B   | Type            | `CHK`, `FUNG` | ARM (type code) |
/// | C   | Treatment Name  | `APRON`       | universal (product name) |
/// | D   | Form Conc       | `25`          | ARM (formulation concentration) |
/// | E   | Form Unit       | `%W/W`        | ARM (formulation-conc syntax) |
/// | F   | Form Type       | `W`           | ARM (formulation type code) |
/// | G   | Rate            | `5`           | universal (dose rate) |
/// | H   | Rate Unit       | `% w/v`       | universal (rate unit) |
///
/// All fields except [trtNumber] are nullable because ARM allows blank
/// cells (e.g. a `CHK` row typically has blank name / rate / formulation
/// — the untreated check has no product).
class ArmTreatmentSheetRow {
  const ArmTreatmentSheetRow({
    required this.trtNumber,
    required this.rowIndex,
    this.typeCode,
    this.treatmentName,
    this.formConc,
    this.formConcUnit,
    this.formType,
    this.rate,
    this.rateUnit,
  });

  /// ARM "Trt No." — the treatment number. Required; a row without a
  /// treatment number is not a treatment row and is dropped by the parser.
  final int trtNumber;

  /// 0-based sheet row position (data rows only — R3 → 0, R4 → 1, …).
  /// Written to [ArmTreatmentMetadata.armRowSortOrder] in slice 2b so
  /// export preserves the original Treatments-sheet ordering.
  final int rowIndex;

  /// ARM "Type" — short code such as `CHK` (check), `HERB` (herbicide),
  /// `FUNG` (fungicide). Nullable because some ARM templates leave it
  /// blank.
  final String? typeCode;

  /// ARM "Treatment Name" — the product name (e.g. `APRON`). Blank for
  /// untreated checks; slice 2b falls back to `"Treatment N"` when null.
  final String? treatmentName;

  /// ARM "Form Conc" — numeric formulation concentration (e.g. `25`).
  /// Parsed from text; null when blank or non-numeric.
  final double? formConc;

  /// ARM "Form Unit" — formulation-concentration syntax (e.g. `%W/W`,
  /// `%W/V`, `G/L`). Preserved verbatim.
  final String? formConcUnit;

  /// ARM "Form Type" — formulation-type code (e.g. `W`, `EC`, `SC`).
  /// Preserved verbatim.
  final String? formType;

  /// ARM "Rate" — numeric dose rate (e.g. `5`). Parsed from text; null
  /// when blank or non-numeric.
  final double? rate;

  /// ARM "Rate Unit" — dose-rate unit (e.g. `% w/v`, `lbs/ac`, `g/ha`).
  /// Universal concept; preserved verbatim for round-trip.
  final String? rateUnit;
}
