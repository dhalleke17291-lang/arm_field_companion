import 'dart:async';
import 'dart:io' show Platform;
import '../rating_repository.dart';
import '../../../core/app_info.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session_lock.dart';

/// SaveRatingUseCase — centerpiece of Ag-Quest Field Companion
/// 
/// Enforces all spec invariants:
/// 1. numericValue must be NULL if resultStatus != RECORDED
/// 2. Version chain — immutable records, new record per change
/// 3. Debounce protection — prevents duplicate writes from double-taps
/// 4. Audit trail written on every save

class SaveRatingUseCase {
  final RatingRepository _ratingRepository;
  
  // Debounce protection — spec section 21
  bool _isProcessing = false;

  SaveRatingUseCase(this._ratingRepository);

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

      // Validate input before touching database
      final validationError = _validate(input);
      if (validationError != null) {
        return SaveRatingResult.failure(validationError);
      }

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

  String? _validate(SaveRatingInput input) {
    // Spec invariant: numeric_value must be NULL if status != RECORDED
    if (input.resultStatus != 'RECORDED' && input.numericValue != null) {
      return 'numericValue must be null when status is ${input.resultStatus}';
    }

    // Must belong to a valid session
    if (input.sessionId <= 0) {
      return 'Invalid session ID';
    }

    // Must belong to a valid trial
    if (input.trialId <= 0) {
      return 'Invalid trial ID';
    }

    // Must belong to a valid plot
    if (input.plotPk <= 0) {
      return 'Invalid plot PK';
    }

    // Numeric value range check if provided
    if (input.numericValue != null && input.minValue != null) {
      if (input.numericValue! < input.minValue!) {
        return 'Value ${input.numericValue} is below minimum ${input.minValue}';
      }
    }

    if (input.numericValue != null && input.maxValue != null) {
      if (input.numericValue! > input.maxValue!) {
        return 'Value ${input.numericValue} exceeds maximum ${input.maxValue}';
      }
    }

    return null;
  }
}

// ─────────────────────────────────────────────
// INPUT
// ─────────────────────────────────────────────

class SaveRatingInput {
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;
  final String resultStatus;
  final double? numericValue;
  final String? textValue;
  final int? subUnitId;
  final String? raterName;
  final int? performedByUserId;
  final bool isSessionClosed;
  final double? minValue;
  final double? maxValue;

  const SaveRatingInput({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    required this.resultStatus,
    this.numericValue,
    this.textValue,
    this.subUnitId,
    this.raterName,
    this.performedByUserId,
    this.isSessionClosed = false,
    this.minValue,
    this.maxValue,
  });
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
