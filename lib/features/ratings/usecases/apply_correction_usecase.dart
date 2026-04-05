import '../rating_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';
import '../../../domain/ratings/assessment_scale_resolver.dart';

/// Apply an immutable correction to a rating (closed sessions only).
/// Original rating record is never modified.
class ApplyCorrectionUseCase {
  final RatingRepository _ratingRepository;

  ApplyCorrectionUseCase(this._ratingRepository);

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
    if (reason.trim().isEmpty) {
      return ApplyCorrectionResult.failure('Correction reason is required.');
    }

    double? effectiveNumeric = newNumericValue;
    if (newResultStatus == 'RECORDED' &&
        assessmentForScale != null &&
        assessmentForScale.dataType == 'numeric') {
      if (effectiveNumeric == null) {
        return ApplyCorrectionResult.failure(
            'A numeric value is required for RECORDED.');
      }
      final bounds = resolvedNumericBoundsForAssessment(
        assessmentForScale,
        definitionScale,
      );
      effectiveNumeric = effectiveNumeric.clamp(bounds.min, bounds.max);
    }

    try {
      final correction = await _ratingRepository.applyCorrection(
        ratingId: rating.id,
        oldResultStatus: rating.resultStatus,
        newResultStatus: newResultStatus,
        oldNumericValue: rating.numericValue,
        newNumericValue: effectiveNumeric,
        oldTextValue: rating.textValue,
        newTextValue: newTextValue,
        reason: reason.trim(),
        correctedByUserId: correctedByUserId,
        sessionId: rating.sessionId,
        plotPk: rating.plotPk,
      );
      return ApplyCorrectionResult.success(correction);
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
