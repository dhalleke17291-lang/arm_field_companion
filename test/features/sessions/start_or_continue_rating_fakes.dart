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

  /// When set, createSession returns this instead of throwing.
  final Session? sessionToReturnFromCreate;

  FakeSessionRepository({
    this.sessions = const [],
    this.sessionAssessments = const {},
    this.sessionToReturnFromCreate,
  });

  @override
  Future<Session?> getSessionById(int sessionId) async =>
      sessions.where((s) => s.id == sessionId).firstOrNull;

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async =>
      sessionAssessments[sessionId] ?? const [];

  @override
  Future<bool> isAssessmentInSession(int assessmentId, int sessionId) async {
    final list = sessionAssessments[sessionId] ?? const [];
    return list.any((a) => a.id == assessmentId);
  }

  @override
  Future<Session?> getOpenSession(int trialId) async => sessions
      .where((s) => s.trialId == trialId && s.endedAt == null)
      .firstOrNull;

  @override
  Stream<Session?> watchOpenSession(int trialId) => Stream.value(sessions
      .where((s) => s.trialId == trialId && s.endedAt == null)
      .firstOrNull);

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      sessions.where((s) => s.trialId == trialId).toList();

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal,
          {int? createdByUserId}) async =>
      sessions.where((s) => s.sessionDateLocal == dateLocal).toList();

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
  }) async {
    final s = sessionToReturnFromCreate;
    if (s != null) return s;
    throw UnimplementedError();
  }

  @override
  Future<void> closeSession(
    int sessionId, {
    String? raterName,
    int? closedByUserId,
  }) async {}

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}

  @override
  Future<void> softDeleteSession(int sessionId,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Session>> getDeletedSessionsForTrial(int trialId) async => [];

  @override
  Future<List<Session>> getAllDeletedSessions() async => [];

  @override
  Future<Session?> getDeletedSessionById(int id) async => null;

  @override
  Stream<bool> watchTrialHasSessionData(int trialId) =>
      Stream.value(sessions.any((s) => s.trialId == trialId));

  @override
  Future<SessionRestoreResult> restoreSession(int sessionId,
          {String? restoredBy, int? restoredByUserId}) async =>
      SessionRestoreResult.failure('Not implemented');

  @override
  Future<int?> resolveSessionIdForRatingShell(Trial trial) async {
    final list = sessions
        .where((s) => s.trialId == trial.id && !s.isDeleted)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (list.isEmpty) return null;
    if (trial.isArmLinked) {
      for (final s in list) {
        if (s.name.contains('ARM Import')) return s.id;
      }
      final anchor = trial.armImportedAt;
      if (anchor != null) {
        Session? best;
        var bestDelta = 9223372036854775807;
        for (final s in list) {
          final d = (s.startedAt.millisecondsSinceEpoch -
                  anchor.millisecondsSinceEpoch)
              .abs();
          if (d < bestDelta) {
            bestDelta = d;
            best = s;
          }
        }
        return best?.id;
      }
    }
    return list.first.id;
  }
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
    String workspaceType = 'efficacy',
  }) async =>
      throw UnimplementedError();

  @override
  Future<bool> updateTrial(Trial trial) async => throw UnimplementedError();

  @override
  Future<int> updateTrialSetup(int trialId, TrialsCompanion companion) async =>
      throw UnimplementedError();

  @override
  Future<bool> updateTrialStatus(int trialId, String status) async =>
      throw UnimplementedError();

  @override
  Future<TrialSummary> getTrialSummary(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<void> softDeleteTrial(int trialId,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Trial>> getDeletedTrials() async => [];

  @override
  Future<Trial?> getDeletedTrialById(int id) async => null;

  @override
  Future<TrialRestoreResult> restoreTrial(int trialId,
          {String? restoredBy, int? restoredByUserId}) async =>
      TrialRestoreResult.failure('Not implemented');
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
  Future<Set<int>> getFlaggedPlotPksForSession(int sessionId) async => {};

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
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
    bool isGuardRow = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async =>
      throw UnimplementedError();

  @override
  Future<int> countRepGuardPlotsToInsert(int trialId) async => 0;

  @override
  Future<int> insertRepGuardPlotsIfNeeded(int trialId) async => 0;

  @override
  Future<void> updatePlotGuardRow(int plotPk, bool isGuardRow) async {}

  @override
  Future<void> updatePlotNotes(int plotPk, String? notes) async {}

  @override
  Future<void> updatePlotDetails(
    int plotPk, {
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
  }) async {}

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

  @override
  Future<void> softDeletePlot(int plotPk,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Plot>> getDeletedPlotsForTrial(int trialId) async => [];

  @override
  Future<List<Plot>> getAllDeletedPlots() async => [];

  @override
  Future<Plot?> getDeletedPlotByPk(int plotPk) async => null;

  @override
  Future<PlotRestoreResult> restorePlot(int plotPk,
          {String? restoredBy, int? restoredByUserId}) async =>
      PlotRestoreResult.failure('Not implemented');
}

class FakeRatingRepository implements RatingRepository {
  final List<RatingRecord> ratings;

  FakeRatingRepository([this.ratings = const []]);

  @override
  Future<List<RatingRecord>> getCurrentRatingsForSession(int sessionId) async =>
      ratings.where((r) => r.sessionId == sessionId).toList();

  @override
  Future<Set<int>> getRatedPlotPksForSession(int sessionId) async => ratings
      .where((r) => r.sessionId == sessionId && r.isCurrent)
      .map((r) => r.plotPk)
      .toSet();

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
  Future<RatingRecord?> getRatingById(int id) async =>
      ratings.where((r) => r.id == id).firstOrNull;

  @override
  Future<RatingRecord> updateRating({
    required int ratingId,
    String? amendmentReason,
    String? amendedBy,
    String? confidence,
    int? lastEditedByUserId,
  }) async =>
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
    String? ratingTime,
    String? ratingMethod,
    String? confidence,
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
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Set<int>> getRatedPlotPks({
    required int sessionId,
    required int assessmentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> getRatedPlotCountForTrial(int trialId) async => 0;

  @override
  Future<RatingCorrection?> getLatestCorrectionForRating(int ratingId) async =>
      throw UnimplementedError();

  @override
  Future<List<RatingCorrection>> getCorrectionsForRating(int ratingId) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<RatingRecord>> getRatingRecordsForSessionRecoveryExport(
      int sessionId) async {
    final list =
        ratings.where((r) => r.sessionId == sessionId).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  @override
  Future<List<RatingRecord>> getRatingRecordsForTrialRecoveryExport(
      int trialId) async {
    final list = ratings.where((r) => r.trialId == trialId).toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }
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
