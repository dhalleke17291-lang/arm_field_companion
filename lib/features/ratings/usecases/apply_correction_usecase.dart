import '../rating_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';
import '../../../domain/ratings/assessment_scale_resolver.dart';
import '../../../domain/ratings/rating_integrity_exception.dart';
import '../../../domain/ratings/rating_integrity_guard.dart';
import '../../../domain/ratings/result_status.dart';
import '../../../domain/ratings/rating_value_validator.dart';
import '../../../domain/ratings/save_rating_input.dart';

/// For [ResultStatus.requiresReason], use non-empty [newTextValue] when present;
/// otherwise fall back to [reasonTrimmed] so validation matches GLP-style
/// correction entry (dialog may only fill the correction reason field).
String? _resolveObservationTextForCorrection(
  String newResultStatus,
  String? newTextValue,
  String reasonTrimmed,
) {
  final st = resultStatusFromDb(newResultStatus);
  if (st != null && st.requiresReason) {
    final fromField = newTextValue?.trim() ?? '';
    if (fromField.isNotEmpty) return newTextValue;
    if (reasonTrimmed.isNotEmpty) return reasonTrimmed;
  }
  return newTextValue;
}

/// Apply an immutable correction to a rating (closed sessions only).
/// Original rating record is never modified.
class ApplyCorrectionUseCase {
  final RatingRepository _ratingRepository;
  final RatingReferentialIntegrity _referentialIntegrity;

  ApplyCorrectionUseCase(this._ratingRepository, this._referentialIntegrity);

  Future<ApplyCorrectionResult> execute({
    required RatingRecord rating,
    required Session session,
    required String newResultStatus,
    required String reason,
    double? newNumericValue,
    String? newTextValue,
    int? correctedByUserId,
    Assessment? assessmentForScale,
    AssessmentDefinitionScale? definitionScale,
  }) async {
    if (isSessionEditable(session)) {
      return ApplyCorrectionResult.failure(
          'Corrections are only allowed for closed sessions.');
    }
    final reasonTrimmed = reason.trim();
    if (reasonTrimmed.isEmpty) {
      return ApplyCorrectionResult.failure('Correction reason is required.');
    }

    ({double min, double max})? numericBounds;
    if (assessmentForScale != null) {
      numericBounds = resolvedNumericBoundsForAssessment(
        assessmentForScale,
        definitionScale,
      );
    }

    double? effectiveNumeric = newNumericValue;
    if (newResultStatus == 'RECORDED' &&
        assessmentForScale != null &&
        assessmentForScale.dataType == 'numeric') {
      if (effectiveNumeric == null) {
        return ApplyCorrectionResult.failure(
            'A numeric value is required for RECORDED.');
      }
      final b = numericBounds!;
      effectiveNumeric = effectiveNumeric.clamp(b.min, b.max);
    }

    final resolvedText = _resolveObservationTextForCorrection(
      newResultStatus,
      newTextValue,
      reasonTrimmed,
    );

    RatingAssessmentConstraints? assessmentConstraints;
    double? minValue;
    double? maxValue;
    if (assessmentForScale != null) {
      final b = numericBounds!;
      minValue = b.min;
      maxValue = b.max;
      assessmentConstraints = RatingAssessmentConstraints(
        dataType: assessmentForScale.dataType,
        minValue: b.min,
        maxValue: b.max,
        unit: assessmentForScale.unit,
      );
    }

    final validationInput = SaveRatingInput(
      trialId: rating.trialId,
      plotPk: rating.plotPk,
      assessmentId: rating.assessmentId,
      sessionId: rating.sessionId,
      resultStatus: newResultStatus,
      numericValue: effectiveNumeric,
      textValue: resolvedText,
      isSessionClosed: false,
      minValue: minValue,
      maxValue: maxValue,
      assessmentConstraints: assessmentConstraints,
    );
    final validation = RatingValueValidator.validate(validationInput);
    if (!validation.isValid) {
      return ApplyCorrectionResult.failure(validation.combinedMessage);
    }

    try {
      await _referentialIntegrity.assertPlotBelongsToTrial(
        plotPk: rating.plotPk,
        trialId: rating.trialId,
      );
      await _referentialIntegrity.assertSessionBelongsToTrial(
        sessionId: rating.sessionId,
        trialId: rating.trialId,
      );
      await _referentialIntegrity.assertAssessmentInSession(
        assessmentId: rating.assessmentId,
        sessionId: rating.sessionId,
      );

      final correction = await _ratingRepository.applyCorrection(
        ratingId: rating.id,
        oldResultStatus: rating.resultStatus,
        newResultStatus: newResultStatus,
        oldNumericValue: rating.numericValue,
        newNumericValue: effectiveNumeric,
        oldTextValue: rating.textValue,
        newTextValue: resolvedText,
        reason: reasonTrimmed,
        correctedByUserId: correctedByUserId,
        sessionId: rating.sessionId,
        plotPk: rating.plotPk,
      );
      return ApplyCorrectionResult.success(correction);
    } on RatingIntegrityException catch (e) {
      return ApplyCorrectionResult.failure(e.toString());
    } catch (e) {
      return ApplyCorrectionResult.failure('Correction failed: $e');
    }
  }
}

class ApplyCorrectionResult {
  final bool success;
  final RatingCorrection? correction;
  final String? errorMessage;

  const ApplyCorrectionResult._({
    required this.success,
    this.correction,
    this.errorMessage,
  });

  factory ApplyCorrectionResult.success(RatingCorrection c) =>
      ApplyCorrectionResult._(success: true, correction: c);

  factory ApplyCorrectionResult.failure(String message) =>
      ApplyCorrectionResult._(success: false, errorMessage: message);
}
