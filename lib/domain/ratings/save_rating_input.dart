/// Resolved assessment metadata for validation (no DB I/O).
class RatingAssessmentConstraints {
  const RatingAssessmentConstraints({
    this.dataType,
    this.minValue,
    this.maxValue,
    this.required,
    this.unit,
  });

  final String? dataType;
  final double? minValue;
  final double? maxValue;
  final bool? required;
  final String? unit;

  static const RatingAssessmentConstraints empty =
      RatingAssessmentConstraints();
}

/// Input for saving a new rating row (version chain). Immutable payload from UI or import.
class SaveRatingInput {
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;
  final String resultStatus;
  final double? numericValue;
  final String? textValue;
  final int? subUnitId;
  final String? raterName;
  final int? performedByUserId;
  final bool isSessionClosed;
  final double? minValue;
  final double? maxValue;
  final String? ratingTime;
  final String? ratingMethod;
  final String? confidence;
  final double? capturedLatitude;
  final double? capturedLongitude;

  /// When saving a new version over an existing current rating, documents why
  /// the value or status changed (GLP-required in UI; ignored on first save).
  final String? amendmentReason;

  /// Optional resolved assessment metadata for validation (min/max, data type, unit).
  /// When null, validation stays conservative (status/null + ids only, plus min/max from [minValue]/[maxValue]).
  final RatingAssessmentConstraints? assessmentConstraints;

  /// ARM TrialAssessment.id for this rating. When provided, persisted on the
  /// rating row so causal-context signals can resolve ARM metadata without a
  /// separate join. Null for standalone (non-ARM) assessments.
  final int? trialAssessmentId;

  const SaveRatingInput({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    required this.resultStatus,
    this.numericValue,
    this.textValue,
    this.subUnitId,
    this.raterName,
    this.performedByUserId,
    this.isSessionClosed = false,
    this.minValue,
    this.maxValue,
    this.ratingTime,
    this.ratingMethod,
    this.confidence,
    this.capturedLatitude,
    this.capturedLongitude,
    this.amendmentReason,
    this.assessmentConstraints,
    this.trialAssessmentId,
  });
}
