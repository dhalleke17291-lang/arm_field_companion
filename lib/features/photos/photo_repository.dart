import 'package:drift/drift.dart';
import 'dart:io';
import '../../core/database/app_database.dart';

class PhotoRepository {
  final AppDatabase _db;

  PhotoRepository(this._db);

  Future<Photo> savePhoto({
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String tempPath,
    required String finalPath,
    String? caption,
    String? raterName,
    int? performedByUserId,
  }) async {
    return _db.transaction(() async {
      // Step 1 — insert DB record with temp path
      final photoId = await _db.into(_db.photos).insert(
            PhotosCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              sessionId: sessionId,
              filePath: finalPath,
              tempPath: Value(tempPath),
              status: const Value('pending'),
              caption: Value(caption),
            ),
          );

      // Step 2 — rename temp file to final path
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(finalPath);
      }

      // Step 3 — mark as final
      await (_db.update(_db.photos)..where((p) => p.id.equals(photoId)))
          .write(const PhotosCompanion(
        status: Value('final'),
        tempPath: Value(null),
      ));

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              sessionId: Value(sessionId),
              plotPk: Value(plotPk),
              eventType: 'PHOTO_CAPTURED',
              description: 'Photo saved for plot $plotPk',
              performedBy: Value(raterName),
              performedByUserId: Value(performedByUserId),
            ),
          );

      return await (_db.select(_db.photos)
            ..where((p) => p.id.equals(photoId)))
          .getSingle();
    });
  }

  Future<int> getPhotoCountForSession(int sessionId) async {
    final list = await (_db.select(_db.photos)
          ..where((p) => p.sessionId.equals(sessionId)))
        .get();
    return list.length;
  }

  Future<List<Photo>> getPhotosForPlot({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) {
    return (_db.select(_db.photos)
          ..where((p) =>
              p.trialId.equals(trialId) &
              p.plotPk.equals(plotPk) &
              p.sessionId.equals(sessionId))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
  }

  Future<void> cleanupOrphanTempFiles() async {
    final pendingPhotos = await (_db.select(_db.photos)
          ..where((p) => p.status.equals('pending')))
        .get();

    for (final photo in pendingPhotos) {
      if (photo.tempPath != null) {
        final tempFile = File(photo.tempPath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      await (_db.delete(_db.photos)..where((p) => p.id.equals(photo.id)))
          .go();
    }
  }

  Stream<List<Photo>> watchPhotosForPlot({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) {
    return (_db.select(_db.photos)
          ..where((p) =>
              p.trialId.equals(trialId) &
              p.plotPk.equals(plotPk) &
              p.sessionId.equals(sessionId))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .watch();
  }

  /// All photos for a trial (any session, any plot). Ordered by session then createdAt.
  Stream<List<Photo>> watchPhotosForTrial(int trialId) {
    return (_db.select(_db.photos)
          ..where((p) => p.trialId.equals(trialId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.sessionId),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .watch();
  }
}