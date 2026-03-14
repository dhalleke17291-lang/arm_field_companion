import "../data/repositories/treatment_repository.dart";
import "../data/repositories/assignment_repository.dart";
import "../data/repositories/assessment_definition_repository.dart";
import "../data/repositories/trial_assessment_repository.dart";
import "../data/repositories/application_repository.dart";
import "../data/repositories/seeding_repository.dart";
import "../domain/models/plot_context.dart";
import "../domain/usecases/resolve_plot_treatment.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'database/app_database.dart';
import '../features/trials/trial_repository.dart';
import '../features/plots/plot_repository.dart';
import '../features/plots/usecases/update_plot_assignment_usecase.dart';
import '../features/protocol_import/protocol_import_usecase.dart';
import '../features/sessions/session_repository.dart';
import '../features/ratings/rating_repository.dart';
import '../features/photos/photo_repository.dart';
import '../features/trials/usecases/create_trial_usecase.dart';
import '../features/trials/usecases/update_treatment_usecase.dart';
import '../features/trials/usecases/delete_treatment_usecase.dart';
import '../features/ratings/usecases/save_rating_usecase.dart';
import '../features/ratings/usecases/undo_rating_usecase.dart';
import '../features/ratings/usecases/apply_correction_usecase.dart';
import '../features/sessions/usecases/create_session_usecase.dart';
import '../features/sessions/usecases/close_session_usecase.dart';
import '../features/sessions/usecases/start_or_continue_rating_usecase.dart';
import '../features/export/data/export_repository.dart';
import '../features/export/domain/export_session_csv_usecase.dart';
import '../features/export/domain/export_session_arm_xml_usecase.dart';
import '../features/export/domain/export_trial_closed_sessions_usecase.dart';
import '../features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart';
import '../features/export/export_trial_usecase.dart';
import '../features/photos/usecases/save_photo_usecase.dart';
import '../features/users/user_repository.dart';
import '../features/diagnostics/integrity_check_repository.dart';
import '../features/diagnostics/trial_diagnostics.dart';
import '../features/diagnostics/trial_readiness.dart';
import '../features/diagnostics/trial_readiness_service.dart';
import '../features/today/domain/activity_event.dart';
import '../features/today/today_activity_repository.dart';
import 'current_user.dart';
import 'diagnostics/diagnostics_store.dart';
import 'last_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final trialRepositoryProvider = Provider<TrialRepository>((ref) {
  return TrialRepository(ref.watch(databaseProvider));
});

final plotRepositoryProvider = Provider<PlotRepository>((ref) {
  return PlotRepository(ref.watch(databaseProvider));
});

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(ref.watch(databaseProvider));
});

final assessmentDefinitionRepositoryProvider =
    Provider<AssessmentDefinitionRepository>((ref) {
  return AssessmentDefinitionRepository(ref.watch(databaseProvider));
});

final trialAssessmentRepositoryProvider =
    Provider<TrialAssessmentRepository>((ref) {
  return TrialAssessmentRepository(ref.watch(databaseProvider));
});

final assessmentDefinitionsProvider =
    StreamProvider<List<AssessmentDefinition>>((ref) {
  return ref
      .watch(assessmentDefinitionRepositoryProvider)
      .watchAll(activeOnly: true);
});

final trialAssessmentsForTrialProvider =
    StreamProvider.family<List<TrialAssessment>, int>((ref, trialId) {
  return ref.watch(trialAssessmentRepositoryProvider).watchForTrial(trialId);
});

final trialAssessmentsWithDefinitionsForTrialProvider =
    StreamProvider.family<List<(TrialAssessment, AssessmentDefinition)>, int>(
        (ref, trialId) {
  return ref
      .watch(trialAssessmentRepositoryProvider)
      .watchForTrialWithDefinitions(trialId);
});

final updatePlotAssignmentUseCaseProvider =
    Provider<UpdatePlotAssignmentUseCase>((ref) {
  return UpdatePlotAssignmentUseCase(
    ref.watch(assignmentRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final protocolImportUseCaseProvider = Provider<ProtocolImportUseCase>((ref) {
  return ProtocolImportUseCase(
    ref.watch(trialRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(assignmentRepositoryProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(databaseProvider));
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(ref.watch(databaseProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(databaseProvider));
});

final diagnosticsStoreProvider = Provider<DiagnosticsStore>((ref) {
  return DiagnosticsStore(maxErrors: 50);
});

final integrityCheckRepositoryProvider =
    Provider<IntegrityCheckRepository>((ref) {
  return IntegrityCheckRepository(ref.watch(databaseProvider));
});

final todayActivityRepositoryProvider =
    Provider<TodayActivityRepository>((ref) {
  return TodayActivityRepository(ref.watch(databaseProvider));
});

/// Activity events for a given day (wall-clock date "yyyy-MM-dd"). AutoDispose, refresh on read.
final todayActivityProvider = FutureProvider.autoDispose
    .family<List<ActivityEvent>, String>((ref, dateLocal) async {
  final repo = ref.watch(todayActivityRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  return repo.getActivityForDate(dateLocal, currentUserId: userId);
});

/// Days with at least one activity (empty days excluded), with event count. For work log history.
final workLogDatesProvider =
    FutureProvider.autoDispose<List<({String dateLocal, int eventCount})>>(
        (ref) async {
  final repo = ref.watch(todayActivityRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  return repo.getDatesWithActivity(currentUserId: userId);
});

/// Sessions for work log: filter by date (sessionDateLocal) and optionally current user (createdByUserId).
final workLogSessionsProvider = FutureProvider.autoDispose
    .family<List<Session>, String>((ref, dateLocal) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  return repo.getSessionsForDate(dateLocal, createdByUserId: userId);
});

/// Number of plots rated in this session (current ratings only).
final ratingCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set = await ref.watch(ratedPlotPksProvider(sessionId).future);
  return set.length;
});

/// Number of plots flagged in this session.
final flagCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set =
      await ref.watch(flaggedPlotIdsForSessionProvider(sessionId).future);
  return set.length;
});

/// Number of photos in this session.
final photoCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) {
  return ref.read(photoRepositoryProvider).getPhotoCountForSession(sessionId);
});

final activeUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userRepositoryProvider).watchActiveUsers();
});

/// Current user id from SharedPreferences. Invalidate after set.
final currentUserIdProvider =
    FutureProvider.autoDispose<int?>((ref) => getCurrentUserId());

/// Full current user. Depends on currentUserIdProvider.
final currentUserProvider = FutureProvider.autoDispose<User?>((ref) async {
  final id = await ref.watch(currentUserIdProvider.future);
  if (id == null) return null;
  return ref.read(userRepositoryProvider).getUserById(id);
});

final createTrialUseCaseProvider = Provider<CreateTrialUseCase>((ref) {
  return CreateTrialUseCase(ref.watch(trialRepositoryProvider));
});

final updateTreatmentUseCaseProvider = Provider<UpdateTreatmentUseCase>((ref) {
  return UpdateTreatmentUseCase(ref.watch(treatmentRepositoryProvider));
});

final deleteTreatmentUseCaseProvider = Provider<DeleteTreatmentUseCase>((ref) {
  return DeleteTreatmentUseCase(ref.watch(treatmentRepositoryProvider));
});

final saveRatingUseCaseProvider = Provider<SaveRatingUseCase>((ref) {
  return SaveRatingUseCase(ref.watch(ratingRepositoryProvider));
});

final undoRatingUseCaseProvider = Provider<UndoRatingUseCase>((ref) {
  return UndoRatingUseCase(ref.watch(ratingRepositoryProvider));
});

final applyCorrectionUseCaseProvider = Provider<ApplyCorrectionUseCase>((ref) {
  return ApplyCorrectionUseCase(ref.watch(ratingRepositoryProvider));
});

/// Latest correction for a rating (for effective value display).
final latestCorrectionForRatingProvider =
    FutureProvider.autoDispose.family<RatingCorrection?, int>((ref, ratingId) {
  return ref
      .read(ratingRepositoryProvider)
      .getLatestCorrectionForRating(ratingId);
});

final createSessionUseCaseProvider = Provider<CreateSessionUseCase>((ref) {
  return CreateSessionUseCase(ref.watch(sessionRepositoryProvider));
});

final closeSessionUseCaseProvider = Provider<CloseSessionUseCase>((ref) {
  return CloseSessionUseCase(ref.watch(sessionRepositoryProvider));
});

final startOrContinueRatingUseCaseProvider =
    Provider<StartOrContinueRatingUseCase>((ref) {
  return StartOrContinueRatingUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
  );
});

final trialsStreamProvider = StreamProvider((ref) {
  return ref.watch(trialRepositoryProvider).watchAllTrials();
});

/// Current trial by id (e.g. for trial detail). Invalidate after status change.
final trialProvider = FutureProvider.autoDispose.family<Trial?, int>((ref, id) {
  return ref.watch(trialRepositoryProvider).getTrialById(id);
});

/// Trial setup fields (protocol, location, plot dimensions, soil, etc.). Watch for setup screen; invalidate after update.
final trialSetupProvider =
    FutureProvider.autoDispose.family<Trial?, int>((ref, trialId) {
  return ref.watch(trialRepositoryProvider).getTrialById(trialId);
});

final plotsForTrialProvider =
    StreamProvider.family<List<Plot>, int>((ref, trialId) {
  return ref.watch(plotRepositoryProvider).watchPlotsForTrial(trialId);
});

final assessmentsForTrialProvider =
    StreamProvider.family<List<Assessment>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.assessments)..where((a) => a.trialId.equals(trialId)))
      .watch();
});

final sessionsForTrialProvider =
    StreamProvider.family<List<Session>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.sessions)
        ..where((s) => s.trialId.equals(trialId))
        ..orderBy([(s) => drift.OrderingTerm.desc(s.startedAt)]))
      .watch();
});

/// Seeding records for a trial (for Seeding tab). Invalidate after add/edit/delete.
final seedingRecordsForTrialProvider = FutureProvider.autoDispose
    .family<List<SeedingRecord>, int>((ref, trialId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.seedingRecords)
        ..where((t) => t.trialId.equals(trialId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
      .get();
});

final openSessionProvider =
    StreamProvider.family<Session?, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchOpenSession(trialId);
});

/// Resolved trial + session for "Continue Last Session" home card.
class LastSessionContext {
  const LastSessionContext({required this.trial, required this.session});
  final Trial trial;
  final Session session;
}

/// Last session (trialId, sessionId) persisted for "Continue Last Session" home card. Valid only if session still exists and is open.
final lastSessionContextProvider =
    FutureProvider.autoDispose<LastSessionContext?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = LastSessionStore(prefs).get();
  if (ids == null) return null;
  final trialRepo = ref.read(trialRepositoryProvider);
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final trial = await trialRepo.getTrialById(ids.$1);
  final session = await sessionRepo.getSessionById(ids.$2);
  if (trial == null ||
      session == null ||
      session.endedAt != null ||
      session.trialId != trial.id) {
    return null;
  }
  return LastSessionContext(trial: trial, session: session);
});

final sessionAssessmentsProvider =
    FutureProvider.family<List<Assessment>, int>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).getSessionAssessments(sessionId);
});

final ratedPlotPksProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where(
            (r) => r.sessionId.equals(sessionId) & r.isCurrent.equals(true)))
      .watch()
      .map((ratings) => ratings.map((r) => r.plotPk).toSet());
});

class CurrentRatingParams {
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;

  const CurrentRatingParams({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is CurrentRatingParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk &&
      other.assessmentId == assessmentId &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(trialId, plotPk, assessmentId, sessionId);
}

final currentRatingProvider =
    StreamProvider.family<RatingRecord?, CurrentRatingParams>((ref, params) {
  return ref.watch(ratingRepositoryProvider).watchCurrentRating(
        trialId: params.trialId,
        plotPk: params.plotPk,
        assessmentId: params.assessmentId,
        sessionId: params.sessionId,
      );
});

final sessionRatingsProvider =
    FutureProvider.family<List<RatingRecord>, int>((ref, sessionId) {
  return ref
      .watch(ratingRepositoryProvider)
      .getCurrentRatingsForSession(sessionId);
});

// ===== Export (CSV) =====

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(databaseProvider));
});

final exportSessionCsvUsecaseProvider =
    Provider<ExportSessionCsvUsecase>((ref) {
  return ExportSessionCsvUsecase(ref.watch(exportRepositoryProvider));
});

final exportSessionArmXmlUsecaseProvider =
    Provider<ExportSessionArmXmlUsecase>((ref) {
  return ExportSessionArmXmlUsecase(ref.watch(exportRepositoryProvider));
});

final exportTrialClosedSessionsUsecaseProvider =
    Provider<ExportTrialClosedSessionsUsecase>((ref) {
  return ExportTrialClosedSessionsUsecase(
    ref.watch(exportSessionCsvUsecaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final exportTrialClosedSessionsArmXmlUsecaseProvider =
    Provider<ExportTrialClosedSessionsArmXmlUsecase>((ref) {
  return ExportTrialClosedSessionsArmXmlUsecase(
    ref.watch(exportSessionArmXmlUsecaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final exportTrialUseCaseProvider = Provider<ExportTrialUseCase>((ref) {
  return ExportTrialUseCase(
    trialRepository: ref.watch(trialRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    seedingRepository: ref.watch(seedingRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
  );
});

/// Trial readiness checks for pre-export diagnostics. AutoDispose, family by trialId.
final trialDiagnosticsProvider = FutureProvider.autoDispose
    .family<TrialReadinessResult, int>((ref, trialId) {
  return TrialDiagnosticsService().runChecks(trialId.toString(), ref);
});

/// Unified trial readiness report (blockers, warnings, passes). Used for readiness card and export gating.
final trialReadinessProvider = FutureProvider.autoDispose
    .family<TrialReadinessReport, int>((ref, trialId) {
  return TrialReadinessService().runChecks(trialId.toString(), ref);
});

/// Latest protocol import event for a trial (for opening saved CSV reference).
final latestImportEventForTrialProvider =
    StreamProvider.family<ImportEvent?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.importEvents)
        ..where((e) => e.trialId.equals(trialId))
        ..orderBy([(e) => drift.OrderingTerm.desc(e.createdAt)])
        ..limit(1))
      .watchSingleOrNull();
});

// ===== Photos =====

final savePhotoUseCaseProvider = Provider<SavePhotoUseCase>((ref) {
  return SavePhotoUseCase(ref.watch(photoRepositoryProvider));
});

/// Flags for a given plot in a session (for one-tap flag toggle on rating screen).
final plotFlagsForPlotSessionProvider =
    StreamProvider.family<List<PlotFlag>, (int, int)>((ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.plotFlags)
        ..where(
            (f) => f.plotPk.equals(params.$1) & f.sessionId.equals(params.$2)))
      .watch();
});

/// Set of plot IDs that have at least one flag in this session (for session/queue UI).
final flaggedPlotIdsForSessionProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.plotFlags)..where((f) => f.sessionId.equals(sessionId)))
      .watch()
      .map((list) => list.map((f) => f.plotPk).toSet());
});

class PhotosForPlotParams {
  final int trialId;
  final int plotPk;
  final int sessionId;

  const PhotosForPlotParams({
    required this.trialId,
    required this.plotPk,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is PhotosForPlotParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(trialId, plotPk, sessionId);
}

final photosForPlotProvider =
    StreamProvider.family<List<Photo>, PhotosForPlotParams>((ref, params) {
  return ref.watch(photoRepositoryProvider).watchPhotosForPlot(
        trialId: params.trialId,
        plotPk: params.plotPk,
        sessionId: params.sessionId,
      );
});

/// All photos for a trial (for trial-level Photos tab). Group by session in UI.
final photosForTrialProvider =
    StreamProvider.family<List<Photo>, int>((ref, trialId) {
  return ref.watch(photoRepositoryProvider).watchPhotosForTrial(trialId);
});

class PlotRatingParams {
  final int trialId;
  final int plotPk;

  const PlotRatingParams({required this.trialId, required this.plotPk});

  @override
  bool operator ==(Object other) =>
      other is PlotRatingParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk;

  @override
  int get hashCode => Object.hash(trialId, plotPk);
}

// Returns full rating history for a plot — all records ordered newest first.
final plotRatingHistoryProvider =
    StreamProvider.family<List<RatingRecord>, PlotRatingParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(params.trialId) & r.plotPk.equals(params.plotPk))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)]))
      .watch();
});
// ===== Treatment =====

final treatmentRepositoryProvider = Provider<TreatmentRepository>((ref) {
  return TreatmentRepository(
      ref.watch(databaseProvider), ref.watch(assignmentRepositoryProvider));
});

final treatmentsForTrialProvider =
    StreamProvider.family<List<Treatment>, int>((ref, trialId) {
  return ref
      .watch(treatmentRepositoryProvider)
      .watchTreatmentsForTrial(trialId);
});

/// Components for a single treatment (for Treatments tab expandable list). Invalidate after add/delete.
final treatmentComponentsForTreatmentProvider = FutureProvider.autoDispose
    .family<List<TreatmentComponent>, int>((ref, treatmentId) {
  return ref
      .watch(treatmentRepositoryProvider)
      .getComponentsForTreatment(treatmentId);
});

final assignmentsForTrialProvider =
    StreamProvider.family<List<Assignment>, int>((ref, trialId) {
  return ref.watch(assignmentRepositoryProvider).watchForTrial(trialId);
});

/// Total count of treatment components across all treatments for a trial (Trial Summary).
final treatmentComponentsCountForTrialProvider =
    FutureProvider.autoDispose.family<int, int>((ref, trialId) async {
  final repo = ref.watch(treatmentRepositoryProvider);
  final treatments = await repo.getTreatmentsForTrial(trialId);
  int count = 0;
  for (final t in treatments) {
    count += (await repo.getComponentsForTreatment(t.id)).length;
  }
  return count;
});

/// Count of distinct plots with at least one current rating for this trial (Trial Summary).
final ratedPlotsCountForTrialProvider =
    FutureProvider.autoDispose.family<int, int>((ref, trialId) {
  return ref.read(ratingRepositoryProvider).getRatedPlotCountForTrial(trialId);
});

final resolvePlotTreatmentProvider = Provider<ResolvePlotTreatment>((ref) {
  return ResolvePlotTreatment(
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
  );
});

final plotContextProvider =
    FutureProvider.autoDispose.family<PlotContext, int>((ref, plotPk) {
  return ref.watch(resolvePlotTreatmentProvider).execute(plotPk);
});

// ===== Applications =====

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(ref.watch(databaseProvider));
});

final seedingRepositoryProvider = Provider<SeedingRepository>((ref) {
  return SeedingRepository(ref.watch(databaseProvider));
});

/// Seeding event for a trial (one per trial). AutoDispose, family keyed by trialId.
final seedingEventForTrialProvider =
    FutureProvider.autoDispose.family<SeedingEvent?, int>((ref, trialId) {
  return ref.read(seedingRepositoryProvider).getSeedingEventForTrial(trialId);
});

/// Trial-level application events (trial_application_events), ordered by application_date ascending.
final trialApplicationsForTrialProvider = StreamProvider.autoDispose
    .family<List<TrialApplicationEvent>, int>((ref, trialId) {
  return ref
      .watch(applicationRepositoryProvider)
      .watchApplicationsForTrial(trialId);
});

/// Latest application event for a trial (most recent application_date). Null if none.
final latestApplicationForTrialProvider = FutureProvider.autoDispose
    .family<TrialApplicationEvent?, int>((ref, trialId) async {
  final list = await ref
      .watch(applicationRepositoryProvider)
      .getApplicationsForTrial(trialId);
  return list.isEmpty ? null : list.last;
});

/// Slot-based application events (application_events table). Legacy Applications tab and event selector.
final applicationsForTrialProvider =
    StreamProvider.family<List<ApplicationEvent>, int>((ref, trialId) {
  return ref.watch(applicationRepositoryProvider).watchEventsForTrial(trialId);
});
