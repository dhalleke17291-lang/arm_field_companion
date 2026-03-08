import '../rating_repository.dart';
import '../../../core/session_lock.dart';

class UndoRatingUseCase {
  final RatingRepository _ratingRepository;

  UndoRatingUseCase(this._ratingRepository);

  Future<UndoRatingResult> execute({
    required int currentRatingId,
    required int sessionId,
    bool isSessionClosed = false,
    String? raterName,
    int? performedByUserId,
  }) async {
    try {
      if (isSessionClosed) {
        return UndoRatingResult.failure(kClosedSessionBlockedMessage);
      }

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
        sessionId: sessionId,
        raterName: raterName,
        performedByUserId: performedByUserId,
      );

      return UndoRatingResult.success();
    } on SessionClosedException {
      return UndoRatingResult.failure(kClosedSessionBlockedMessage);
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
