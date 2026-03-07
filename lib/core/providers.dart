import "../data/repositories/treatment_repository.dart";
import "../data/repositories/application_repository.dart";
import "../domain/models/plot_context.dart";
import "../domain/usecases/resolve_plot_treatment.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'database/app_database.dart';
import '../features/trials/trial_repository.dart';
import '../features/plots/plot_repository.dart';
import '../features/sessions/session_repository.dart';
import '../features/ratings/rating_repository.dart';
import '../features/photos/photo_repository.dart';
import '../features/trials/usecases/create_trial_usecase.dart';
import '../features/ratings/usecases/save_rating_usecase.dart';
import '../features/sessions/usecases/create_session_usecase.dart';
import '../features/sessions/usecases/close_session_usecase.dart';
import '../features/export/data/export_repository.dart';
import '../features/export/domain/export_session_csv_usecase.dart';
import '../features/photos/usecases/save_photo_usecase.dart';

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

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(databaseProvider));
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(ref.watch(databaseProvider));
});

final createTrialUseCaseProvider = Provider<CreateTrialUseCase>((ref) {
  return CreateTrialUseCase(ref.watch(trialRepositoryProvider));
});

final saveRatingUseCaseProvider = Provider<SaveRatingUseCase>((ref) {
  return SaveRatingUseCase(ref.watch(ratingRepositoryProvider));
});

final createSessionUseCaseProvider = Provider<CreateSessionUseCase>((ref) {
  return CreateSessionUseCase(ref.watch(sessionRepositoryProvider));
});

final closeSessionUseCaseProvider = Provider<CloseSessionUseCase>((ref) {
  return CloseSessionUseCase(ref.watch(sessionRepositoryProvider));
});

final trialsStreamProvider = StreamProvider((ref) {
  return ref.watch(trialRepositoryProvider).watchAllTrials();
});

final plotsForTrialProvider =
    StreamProvider.family<List<Plot>, int>((ref, trialId) {
  return ref.watch(plotRepositoryProvider).watchPlotsForTrial(trialId);
});

final assessmentsForTrialProvider =
    StreamProvider.family<List<Assessment>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.assessments)
        ..where((a) => a.trialId.equals(trialId)))
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

final openSessionProvider =
    StreamProvider.family<Session?, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchOpenSession(trialId);
});

final sessionAssessmentsProvider =
    FutureProvider.family<List<Assessment>, int>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).getSessionAssessments(sessionId);
});

final ratedPlotPksProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) => r.sessionId.equals(sessionId) & r.isCurrent.equals(true)))
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
  int get hashCode =>
      Object.hash(trialId, plotPk, assessmentId, sessionId);
}

final currentRatingProvider =
    StreamProvider.family<RatingRecord?, CurrentRatingParams>(
        (ref, params) {
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

// ===== Photos =====

final savePhotoUseCaseProvider = Provider<SavePhotoUseCase>((ref) {
  return SavePhotoUseCase(ref.watch(photoRepositoryProvider));
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
    StreamProvider.family<List<RatingRecord>, PlotRatingParams>(
        (ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(params.trialId) &
            r.plotPk.equals(params.plotPk))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)]))
      .watch();
});
// ===== Treatment =====

final treatmentRepositoryProvider = Provider<TreatmentRepository>((ref) {
  return TreatmentRepository(ref.watch(databaseProvider));
});

final treatmentsForTrialProvider =
    StreamProvider.family<List<Treatment>, int>((ref, trialId) {
  return ref.watch(treatmentRepositoryProvider).watchTreatmentsForTrial(trialId);
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

final applicationsForTrialProvider =
    StreamProvider.family<List<ApplicationEvent>, int>((ref, trialId) {
  return ref.watch(applicationRepositoryProvider).watchEventsForTrial(trialId);
});
