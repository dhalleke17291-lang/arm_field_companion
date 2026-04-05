import '../rating_repository.dart';
import '../../../domain/ratings/rating_integrity_exception.dart';
import '../../../domain/ratings/rating_integrity_guard.dart';

class VoidRatingUseCase {
  final RatingRepository _ratingRepository;
  final RatingReferentialIntegrity _referentialIntegrity;

  VoidRatingUseCase(this._ratingRepository, this._referentialIntegrity);

  Future<VoidRatingResult> execute({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    bool isSessionClosed = false,
    String? raterName,
    int? performedByUserId,
  }) async {
    try {
      if (isSessionClosed) {
        return VoidRatingResult.failure(
            'This session is closed. Data is read-only. Use correction workflow if changes are required.');
      }
      // Reason must not be empty — explicit confirmation required per spec
      if (reason.trim().isEmpty) {
        return VoidRatingResult.failure('Void reason must not be empty');
      }

      await _referentialIntegrity.assertPlotBelongsToTrial(
        plotPk: plotPk,
        trialId: trialId,
      );
      await _referentialIntegrity.assertSessionBelongsToTrial(
        sessionId: sessionId,
        trialId: trialId,
      );

      await _ratingRepository.voidRating(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        reason: reason,
        isSessionClosed: isSessionClosed,
        raterName: raterName,
        performedByUserId: performedByUserId,
      );

      return VoidRatingResult.success();
    } on RatingIntegrityException catch (e) {
      return VoidRatingResult.failure(e.toString());
    } catch (e) {
      return VoidRatingResult.failure('Void failed: $e');
    }
  }
}

class VoidRatingResult {
  final bool success;
  final String? errorMessage;

  const VoidRatingResult._({required this.success, this.errorMessage});

  factory VoidRatingResult.success() => const VoidRatingResult._(success: true);

  factory VoidRatingResult.failure(String message) =>
      VoidRatingResult._(success: false, errorMessage: message);
}
