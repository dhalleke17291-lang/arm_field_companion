import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/start_or_continue_rating_usecase.dart';

/// Shared fakes for StartOrContinueRating use case (unit + widget tests).

class FakeSessionRepository implements SessionRepository {
  final List<Session> sessions;
  final Map<int, List<Assessment>> sessionAssessments;

  FakeSessionRepository({
    this.sessions = const [],
    this.sessionAssessments = const {},
  });

  @override
  Future<Session?> getSessionById(int sessionId) async =>
      sessions.where((s) => s.id == sessionId).firstOrNull;

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async =>
      sessionAssessments[sessionId] ?? const [];

  @override
  Future<Session?> getOpenSession(int trialId) async =>
      sessions.where((s) => s.trialId == trialId && s.endedAt == null).firstOrNull;

  @override
  Stream<Session?> watchOpenSession(int trialId) =>
      Stream.value(sessions.where((s) => s.trialId == trialId && s.endedAt == null).firstOrNull);

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      sessions.where((s) => s.trialId == trialId).toList();

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> closeSession(
    int sessionId, {
    String? raterName,
    int? closedByUserId,
  }) async {}
}

class FakeTrialRepository implements TrialRepository {
  final List<Trial> trials;

  FakeTrialRepository(this.trials);

  @override
  Future<Trial?> getTrialById(int id) async =>
      trials.where((t) => t.id == id).firstOrNull;

  @override
  Stream<List<Trial>> watchAllTrials() => Stream.value(trials);

  @override
  Future<int> createTrial({
    required String name,
    String? crop,
    String? location,
    String? season,
  }) async =>
      throw UnimplementedError();

  @override
  Future<bool> updateTrial(Trial trial) async => throw UnimplementedError();

  @override
  Future<bool> updateTrialStatus(int trialId, String status) async =>
      throw UnimplementedError();

  @override
  Future<TrialSummary> getTrialSummary(int trialId) async =>
      throw UnimplementedError();
}

class FakePlotRepository implements PlotRepository {
  final List<Plot> plots;

  FakePlotRepository(this.plots);

  @override
  Future<List<Plot>> getPlotsForTrial(int trialId) async =>
      plots.where((p) => p.trialId == trialId).toList();

  @override
  Stream<List<Plot>> watchPlotsForTrial(int trialId) =>
      Stream.value(plots.where((p) => p.trialId == trialId).toList());

  @override
  Future<Plot?> getPlotByPk(int plotPk) async => throw UnimplementedError();

  @override
  Future<Plot?> getPlotByPlotId(int trialId, String plotId) async =>
      throw UnimplementedError();

  @override
  Future<int> insertPlot({
    required int trialId,
    required String plotId,
    int? plotSortIndex,
    int? rep,
    int? treatmentId,
    String? row,
    String? column,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async =>
      throw UnimplementedError();

  @override
  Future<List<Plot>> getPlotsPage({
    required int trialId,
    required int offset,
    int limit = 50,
    int? repFilter,
    int? treatmentFilter,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<int>> getRepsForTrial(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotNotes(int plotPk, String? notes) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotTreatment(
    int plotPk,
    int? treatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotsTreatmentsBulk(
    Map<int, int?> plotPkToTreatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async =>
      throw UnimplementedError();
}

class FakeRatingRepository implements RatingRepository {
  final List<RatingRecord> ratings;

  FakeRatingRepository([this.ratings = const []]);

  @override
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) async =>
      ratings.where((r) => r.sessionId == sessionId).toList();

  @override
  Future<RatingRecord?> getCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    int? subUnitId,
  }) async =>
      throw UnimplementedError();

  @override
  Stream<RatingRecord?> watchCurrentRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
  }) =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> undoRating({
    required int currentRatingId,
    required int sessionId,
    String? raterName,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> voidRating({
    required int trialId,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    required String reason,
    required bool isSessionClosed,
    String? raterName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Set<int>> getRatedPlotPks({
    required int sessionId,
    required int assessmentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<RatingCorrection?> getLatestCorrectionForRating(int ratingId) async =>
      throw UnimplementedError();

  @override
  Future<List<RatingCorrection>> getCorrectionsForRating(int ratingId) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();
}

/// Use case double that returns a configurable result for widget tests.
class FakeStartOrContinueRatingUseCase extends StartOrContinueRatingUseCase {
  FakeStartOrContinueRatingUseCase()
      : super(
          FakeSessionRepository(),
          FakeTrialRepository([]),
          FakePlotRepository([]),
          FakeRatingRepository(),
        );

  StartOrContinueRatingResult? result;

  @override
  Future<StartOrContinueRatingResult> execute(
      StartOrContinueRatingInput input) async {
    return result ?? StartOrContinueRatingResult.failure('fake not configured');
  }
}
