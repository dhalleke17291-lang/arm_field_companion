import 'dart:async';
import 'dart:io' show Platform;

import '../../../core/app_info.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';
import '../../../domain/ratings/rating_integrity_exception.dart';
import '../../../domain/ratings/rating_integrity_guard.dart';
import '../../../domain/ratings/rating_value_validator.dart';
import '../../../domain/ratings/save_rating_input.dart';
import '../rating_repository.dart';

export '../../../domain/ratings/save_rating_input.dart';

/// SaveRatingUseCase — centerpiece of Agnexis
///
/// Enforces all spec invariants:
/// 1. [RatingValueValidator] — result status vs value columns + assessment rules
/// 2. Version chain — immutable records, new record per change
/// 3. Debounce protection — prevents duplicate writes from double-taps
/// 4. Audit trail written on every save

class SaveRatingUseCase {
  final RatingRepository _ratingRepository;
  final RatingReferentialIntegrity _referentialIntegrity;

  // Debounce protection — spec section 21
  bool _isProcessing = false;

  SaveRatingUseCase(this._ratingRepository, this._referentialIntegrity);

  Future<SaveRatingResult> execute(SaveRatingInput input) async {
    // Debounce guard — prevents double-tap duplicate writes
    if (_isProcessing) {
      return SaveRatingResult.debounced();
    }

    _isProcessing = true;

    try {
      // Session lock: no normal edits when session is closed
      if (input.isSessionClosed) {
        return SaveRatingResult.failure(kClosedSessionBlockedMessage);
      }

      final validation = RatingValueValidator.validate(input);
      if (!validation.isValid) {
        return SaveRatingResult.failure(validation.combinedMessage);
      }

      await _referentialIntegrity.assertPlotBelongsToTrial(
        plotPk: input.plotPk,
        trialId: input.trialId,
      );
      await _referentialIntegrity.assertSessionBelongsToTrial(
        sessionId: input.sessionId,
        trialId: input.trialId,
      );
      await _referentialIntegrity.assertAssessmentInSession(
        assessmentId: input.assessmentId,
        sessionId: input.sessionId,
      );

      const createdAppVersion = kAppVersion;
      final createdDeviceInfo = Platform.operatingSystem;

      final rating = await _ratingRepository.saveRating(
        trialId: input.trialId,
        plotPk: input.plotPk,
        assessmentId: input.assessmentId,
        sessionId: input.sessionId,
        resultStatus: input.resultStatus,
        numericValue: input.numericValue,
        textValue: input.textValue,
        subUnitId: input.subUnitId,
        raterName: input.raterName,
        performedByUserId: input.performedByUserId,
        isSessionClosed: input.isSessionClosed,
        createdAppVersion: createdAppVersion,
        createdDeviceInfo: createdDeviceInfo,
        ratingTime: input.ratingTime,
        ratingMethod: input.ratingMethod,
        confidence: input.confidence,
      );

      return SaveRatingResult.success(rating);
    } on SessionClosedException {
      return SaveRatingResult.failure(kClosedSessionBlockedMessage);
    } on RatingIntegrityException catch (e) {
      return SaveRatingResult.failure(e.toString());
    } catch (e) {
      return SaveRatingResult.failure('Unexpected error: $e');
    } finally {
      // Always release lock
      _isProcessing = false;
    }
  }
}

// ─────────────────────────────────────────────
// RESULT
// ─────────────────────────────────────────────

enum SaveRatingStatus { success, failure, debounced }

class SaveRatingResult {
  final SaveRatingStatus status;
  final RatingRecord? rating;
  final String? errorMessage;

  const SaveRatingResult._({
    required this.status,
    this.rating,
    this.errorMessage,
  });

  factory SaveRatingResult.success(RatingRecord rating) {
    return SaveRatingResult._(
      status: SaveRatingStatus.success,
      rating: rating,
    );
  }

  factory SaveRatingResult.failure(String message) {
    return SaveRatingResult._(
      status: SaveRatingStatus.failure,
      errorMessage: message,
    );
  }

  factory SaveRatingResult.debounced() {
    return const SaveRatingResult._(status: SaveRatingStatus.debounced);
  }

  bool get isSuccess => status == SaveRatingStatus.success;
  bool get isFailure => status == SaveRatingStatus.failure;
  bool get isDebounced => status == SaveRatingStatus.debounced;
}
