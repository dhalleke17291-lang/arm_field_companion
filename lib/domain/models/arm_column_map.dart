/// One assessment column in an ARM Rating Shell (descriptor rows + column index).
///
/// Row indices in field docs are **0-based** (Excel row N → index N−1), matching
/// [parseArmShellBytes] and `test/fixtures/arm_shells/README.md` Excel rows.
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
    /// Row 9 (0-based) — ARM `003EPT` pest code cell; distinct from [seName].
    this.pestCodeFromSheet,
    this.partRated,
    /// Row 24 (0-based) — ARM `018EUS` Collect. Basis (was mis-read from row 23).
    this.collectBasis,
    /// Row 23 (0-based) — ARM `017EBU` size unit.
    this.sizeUnit,
    this.appTimingCode,
    this.trtEvalInterval,
    this.datInterval,
    this.pestType,
    this.pestName,
    this.cropCodeArm,
    this.cropNameArm,
    this.cropVariety,
    this.ratingTime,
    this.cropOrPest,
    this.sampleSize,
    this.collectionBasisUnit,
    this.reportingBasis,
    this.reportingBasisUnit,
    this.stageScale,
    this.cropStageMin,
    this.cropStageMax,
    this.cropDensity,
    this.cropDensityUnit,
    this.pestStageMaj,
    this.pestStageMin,
    this.pestStageMax,
    this.pestDensity,
    this.pestDensityUnit,
    this.assessedBy,
    this.equipment,
    this.untreatedRatingType,
    this.armActions,
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

  /// Row 9 (0-based) — ARM `003EPT` primary pest / EPPO-style code when present.
  final String? pestCodeFromSheet;

  /// Row 18 (0-based) — Part rated (PLANT, LEAF3).
  final String? partRated;

  /// Row 24 (0-based) — ARM `018EUS` Collect. Basis.
  final String? collectBasis;

  /// Row 23 (0-based) — ARM `017EBU` sample / size unit (e.g. PLOT).
  final String? sizeUnit;

  /// Row 41 (0-based) — App timing code (A1, A3, A6, A9, AA).
  final String? appTimingCode;

  /// Row 42 (0-based) — Treatment-evaluation interval (-28 DA-A, -7 DA-A).
  final String? trtEvalInterval;

  /// Row 43 (0-based) — Plant-eval / DAT interval (-7 DP-1, 1 DP-1, 14 DP-1).
  final String? datInterval;

  /// Row 8 (0-based) — `002E~P` Pest Type.
  final String? pestType;

  /// Row 10 (0-based) — `004EPG` Pest Name.
  final String? pestName;

  /// Row 11 (0-based) — `005ECR` Crop Code (descriptor; not trial-level crop).
  final String? cropCodeArm;

  /// Row 12 (0-based) — `006ECG` Crop Name.
  final String? cropNameArm;

  /// Row 13 (0-based) — `007ECV` Crop Variety.
  final String? cropVariety;

  /// Row 16 (0-based) — `010ETD` Rating Time.
  final String? ratingTime;

  /// Row 19 (0-based) — `013ERF` Crop or Pest.
  final String? cropOrPest;

  /// Row 22 (0-based) — `016EBS` Sample Size (verbatim string).
  final String? sampleSize;

  /// Row 25 (0-based) — `019EUU` collection basis unit.
  final String? collectionBasisUnit;

  /// Row 26 (0-based) — `020ERS` Reporting basis.
  final String? reportingBasis;

  /// Row 27 (0-based) — `021ERN` Reporting basis unit.
  final String? reportingBasisUnit;

  /// Row 28 (0-based) — `022ECN` Stage scale (e.g. BBCH).
  final String? stageScale;

  /// Row 30 (0-based) — `024ECL` Crop stage min.
  final String? cropStageMin;

  /// Row 31 (0-based) — `025ECX` Crop stage max.
  final String? cropStageMax;

  /// Row 32 (0-based) — `026ECD` Crop density.
  final String? cropDensity;

  /// Row 33 (0-based) — `027ECU` Crop density unit.
  final String? cropDensityUnit;

  /// Row 34 (0-based) — `028EPS` Pest stage maj.
  final String? pestStageMaj;

  /// Row 35 (0-based) — `029EPL` Pest stage min.
  final String? pestStageMin;

  /// Row 36 (0-based) — `030EPX` Pest stage max.
  final String? pestStageMax;

  /// Row 37 (0-based) — `031EPD` Pest density.
  final String? pestDensity;

  /// Row 38 (0-based) — `032EPU` Pest density unit.
  final String? pestDensityUnit;

  /// Row 39 (0-based) — `033EAB` Assessed By (rater; shell cell).
  final String? assessedBy;

  /// Row 40 (0-based) — `034EQP` Equipment.
  final String? equipment;

  /// Row 44 (0-based) — `038EUT` Untreated rating type.
  final String? untreatedRatingType;

  /// Row 45 (0-based) — `039EDP` ARM Actions.
  final String? armActions;
}
