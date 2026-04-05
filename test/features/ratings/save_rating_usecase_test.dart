import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';

class MockRatingRepository implements RatingRepository {
  final List<RatingRecord> _records = [];
  bool shouldThrow = false;
  String? throwMessage;

  @override
  Future<RatingRecord?> getCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) async {
    return _records.where((r) =>
        r.trialId == trialId &&
        r.plotPk == plotPk &&
        r.assessmentId == assessmentId &&
        r.sessionId == sessionId &&
        r.isCurrent).firstOrNull;
  }

  @override
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) => Stream.value(null);

  @override
  Future<RatingRecord> saveRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String resultStatus,
    required bool isSessionClosed,
    double? numericValue,
    String? textValue,
    int? subUnitId,
    String? raterName,
    int? performedByUserId,
    String? createdAppVersion,
    String? createdDeviceInfo,
    double? capturedLatitude,
    double? capturedLongitude,
    String? ratingTime,
    String? ratingMethod,
    String? confidence,
  }) async {
    if (shouldThrow) {
      throw RatingIntegrityException(throwMessage ?? 'Mock error');
    }

    for (int i = 0; i < _records.length; i++) {
      if (_records[i].trialId == trialId &&
          _records[i].plotPk == plotPk &&
          _records[i].assessmentId == assessmentId &&
          _records[i].sessionId == sessionId) {
        _records[i] = _records[i].copyWith(isCurrent: false);
      }
    }

    final record = RatingRecord(
      id: _records.length + 1,
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      subUnitId: subUnitId,
      resultStatus: resultStatus,
      numericValue: numericValue,
      textValue: textValue,
      isCurrent: true,
      previousId: null,
      createdAt: DateTime.now(),
      raterName: raterName,
      amended: false,
      isDeleted: false,
    );

    _records.add(record);
    return record;
  }

  @override
  Future<RatingRecord?> getRatingById(int id) async {
    return _records.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<RatingRecord> updateRating({
    required int ratingId,
    double? numericValue,
    String? textValue,
    String? resultStatus,
    String? amendmentReason,
    String? amendedBy,
    String? confidence,
    int? lastEditedByUserId,
  }) async {
    final idx = _records.indexWhere((r) => r.id == ratingId);
    if (idx == -1) throw RatingIntegrityException('Rating not found: $ratingId');
    final r = _records[idx];
    _records[idx] = r.copyWith(
      numericValue: Value(numericValue ?? r.numericValue),
      textValue: Value(textValue ?? r.textValue),
      resultStatus: resultStatus ?? r.resultStatus,
    );
    return _records[idx];
  }

  @override
  Future<void> undoRating({
    required int currentRatingId,
    required int sessionId,
    String? raterName,
    int? performedByUserId,
  }) async {}

  @override
  Future<void> voidRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    required bool isSessionClosed,
    String? raterName,
    int? performedByUserId,
  }) async {}

  @override
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) async {
    return _records.where((r) => r.sessionId == sessionId && r.isCurrent).toList();
  }

  @override
  Future<Set<int>> getRatedPlotPks({
    required int sessionId,
    required int assessmentId,
  }) async {
    return _records
        .where((r) => r.sessionId == sessionId &&
            r.assessmentId == assessmentId &&
            r.isCurrent)
        .map((r) => r.plotPk)
        .toSet();
  }

  @override
  Future<int> getRatedPlotCountForTrial(int trialId) async {
    return _records.where((r) => r.trialId == trialId && r.isCurrent).map((r) => r.plotPk).toSet().length;
  }

  @override
  Future<RatingCorrection?> getLatestCorrectionForRating(int ratingId) async => null;

  @override
  Future<List<RatingCorrection>> getCorrectionsForRating(int ratingId) async => [];

  @override
  Future<Set<int>> getSessionIdsWithCorrections(Iterable<int> sessionIds) async =>
      {};

  @override
  Future<Set<int>> getPlotPksWithCorrectionsForSession(int sessionId) async => {};

  @override
  Future<RatingCorrection> applyCorrection({
    required int ratingId,
    required String oldResultStatus,
    required String newResultStatus,
    double? oldNumericValue,
    double? newNumericValue,
    String? oldTextValue,
    String? newTextValue,
    required String reason,
    int? correctedByUserId,
    int? sessionId,
    int? plotPk,
  }) async {
    throw UnimplementedError('applyCorrection not used in save_rating_usecase_test');
  }

  @override
  Future<List<RatingRecord>> getRatingRecordsForSessionRecoveryExport(
      int sessionId) async {
    final list =
        _records.where((r) => r.sessionId == sessionId).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  @override
  Future<List<RatingRecord>> getRatingRecordsForTrialRecoveryExport(
      int trialId) async {
    final list = _records.where((r) => r.trialId == trialId).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }
}

void main() {
  late SaveRatingUseCase useCase;
  late MockRatingRepository mockRepo;

  setUp(() {
    mockRepo = MockRatingRepository();
    useCase = SaveRatingUseCase(mockRepo);
  });

  group('SaveRatingUseCase — Core Invariants', () {
    test('INVARIANT: numericValue must be null when status is NOT_OBSERVED', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'NOT_OBSERVED',
        numericValue: 5.0,
      ));

      expect(result.isFailure, true);
      expect(result.errorMessage, contains('numericValue must be null'));
    });

    test('INVARIANT: numericValue must be null when status is NOT_APPLICABLE', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'NOT_APPLICABLE',
        numericValue: 3.0,
      ));

      expect(result.isFailure, true);
      expect(result.errorMessage, contains('numericValue must be null'));
    });

    test('INVARIANT: numericValue must be null when status is MISSING_CONDITION', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'MISSING_CONDITION',
        numericValue: 1.0,
      ));

      expect(result.isFailure, true);
    });

    test('SUCCESS: RECORDED status with numeric value succeeds', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 7.5,
      ));

      expect(result.isSuccess, true);
      expect(result.rating?.numericValue, 7.5);
      expect(result.rating?.resultStatus, 'RECORDED');
    });

    test('SUCCESS: NOT_OBSERVED with null numeric value succeeds', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'NOT_OBSERVED',
        numericValue: null,
      ));

      expect(result.isSuccess, true);
      expect(result.rating?.numericValue, null);
    });

    test('INVARIANT: range check rejects value below minimum', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: -1.0,
        minValue: 0.0,
        maxValue: 100.0,
      ));

      expect(result.isFailure, true);
      expect(result.errorMessage, contains('below minimum'));
    });

    test('INVARIANT: range check rejects value above maximum', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 101.0,
        minValue: 0.0,
        maxValue: 100.0,
      ));

      expect(result.isFailure, true);
      expect(result.errorMessage, contains('exceeds maximum'));
    });

    test('INVARIANT: invalid session ID rejected', () async {
      final result = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 0,
        resultStatus: 'RECORDED',
        numericValue: 5.0,
      ));

      expect(result.isFailure, true);
      expect(result.errorMessage, contains('Invalid session ID'));
    });

    test('DEBOUNCE: second call while processing returns debounced', () async {
      final future1 = useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 5.0,
      ));

      final future2 = useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 6.0,
      ));

      final results = await Future.wait([future1, future2]);
      final statuses = results.map((r) => r.status).toList();

      expect(statuses.contains(SaveRatingStatus.success), true);
      expect(statuses.contains(SaveRatingStatus.debounced), true);
    });
  });
}
