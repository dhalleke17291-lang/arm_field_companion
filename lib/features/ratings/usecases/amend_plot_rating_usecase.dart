import '../../../core/database/app_database.dart';
import '../../sessions/session_repository.dart';
import '../rating_repository.dart';
import 'save_rating_usecase.dart';
import '../../../domain/signals/signal_repository.dart';
import '../../../domain/signals/signal_writers/scale_violation_writer.dart';
import '../../../domain/signals/signal_writers/timing_window_violation_writer.dart';

/// Payload for amending a plot rating from the plot-detail edit sheet.
///
/// [resultStatus] and existing value fields must match the rating row being
/// amended (same semantics as the previous inline handler).
///
/// [minValue] / [maxValue] should match the resolved numeric bounds from the
/// screen (including definition scale when present).
///
/// [subUnitId], [existingNumericValue], and [existingTextValue] mirror the
/// current rating row when constructing the new version via [SaveRatingUseCase].
class AmendPlotRatingInput {
  const AmendPlotRatingInput({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    required this.rawValue,
    required this.dataType,
    required this.resultStatus,
    this.minValue,
    this.maxValue,
    this.assessmentConstraints,
    required this.amendmentReason,
    required this.amendedBy,
    this.performedByUserId,
    this.subUnitId,
    this.existingNumericValue,
    this.existingTextValue,
    this.seType,
    this.trialAssessmentId,
  });

  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;

  /// Text from the value field (trimmed by the use case where needed).
  final String rawValue;

  /// [Assessment.dataType] when known (e.g. `'numeric'`).
  final String? dataType;

  /// Existing rating's [RatingRecord.resultStatus].
  final String resultStatus;

  final double? minValue;
  final double? maxValue;
  final RatingAssessmentConstraints? assessmentConstraints;

  final String amendmentReason;
  final String amendedBy;
  final int? performedByUserId;

  final int? subUnitId;
  final double? existingNumericValue;
  final String? existingTextValue;

  /// ARM rating-type prefix for scale violation signals (e.g. 'CONTRO').
  /// Resolved by the caller from ARM metadata; defaults to 'LOCAL' when absent.
  final String? seType;

  /// ARM trialAssessmentId for timing window signals.
  /// Passed explicitly because the new rating row won't have it in the DB yet.
  final int? trialAssessmentId;
}

class AmendPlotRatingResult {
  const AmendPlotRatingResult._({
    required this.isSuccess,
    this.savedRatingId,
    this.errorMessage,
    this.isDebounced = false,
  });

  final bool isSuccess;
  final int? savedRatingId;
  final String? errorMessage;
  final bool isDebounced;

  factory AmendPlotRatingResult.success(int savedRatingId) {
    return AmendPlotRatingResult._(
      isSuccess: true,
      savedRatingId: savedRatingId,
    );
  }

  factory AmendPlotRatingResult.failure(
    String message, {
    bool debounced = false,
  }) {
    return AmendPlotRatingResult._(
      isSuccess: false,
      errorMessage: message,
      isDebounced: debounced,
    );
  }
}

/// Orchestrates session lookup, value resolution, [SaveRatingUseCase], and
/// amendment metadata on the new rating row.
class AmendPlotRatingUseCase {
  AmendPlotRatingUseCase(
    this._sessionRepository,
    this._saveRatingUseCase,
    this._ratingRepository,
    this._signalRepository,
    this._db,
  );

  final SessionRepository _sessionRepository;
  final SaveRatingUseCase _saveRatingUseCase;
  final RatingRepository _ratingRepository;
  final SignalRepository _signalRepository;
  final AppDatabase _db;

  Future<AmendPlotRatingResult> execute(AmendPlotRatingInput input) async {
    final session = await _sessionRepository.getSessionById(input.sessionId);
    if (session == null) {
      return AmendPlotRatingResult.failure('Session not found');
    }

    final rawTrimmed = input.rawValue.trim();

    double? numericValue = input.existingNumericValue;
    String? textValue = input.existingTextValue;

    if (input.resultStatus == 'RECORDED' && input.dataType == 'numeric') {
      final parsed = double.tryParse(rawTrimmed);
      if (parsed == null && rawTrimmed.isNotEmpty) {
        return AmendPlotRatingResult.failure('Enter a valid number');
      }
      final minB = input.minValue ?? 0.0;
      final maxB = input.maxValue ?? 999.0;
      if (parsed != null) {
        try {
          await ScaleViolationWriter(_signalRepository).checkAndRaise(
            trialId: input.trialId,
            sessionId: input.sessionId,
            plotId: input.plotPk,
            enteredValue: parsed,
            scaleMin: minB,
            scaleMax: maxB,
            seType: input.seType ?? 'LOCAL',
            consequenceText:
                'Numeric rating outside declared scale; value clamped before save.',
          );
        } catch (_) {
          // Signal write failure does not block the amendment.
        }
        numericValue = parsed.clamp(minB, maxB);
      } else {
        numericValue = input.existingNumericValue;
      }
      textValue = null;
    } else if (input.resultStatus == 'RECORDED') {
      numericValue = null;
      textValue = rawTrimmed.isNotEmpty ? rawTrimmed : input.existingTextValue;
    }

    final minB = input.minValue ?? 0.0;
    final maxB = input.maxValue ?? 999.0;

    final now = DateTime.now();
    final ratingTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final saveResult = await _saveRatingUseCase.execute(SaveRatingInput(
      trialId: input.trialId,
      plotPk: input.plotPk,
      assessmentId: input.assessmentId,
      sessionId: input.sessionId,
      resultStatus: input.resultStatus,
      numericValue: numericValue,
      textValue: textValue,
      subUnitId: input.subUnitId,
      raterName: session.raterName,
      performedByUserId: input.performedByUserId,
      isSessionClosed: session.endedAt != null,
      minValue: minB,
      maxValue: maxB,
      ratingTime: ratingTime,
      assessmentConstraints: input.assessmentConstraints,
    ));

    if (!saveResult.isSuccess) {
      if (saveResult.isDebounced) {
        return AmendPlotRatingResult.failure(
          'Please wait and try again',
          debounced: true,
        );
      }
      return AmendPlotRatingResult.failure(
        saveResult.errorMessage ?? 'Could not save rating',
      );
    }

    final saved = saveResult.rating!;

    try {
      await _ratingRepository.updateRating(
        ratingId: saved.id,
        amendmentReason: input.amendmentReason,
        amendedBy: input.amendedBy.isEmpty ? null : input.amendedBy,
        lastEditedByUserId: input.performedByUserId,
      );
    } catch (e) {
      return AmendPlotRatingResult.failure('Error: $e');
    }

    TimingWindowViolationWriter(_db, _signalRepository)
        .checkAndRaise(
          ratingId: saved.id,
          trialAssessmentId: input.trialAssessmentId,
        )
        .ignore();

    return AmendPlotRatingResult.success(saved.id);
  }
}
