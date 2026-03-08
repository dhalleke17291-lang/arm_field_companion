import '../rating_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';

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
  }) async {
    if (isSessionEditable(session)) {
      return ApplyCorrectionResult.failure(
          'Corrections are only allowed for closed sessions.');
    }
    if (reason.trim().isEmpty) {
      return ApplyCorrectionResult.failure('Correction reason is required.');
    }

    try {
      final correction = await _ratingRepository.applyCorrection(
        ratingId: rating.id,
        oldResultStatus: rating.resultStatus,
        newResultStatus: newResultStatus,
        oldNumericValue: rating.numericValue,
        newNumericValue: newNumericValue,
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
