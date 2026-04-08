/// One assessment column in an ARM Rating Shell (descriptor rows + column index).
class ArmColumnMap {
  const ArmColumnMap({
    required this.armColumnId,
    required this.columnLetter,
    required this.columnIndex,
    this.ratingDate,
    this.seDescription,
    this.seName,
    this.ratingType,
    this.ratingUnit,
    this.cropStageMaj,
    this.ratingTiming,
    this.numSubsamples,
  });

  /// Row index 7 — ARM Column ID (001EID); identity key, never empty when present.
  final String armColumnId;

  /// Excel column letter: C, D, E, …
  final String columnLetter;

  /// 0-based column index (A=0, B=1, C=2).
  final int columnIndex;

  final String? ratingDate;

  /// Row 14 — SE Description (0-based index).
  final String? seDescription;
  final String? seName;
  final String? ratingType;
  final String? ratingUnit;
  final String? cropStageMaj;
  final String? ratingTiming;
  final int? numSubsamples;
}
