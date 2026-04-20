/// One assessment column in an ARM Rating Shell (descriptor rows + column index).
class ArmColumnMap {
  const ArmColumnMap({
    required this.armColumnId,
    required this.columnLetter,
    required this.columnIndex,
    this.armColumnIdInteger,
    this.ratingDate,
    this.seDescription,
    this.seName,
    this.ratingType,
    this.ratingUnit,
    this.cropStageMaj,
    this.ratingTiming,
    this.numSubsamples,
    this.pestCode,
    this.partRated,
    this.collectBasis,
    this.appTimingCode,
    this.trtEvalInterval,
    this.datInterval,
  });

  /// Row 7 (0-based) — ARM Column ID string; identity key, never empty when present.
  final String armColumnId;

  /// ARM Column ID parsed as integer (e.g. 3, 6, 7, 8, 16). Null if non-numeric.
  final int? armColumnIdInteger;

  /// Excel column letter: C, D, E, …
  final String columnLetter;

  /// 0-based column index (A=0, B=1, C=2).
  final int columnIndex;

  final String? ratingDate;

  /// Row 14 (0-based) — SE Description.
  final String? seDescription;
  final String? seName;
  final String? ratingType;
  final String? ratingUnit;
  final String? cropStageMaj;
  final String? ratingTiming;
  final int? numSubsamples;

  /// Row 17 (0-based) — Pest code (W003, W001, CF013).
  final String? pestCode;
  /// Row 18 (0-based) — Part rated (PLANT, LEAF3).
  final String? partRated;
  /// Row 23 (0-based) — Collect basis (PLOT).
  final String? collectBasis;
  /// Row 41 (0-based) — App timing code (A1, A3, A6, A9, AA).
  final String? appTimingCode;
  /// Row 42 (0-based) — Treatment-evaluation interval (-28 DA-A, -7 DA-A).
  final String? trtEvalInterval;
  /// Row 43 (0-based) — DAT interval (-7 DP-1, 1 DP-1, 14 DP-1).
  final String? datInterval;
}
