import 'result_status.dart';
import 'save_rating_input.dart';

/// Machine-readable validation failure (Phase 1 structured errors).
enum RatingValidationErrorCode {
  unknownResultStatus,
  invalidSessionId,
  invalidTrialId,
  invalidPlotPk,
  missingNumericValue,
  unexpectedNumericValue,
  belowMinimum,
  aboveMaximum,
  unsupportedRecordedValueType,
  /// Recorded observation missing a value when assessment type requires one (e.g. text).
  missingRecordingValue,
  missingRequiredReason,
}

class RatingValidationError {
  const RatingValidationError(this.code, this.message);

  final RatingValidationErrorCode code;
  final String message;
}

/// Structured validation outcome (pure Dart).
class ValidationResult {
  const ValidationResult._(this.errors);

  final List<RatingValidationError> errors;

  bool get isValid => errors.isEmpty;

  String get combinedMessage =>
      errors.map((e) => e.message).join('; ');

  factory ValidationResult.success() => const ValidationResult._([]);

  factory ValidationResult.failure(List<RatingValidationError> errors) =>
      ValidationResult._(List<RatingValidationError>.unmodifiable(errors));
}

/// Pure validation for rating save payloads — no database access.
class RatingValueValidator {
  RatingValueValidator._();

  /// Merges [SaveRatingInput.assessmentConstraints] with top-level [minValue]/[maxValue].
  static RatingAssessmentConstraints mergeConstraints(SaveRatingInput input) {
    final ac = input.assessmentConstraints;
    if (ac == null) {
      return RatingAssessmentConstraints(
        dataType: null,
        minValue: input.minValue,
        maxValue: input.maxValue,
        required: null,
        unit: null,
      );
    }
    return RatingAssessmentConstraints(
      dataType: ac.dataType,
      minValue: ac.minValue ?? input.minValue,
      maxValue: ac.maxValue ?? input.maxValue,
      required: ac.required,
      unit: ac.unit,
    );
  }

  /// Validates [input] using merged [RatingAssessmentConstraints].
  static ValidationResult validate(SaveRatingInput input) {
    final errors = <RatingValidationError>[];

    final status = resultStatusFromDb(input.resultStatus);
    if (status == null) {
      errors.add(RatingValidationError(
        RatingValidationErrorCode.unknownResultStatus,
        'Unknown result status: ${input.resultStatus}',
      ));
      return ValidationResult.failure(errors);
    }

    if (input.sessionId <= 0) {
      errors.add(const RatingValidationError(
        RatingValidationErrorCode.invalidSessionId,
        'Invalid session ID',
      ));
    }
    if (input.trialId <= 0) {
      errors.add(const RatingValidationError(
        RatingValidationErrorCode.invalidTrialId,
        'Invalid trial ID',
      ));
    }
    if (input.plotPk <= 0) {
      errors.add(const RatingValidationError(
        RatingValidationErrorCode.invalidPlotPk,
        'Invalid plot PK',
      ));
    }

    final c = mergeConstraints(input);

    _validateStatusValuePair(status, input.numericValue, input.textValue, c, errors);

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }

    return ValidationResult.success();
  }

  static void _validateStatusValuePair(
    ResultStatus status,
    double? numericValue,
    String? textValue,
    RatingAssessmentConstraints c,
    List<RatingValidationError> errors,
  ) {
    final dataType = c.dataType;
    final textTrimmed = textValue?.trim() ?? '';

    if (status.mustClearNumericValue && numericValue != null) {
      errors.add(RatingValidationError(
        RatingValidationErrorCode.unexpectedNumericValue,
        'numericValue must be null when status is ${status.dbString}',
      ));
    }

    if (status == ResultStatus.recorded) {
      final numericDt = isNumericAssessmentDataType(dataType);
      final textDt = isTextAssessmentDataType(dataType);
      final ambiguousDt = dataType == null ||
          dataType.isEmpty ||
          (!numericDt && !textDt);

      if (numericDt) {
        if (numericValue == null) {
          errors.add(const RatingValidationError(
            RatingValidationErrorCode.missingNumericValue,
            'A numeric value is required for RECORDED on this assessment',
          ));
        }
      } else if (textDt) {
        if (textTrimmed.isEmpty) {
          errors.add(const RatingValidationError(
            RatingValidationErrorCode.missingRecordingValue,
            'A text value is required for RECORDED on this assessment',
          ));
        }
        if (numericValue != null) {
          errors.add(const RatingValidationError(
            RatingValidationErrorCode.unexpectedNumericValue,
            'numericValue must be null for text-based assessments',
          ));
        }
      } else if (ambiguousDt) {
        if (c.required == true &&
            numericValue == null &&
            textTrimmed.isEmpty) {
          errors.add(const RatingValidationError(
            RatingValidationErrorCode.missingRecordingValue,
            'A value is required for RECORDED on this assessment',
          ));
        }
      }

      if (numericValue != null && (numericDt || ambiguousDt)) {
        if (assessmentExpectsIntegerValues(dataType)) {
          final rounded = numericValue.roundToDouble();
          if ((numericValue - rounded).abs() > 1e-9) {
            errors.add(const RatingValidationError(
              RatingValidationErrorCode.unsupportedRecordedValueType,
              'Value must be a whole number for this assessment',
            ));
          }
        }
        final min = c.minValue;
        final max = c.maxValue;
        if (min != null && numericValue < min) {
          errors.add(RatingValidationError(
            RatingValidationErrorCode.belowMinimum,
            'Value $numericValue is below minimum $min',
          ));
        }
        if (max != null && numericValue > max) {
          errors.add(RatingValidationError(
            RatingValidationErrorCode.aboveMaximum,
            'Value $numericValue exceeds maximum $max',
          ));
        }
      }
    }

    if (status.requiresReason && textTrimmed.isEmpty) {
      errors.add(RatingValidationError(
        RatingValidationErrorCode.missingRequiredReason,
        'A reason is required for ${status.dbString}',
      ));
    }
  }
}
