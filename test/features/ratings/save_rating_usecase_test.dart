import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_exception.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_providers.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/timing_window_violation_writer.dart';
import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
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
    return _records.where((r) {
      final subOk = subUnitId == null
          ? r.subUnitId == null
          : r.subUnitId == subUnitId;
      return r.trialId == trialId &&
          r.plotPk == plotPk &&
          r.assessmentId == assessmentId &&
          r.sessionId == sessionId &&
          r.isCurrent &&
          !r.isDeleted &&
          subOk;
    }).firstOrNull;
  }

  @override
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
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
    int? trialAssessmentId,
  }) async {
    if (shouldThrow) {
      throw RatingIntegrityException(throwMessage ?? 'Mock error');
    }

    for (int i = 0; i < _records.length; i++) {
      final r = _records[i];
      final subOk =
          subUnitId == null ? r.subUnitId == null : r.subUnitId == subUnitId;
      if (r.trialId == trialId &&
          r.plotPk == plotPk &&
          r.assessmentId == assessmentId &&
          r.sessionId == sessionId &&
          subOk) {
        _records[i] = r.copyWith(isCurrent: false);
      }
    }

    final record = RatingRecord(
      id: _records.length + 1,
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      trialAssessmentId: trialAssessmentId,
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
    String? amendmentReason,
    String? amendedBy,
    String? confidence,
    int? lastEditedByUserId,
  }) async {
    final idx = _records.indexWhere((r) => r.id == ratingId);
    if (idx == -1) {
      throw RatingIntegrityException('Rating not found: $ratingId');
    }
    final hasAmendmentReason = amendmentReason != null;
    final hasAmendedBy = amendedBy != null;
    final hasConfidence = confidence != null;
    final hasEditor = lastEditedByUserId != null;
    if (!hasAmendmentReason &&
        !hasAmendedBy &&
        !hasConfidence &&
        !hasEditor) {
      throw RatingIntegrityException(
        'No metadata fields to update. Rating value/status changes must use saveRating.',
      );
    }
    final r = _records[idx];
    _records[idx] = r.copyWith(
      amendmentReason:
          hasAmendmentReason ? Value(amendmentReason) : const Value.absent(),
      amendedBy: hasAmendedBy ? Value(amendedBy) : const Value.absent(),
      confidence: hasConfidence ? Value(confidence) : const Value.absent(),
      lastEditedByUserId:
          hasEditor ? Value(lastEditedByUserId) : const Value.absent(),
      lastEditedAt: Value(DateTime.now().toUtc()),
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
  Future<Set<int>> getRatedPlotPksForSession(int sessionId) async {
    return _records
        .where((r) => r.sessionId == sessionId && r.isCurrent)
        .map((r) => r.plotPk)
        .toSet();
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
  Future<Map<int, int>> getRatedDataPlotCountsPerLegacyAssessment(
          int trialId) async =>
      {};

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
    String? sessionRaterName,
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

  @override
  Future<List<RatingRecord>> getRatingChainForPlotAssessmentSession({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) async {
    final list = _records
        .where((r) =>
            r.trialId == trialId &&
            r.plotPk == plotPk &&
            r.assessmentId == assessmentId &&
            r.sessionId == sessionId &&
            !r.isDeleted)
        .toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  @override
  Future<List<RatingCorrection>> getCorrectionsForRatingIds(
          List<int> ratingIds) async =>
      [];

  @override
  Future<List<DeviationFlag>> getVoidDeviationFlags({
    required int trialId,
    required int sessionId,
    required int plotPk,
  }) async =>
      [];

  @override
  Future<List<DiagnosticFinding>> repairCurrentFlagsForExport({
    int? trialId,
    int? sessionId,
  }) async => [];
}

class _NoOpRatingReferentialIntegrity implements RatingReferentialIntegrity {
  @override
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  }) async {}

  @override
  Future<void> assertSessionBelongsToTrial({
    required int sessionId,
    required int trialId,
  }) async {}

  @override
  Future<void> assertAssessmentInSession({
    required int assessmentId,
    required int sessionId,
  }) async {}
}

void main() {
  late SaveRatingUseCase useCase;
  late MockRatingRepository mockRepo;

  setUp(() {
    mockRepo = MockRatingRepository();
    useCase = SaveRatingUseCase(
      mockRepo,
      _NoOpRatingReferentialIntegrity(),
    );
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

  group('updateRating — metadata only (mock parity with RatingRepository)', () {
    test('throws when no metadata fields are provided', () async {
      final row = await mockRepo.saveRating(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 3.0,
        isSessionClosed: false,
      );
      expect(
        () => mockRepo.updateRating(ratingId: row.id),
        throwsA(isA<RatingIntegrityException>().having(
          (e) => e.toString(),
          'message',
          contains('saveRating'),
        )),
      );
    });

    test('plot-detail style: save new value then metadata update keeps new value',
        () async {
      final first = await mockRepo.saveRating(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 2.0,
        isSessionClosed: false,
      );
      final firstId = first.id;

      final saveResult = await useCase.execute(const SaveRatingInput(
        trialId: 1,
        plotPk: 1,
        assessmentId: 1,
        sessionId: 1,
        resultStatus: 'RECORDED',
        numericValue: 9.0,
      ));
      expect(saveResult.isSuccess, true);
      final newId = saveResult.rating!.id;

      await mockRepo.updateRating(
        ratingId: newId,
        amendmentReason: 'Corrected entry',
        lastEditedByUserId: 42,
      );

      final updated = await mockRepo.getRatingById(newId);
      expect(updated!.numericValue, 9.0);
      expect(updated.amendmentReason, 'Corrected entry');
      expect(updated.lastEditedByUserId, 42);
      expect(firstId, isNot(newId));
    });
  });

  group('SaveRatingUseCase — trialAssessmentId persistence (real DB)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<({int trialId, int sessionId, int plotPk, int taId})> seed() async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(name: 'TA persist test'),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-06-01',
            ),
          );
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(trialId: trialId, plotId: 'P1'),
          );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'TST',
              name: 'Test',
              category: 'pest',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
            ),
          );
      return (trialId: trialId, sessionId: sessionId, plotPk: plotPk, taId: taId);
    }

    test('persists trialAssessmentId on rating row when provided', () async {
      final s = await seed();
      const assessmentId = 1;

      final repo = RatingRepository(db);
      final uc = SaveRatingUseCase(repo, _NoOpRatingReferentialIntegrity());

      final result = await uc.execute(SaveRatingInput(
        trialId: s.trialId,
        plotPk: s.plotPk,
        assessmentId: assessmentId,
        sessionId: s.sessionId,
        resultStatus: 'RECORDED',
        numericValue: 5.0,
        trialAssessmentId: s.taId,
      ));

      expect(result.isSuccess, true);
      expect(result.rating!.trialAssessmentId, s.taId);

      // Confirm persisted to DB.
      final row = await (db.select(db.ratingRecords)
            ..where((r) => r.id.equals(result.rating!.id)))
          .getSingle();
      expect(row.trialAssessmentId, s.taId);
    });

    test('trialAssessmentId is null when not provided', () async {
      final s = await seed();
      const assessmentId = 1;

      final repo = RatingRepository(db);
      final uc = SaveRatingUseCase(repo, _NoOpRatingReferentialIntegrity());

      final result = await uc.execute(SaveRatingInput(
        trialId: s.trialId,
        plotPk: s.plotPk,
        assessmentId: assessmentId,
        sessionId: s.sessionId,
        resultStatus: 'NOT_OBSERVED',
      ));

      expect(result.isSuccess, true);
      expect(result.rating!.trialAssessmentId, isNull);
    });
  });

  group('SaveRatingUseCase + TimingWindowViolationWriter integration', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('out-of-window save followed by writer check raises timing signal',
        () async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(
              name: 'SaveTimingE2E',
              workspaceType: const Value('efficacy'),
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-06-10',
            ),
          );
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(trialId: trialId, plotId: 'P1'),
          );
      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A'),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
            ),
          );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'TST',
              name: 'Test',
              category: 'pest',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              ratingType: const Value('CONTRO'),
            ),
          );
      await db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion(
              trialId: Value(trialId),
              applicationDate: Value(DateTime.now().toUtc()),
              status: const Value('applied'),
            ),
          );

      final repo = RatingRepository(db);
      final useCase = SaveRatingUseCase(repo, _NoOpRatingReferentialIntegrity());

      final save = await useCase.execute(SaveRatingInput(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        resultStatus: 'RECORDED',
        numericValue: 12.0,
        trialAssessmentId: taId,
      ));
      expect(save.isSuccess, isTrue);

      final writer = TimingWindowViolationWriter(
        db,
        container.read(signalRepositoryProvider),
      );
      final signalId = await writer.checkAndRaise(
        ratingId: save.rating!.id,
        trialAssessmentId: taId,
      );

      expect(signalId, isNotNull);
      final signals = await db.select(db.signals).get();
      expect(signals, hasLength(1));
      expect(signals.single.signalType, SignalType.causalContextFlag.dbValue);
    });
  });
}
