import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/start_or_continue_rating_usecase.dart';

/// Lightweight in-memory doubles for repositories, to keep this test
/// focused on the index selection logic rather than Drift wiring.

class _FakeSessionRepository implements SessionRepository {
  final List<Session> _sessions;
  final Map<int, List<Assessment>> _sessionAssessments;

  _FakeSessionRepository({
    required List<Session> sessions,
    required Map<int, List<Assessment>> sessionAssessments,
  })  : _sessions = sessions,
        _sessionAssessments = sessionAssessments;

  @override
  Future<Session?> getSessionById(int sessionId) async {
    return _sessions.where((s) => s.id == sessionId).firstOrNull;
  }

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async {
    return _sessionAssessments[sessionId] ?? const [];
  }

  // Unused methods for this use case in this test.
  @override
  Future<Session?> getOpenSession(int trialId) async =>
      _sessions.where((s) => s.trialId == trialId && s.endedAt == null).firstOrNull;

  @override
  Stream<Session?> watchOpenSession(int trialId) =>
      Stream.value(_sessions.where((s) => s.trialId == trialId && s.endedAt == null).firstOrNull);

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      _sessions.where((s) => s.trialId == trialId).toList();

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal, {int? createdByUserId}) async =>
      _sessions.where((s) => s.sessionDateLocal == dateLocal).toList();

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> closeSession(
    int sessionId, {
    String? raterName,
    int? closedByUserId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}
}

class _FakeTrialRepository implements TrialRepository {
  final List<Trial> _trials;

  _FakeTrialRepository(this._trials);

  @override
  Future<Trial?> getTrialById(int id) async {
    return _trials.where((t) => t.id == id).firstOrNull;
  }

  // Unused members for this test.
  @override
  Stream<List<Trial>> watchAllTrials() => const Stream.empty();

  @override
  Future<int> createTrial({
    required String name,
    String? crop,
    String? location,
    String? season,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> updateTrial(Trial trial) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> updateTrialStatus(int trialId, String status) async {
    throw UnimplementedError();
  }

  @override
  Future<TrialSummary> getTrialSummary(int trialId) async {
    throw UnimplementedError();
  }
}

class _FakePlotRepository implements PlotRepository {
  final List<Plot> _plots;

  _FakePlotRepository(this._plots);

  @override
  Future<List<Plot>> getPlotsForTrial(int trialId) async {
    return _plots.where((p) => p.trialId == trialId).toList();
  }

  // Unused for this test.
  @override
  Stream<List<Plot>> watchPlotsForTrial(int trialId) => const Stream.empty();

  @override
  Future<Plot?> getPlotByPk(int plotPk) async {
    throw UnimplementedError();
  }

  @override
  Future<Plot?> getPlotByPlotId(int trialId, String plotId) async {
    throw UnimplementedError();
  }

  @override
  Future<int> insertPlot({
    required int trialId,
    required String plotId,
    int? plotSortIndex,
    int? rep,
    int? treatmentId,
    String? row,
    String? column,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Plot>> getPlotsPage({
    required int trialId,
    required int offset,
    int limit = 50,
    int? repFilter,
    int? treatmentFilter,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> getRepsForTrial(int trialId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlotNotes(int plotPk, String? notes) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlotTreatment(
    int plotPk,
    int? treatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePlotsTreatmentsBulk(
    Map<int, int?> plotPkToTreatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeRatingRepository implements RatingRepository {
  final List<RatingRecord> _ratings;

  _FakeRatingRepository(this._ratings);

  @override
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) async {
    return _ratings.where((r) => r.sessionId == sessionId).toList();
  }

  // Unused members.
  @override
  Future<RatingRecord?> getCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RatingRecord> saveRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String resultStatus,
    double? numericValue,
    String? textValue,
    int? subUnitId,
    String? raterName,
    int? performedByUserId,
    required bool isSessionClosed,
    String? createdAppVersion,
    String? createdDeviceInfo,
    double? capturedLatitude,
    double? capturedLongitude,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoRating({
    required int currentRatingId,
    required int sessionId,
    String? raterName,
    int? performedByUserId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> voidRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    required bool isSessionClosed,
    String? raterName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Set<int>> getRatedPlotPks({
    required int sessionId,
    required int assessmentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<int> getRatedPlotCountForTrial(int trialId) async => 0;

  @override
  Future<RatingCorrection?> getLatestCorrectionForRating(int ratingId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<RatingCorrection>> getCorrectionsForRating(int ratingId) async {
    throw UnimplementedError();
  }

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
    throw UnimplementedError();
  }
}

void main() {
  group('StartOrContinueRatingUseCase — serpentine index selection', () {
    late StartOrContinueRatingUseCase useCase;
    late Session session;
    late Trial trial;
    late List<Plot> plots;
    late List<Assessment> assessments;

    setUp(() {
      trial = Trial(
        id: 1,
        name: 'Trial',
        crop: null,
        location: null,
        season: null,
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      session = Session(
        id: 10,
        trialId: trial.id,
        name: 'Session',
        startedAt: DateTime(2026, 1, 2),
        endedAt: null,
        sessionDateLocal: '2026-01-02',
        raterName: 'R',
        createdByUserId: null,
        status: 'open',
      );

      // Three plots in simple order, no grid to keep the test easy to follow.
      plots = [
        Plot(
          id: 101,
          trialId: trial.id,
          plotId: '1',
          plotSortIndex: 1,
          rep: 1,
          treatmentId: null,
          notes: null,
          row: null,
          column: null,
          fieldRow: null,
          fieldColumn: null,
          assignmentSource: null,
          assignmentUpdatedAt: null,
        ),
        Plot(
          id: 102,
          trialId: trial.id,
          plotId: '2',
          plotSortIndex: 2,
          rep: 1,
          treatmentId: null,
          notes: null,
          row: null,
          column: null,
          fieldRow: null,
          fieldColumn: null,
          assignmentSource: null,
          assignmentUpdatedAt: null,
        ),
        Plot(
          id: 103,
          trialId: trial.id,
          plotId: '3',
          plotSortIndex: 3,
          rep: 1,
          treatmentId: null,
          notes: null,
          row: null,
          column: null,
          fieldRow: null,
          fieldColumn: null,
          assignmentSource: null,
          assignmentUpdatedAt: null,
        ),
      ];

      assessments = [
        Assessment(
          id: 201,
          trialId: trial.id,
          name: 'Score',
          unit: null,
          dataType: 'numeric',
          minValue: 0,
          maxValue: 100,
          isActive: true,
        ),
      ];

      final fakeSessionRepo = _FakeSessionRepository(
        sessions: [session],
        sessionAssessments: {session.id: assessments},
      );
      final fakeTrialRepo = _FakeTrialRepository([trial]);
      final fakePlotRepo = _FakePlotRepository(plots);

      // Rating repository is injected per test with scenario-specific ratings.
      final emptyRatingsRepo = _FakeRatingRepository(const []);

      useCase = StartOrContinueRatingUseCase(
        fakeSessionRepo,
        fakeTrialRepo,
        fakePlotRepo,
        emptyRatingsRepo,
      );
    });

    test('nothing rated → starts at index 0', () async {
      final result = await useCase
          .execute(StartOrContinueRatingInput(sessionId: session.id));

      expect(result.success, true);
      expect(result.startPlotIndex, 0);
      expect(result.isSessionComplete, false);
      expect(result.allPlotsSerpentine?.length, plots.length);
    });

    test('some rated → first unrated after last rated in order', () async {
      final ratingsRepo = _FakeRatingRepository([
        RatingRecord(
          id: 1,
          trialId: trial.id,
          plotPk: plots[0].id,
          assessmentId: assessments[0].id,
          sessionId: session.id,
          resultStatus: 'RECORDED',
          numericValue: 10,
          textValue: null,
          isCurrent: true,
          previousId: null,
          raterName: 'R',
          createdAppVersion: null,
          createdDeviceInfo: null,
          capturedLatitude: null,
          capturedLongitude: null,
          createdAt: DateTime(2026, 1, 3),
        ),
      ]);

      useCase = StartOrContinueRatingUseCase(
        _FakeSessionRepository(
          sessions: [session],
          sessionAssessments: {session.id: assessments},
        ),
        _FakeTrialRepository([trial]),
        _FakePlotRepository(plots),
        ratingsRepo,
      );

      final result = await useCase
          .execute(StartOrContinueRatingInput(sessionId: session.id));

      expect(result.success, true);
      // Next after plot[0] is plot[1] at index 1.
      expect(result.startPlotIndex, 1);
      expect(result.isSessionComplete, false);
    });

    test('all rated → marks session complete and points at last index', () async {
      final ratingsRepo = _FakeRatingRepository([
        RatingRecord(
          id: 1,
          trialId: trial.id,
          plotPk: plots[0].id,
          assessmentId: assessments[0].id,
          sessionId: session.id,
          resultStatus: 'RECORDED',
          numericValue: 10,
          textValue: null,
          isCurrent: true,
          previousId: null,
          raterName: 'R',
          createdAppVersion: null,
          createdDeviceInfo: null,
          capturedLatitude: null,
          capturedLongitude: null,
          createdAt: DateTime(2026, 1, 3),
        ),
        RatingRecord(
          id: 2,
          trialId: trial.id,
          plotPk: plots[1].id,
          assessmentId: assessments[0].id,
          sessionId: session.id,
          resultStatus: 'RECORDED',
          numericValue: 20,
          textValue: null,
          isCurrent: true,
          previousId: null,
          raterName: 'R',
          createdAppVersion: null,
          createdDeviceInfo: null,
          capturedLatitude: null,
          capturedLongitude: null,
          createdAt: DateTime(2026, 1, 3),
        ),
        RatingRecord(
          id: 3,
          trialId: trial.id,
          plotPk: plots[2].id,
          assessmentId: assessments[0].id,
          sessionId: session.id,
          resultStatus: 'RECORDED',
          numericValue: 30,
          textValue: null,
          isCurrent: true,
          previousId: null,
          raterName: 'R',
          createdAppVersion: null,
          createdDeviceInfo: null,
          capturedLatitude: null,
          capturedLongitude: null,
          createdAt: DateTime(2026, 1, 3),
        ),
      ]);

      useCase = StartOrContinueRatingUseCase(
        _FakeSessionRepository(
          sessions: [session],
          sessionAssessments: {session.id: assessments},
        ),
        _FakeTrialRepository([trial]),
        _FakePlotRepository(plots),
        ratingsRepo,
      );

      final result = await useCase
          .execute(StartOrContinueRatingInput(sessionId: session.id));

      expect(result.success, true);
      expect(result.isSessionComplete, true);
      expect(result.startPlotIndex, plots.length - 1);
    });
  });
}

