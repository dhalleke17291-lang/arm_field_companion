import '../rating_repository.dart';

class UndoRatingUseCase {
  final RatingRepository _ratingRepository;

  UndoRatingUseCase(this._ratingRepository);

  Future<UndoRatingResult> execute({
    required int currentRatingId,
    required int sessionId,
    String? raterName,
  }) async {
    try {
      // Get current rating to verify it belongs to this session
      final ratings = await _ratingRepository
          .getCurrentRatingsForSession(sessionId);

      final belongs = ratings.any((r) => r.id == currentRatingId);
      if (!belongs) {
        return UndoRatingResult.failure(
            'Rating does not belong to current session');
      }

      await _ratingRepository.undoRating(
        currentRatingId: currentRatingId,
        raterName: raterName,
      );

      return UndoRatingResult.success();
    } catch (e) {
      return UndoRatingResult.failure('Undo failed: $e');
    }
  }
}

class UndoRatingResult {
  final bool success;
  final String? errorMessage;

  const UndoRatingResult._({required this.success, this.errorMessage});

  factory UndoRatingResult.success() =>
      const UndoRatingResult._(success: true);

  factory UndoRatingResult.failure(String message) =>
      UndoRatingResult._(success: false, errorMessage: message);
}
