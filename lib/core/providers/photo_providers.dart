import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../features/photos/usecases/save_photo_usecase.dart';
import 'infrastructure_providers.dart';
import 'session_providers.dart';

final savePhotoUseCaseProvider = Provider<SavePhotoUseCase>((ref) {
  return SavePhotoUseCase(
    ref.watch(photoRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
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

/// Photos for a plot in a session (live updates).
final photosForPlotInSessionProvider = StreamProvider.autoDispose
    .family<List<Photo>, PhotosForPlotParams>((ref, params) {
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

final photosForPlotAllSessionsProvider = FutureProvider.autoDispose
    .family<List<Photo>, ({int trialId, int plotPk})>((ref, params) {
  return ref.watch(photoRepositoryProvider).getPhotosForPlotAllSessions(
        trialId: params.trialId,
        plotPk: params.plotPk,
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
    StreamProvider.family<List<RatingRecord>, PlotRatingParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(params.trialId) &
            r.plotPk.equals(params.plotPk) &
            r.isDeleted.equals(false))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)]))
      .watch();
});
