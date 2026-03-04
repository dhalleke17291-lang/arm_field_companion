import '../rating_repository.dart';

class VoidRatingUseCase {
  final RatingRepository _ratingRepository;

  VoidRatingUseCase(this._ratingRepository);

  Future<VoidRatingResult> execute({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    String? raterName,
  }) async {
    try {
      // Reason must not be empty — explicit confirmation required per spec
      if (reason.trim().isEmpty) {
        return VoidRatingResult.failure('Void reason must not be empty');
      }

      await _ratingRepository.voidRating(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        reason: reason,
        raterName: raterName,
      );

      return VoidRatingResult.success();
    } catch (e) {
      return VoidRatingResult.failure('Void failed: $e');
    }
  }
}

class VoidRatingResult {
  final bool success;
  final String? errorMessage;

  const VoidRatingResult._({required this.success, this.errorMessage});

  factory VoidRatingResult.success() =>
      const VoidRatingResult._(success: true);

  factory VoidRatingResult.failure(String message) =>
      VoidRatingResult._(success: false, errorMessage: message);
}
