/// Canonical rating observation outcome (maps to [rating_records.result_status] strings).
enum ResultStatus {
  recorded,
  notObserved,
  notApplicable,
  missingCondition,
  technicalIssue,
  voided,
}

/// DB string constants — explicit mapping for persistence.
abstract final class ResultStatusDb {
  static const String recorded = 'RECORDED';
  static const String notObserved = 'NOT_OBSERVED';
  static const String notApplicable = 'NOT_APPLICABLE';
  static const String missingCondition = 'MISSING_CONDITION';
  static const String technicalIssue = 'TECHNICAL_ISSUE';
  static const String voided = 'VOID';
}

/// Bidirectional DB string mapping for [ResultStatus].
extension ResultStatusDbMapping on ResultStatus {
  /// Value stored in [rating_records.result_status].
  String get dbString => switch (this) {
        ResultStatus.recorded => ResultStatusDb.recorded,
        ResultStatus.notObserved => ResultStatusDb.notObserved,
        ResultStatus.notApplicable => ResultStatusDb.notApplicable,
        ResultStatus.missingCondition => ResultStatusDb.missingCondition,
        ResultStatus.technicalIssue => ResultStatusDb.technicalIssue,
        ResultStatus.voided => ResultStatusDb.voided,
      };

  /// Guidance: recorded observations use the numeric column for measured values;
  /// non-recorded statuses must not carry a numeric value in that column.
  bool get expectsNumericValue => this == ResultStatus.recorded;

  /// Conservative: text may accompany recorded, missing, and technical-issue rows.
  bool get allowsTextValue =>
      this == ResultStatus.recorded ||
      this == ResultStatus.missingCondition ||
      this == ResultStatus.technicalIssue;

  /// Only where the save path already persists reasons via [textValue] (rating screen).
  bool get requiresReason =>
      this == ResultStatus.missingCondition ||
      this == ResultStatus.technicalIssue;

  /// Protocol rule: numeric column must be null unless status is [recorded].
  bool get mustClearNumericValue => this != ResultStatus.recorded;
}

/// Parse persisted [rating_records.result_status]. Returns null if unknown / legacy.
ResultStatus? resultStatusFromDb(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case ResultStatusDb.recorded:
      return ResultStatus.recorded;
    case ResultStatusDb.notObserved:
      return ResultStatus.notObserved;
    case ResultStatusDb.notApplicable:
      return ResultStatus.notApplicable;
    case ResultStatusDb.missingCondition:
      return ResultStatus.missingCondition;
    case ResultStatusDb.technicalIssue:
      return ResultStatus.technicalIssue;
    case ResultStatusDb.voided:
      return ResultStatus.voided;
    default:
      return null;
  }
}

bool isNumericAssessmentDataType(String? dataType) {
  if (dataType == null || dataType.isEmpty) return false;
  final d = dataType.toLowerCase().trim();
  return d == 'numeric' ||
      d == 'number' ||
      d == 'integer' ||
      d == 'decimal' ||
      d == 'int' ||
      d == 'float';
}

bool isTextAssessmentDataType(String? dataType) {
  if (dataType == null || dataType.isEmpty) return false;
  final d = dataType.toLowerCase().trim();
  return d == 'text' || d == 'string' || d == 'categorical';
}

bool assessmentExpectsIntegerValues(String? dataType) {
  if (dataType == null || dataType.isEmpty) return false;
  final d = dataType.toLowerCase().trim();
  return d == 'integer' || d == 'int';
}
