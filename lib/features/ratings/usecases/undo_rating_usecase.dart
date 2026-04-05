import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';
import '../../../domain/ratings/rating_integrity_exception.dart';
import '../../../domain/ratings/rating_integrity_guard.dart';
import '../rating_repository.dart';

class UndoRatingUseCase {
  final RatingRepository _ratingRepository;
  final RatingReferentialIntegrity _referentialIntegrity;

  UndoRatingUseCase(this._ratingRepository, this._referentialIntegrity);

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
      final ratings =
          await _ratingRepository.getCurrentRatingsForSession(sessionId);

      RatingRecord? current;
      for (final r in ratings) {
        if (r.id == currentRatingId) {
          current = r;
          break;
        }
      }
      if (current == null) {
        return UndoRatingResult.failure(
            'Rating does not belong to current session');
      }

      await _referentialIntegrity.assertSessionBelongsToTrial(
        sessionId: sessionId,
        trialId: current.trialId,
      );

      await _ratingRepository.undoRating(
        currentRatingId: currentRatingId,
        sessionId: sessionId,
        raterName: raterName,
        performedByUserId: performedByUserId,
      );

      return UndoRatingResult.success();
    } on SessionClosedException {
      return UndoRatingResult.failure(kClosedSessionBlockedMessage);
    } on RatingIntegrityException catch (e) {
      return UndoRatingResult.failure(e.toString());
    } catch (e) {
      return UndoRatingResult.failure('Undo failed: $e');
    }
  }
}

class UndoRatingResult {
  final bool success;
  final String? errorMessage;

  const UndoRatingResult._({required this.success, this.errorMessage});

  factory UndoRatingResult.success() => const UndoRatingResult._(success: true);

  factory UndoRatingResult.failure(String message) =>
      UndoRatingResult._(success: false, errorMessage: message);
}
