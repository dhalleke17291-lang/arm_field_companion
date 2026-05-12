import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/database/app_database.dart';
import '../../domain/evidence/evidence_anchor_repository.dart';

const int kThumbnailSize = 200;

String thumbnailPathFor(String originalPath) {
  final lastDot = originalPath.lastIndexOf('.');
  if (lastDot < 0) return '${originalPath}_thumb';
  return '${originalPath.substring(0, lastDot)}_thumb${originalPath.substring(lastDot)}';
}

Future<void> generateThumbnailInBackground(String originalPath) async {
  try {
    await compute(_generateThumbnail, originalPath);
  } catch (_) {
    // Thumbnail generation failure is non-fatal.
  }
}

void _generateThumbnail(String originalPath) {
  final file = File(originalPath);
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return;
  final thumb = img.copyResize(decoded,
      width: kThumbnailSize,
      height: kThumbnailSize,
      interpolation: img.Interpolation.average);
  final thumbPath = thumbnailPathFor(originalPath);
  File(thumbPath).writeAsBytesSync(img.encodeJpg(thumb, quality: 80));
}

class PhotoRepository {
  final AppDatabase _db;

  PhotoRepository(this._db);

  /// Resolves a stored photo path to an absolute path using the current
  /// documents directory. Handles both legacy absolute paths (which embed an
  /// iOS sandbox UUID that may have rotated) and new filename-only values by
  /// extracting the basename and rejoining with the current docs/photos dir.
  ///
  /// The [docsDir] parameter exists for testing — pass a fake directory to
  /// avoid hitting path_provider in unit tests.
  static Future<String> resolvePhotoPath(
    String storedPath, {
    Directory? docsDir,
  }) async {
    final filename = path.basename(storedPath);
    final dir = docsDir ?? await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'photos', filename);
  }

  Future<Photo> savePhoto({
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String tempPath,
    required String finalPath,
    String? caption,
    String? raterName,
    int? performedByUserId,
    int? assessmentId,
    double? ratingValue,
  }) async {
    final photo = await _db.transaction(() async {
      final photoId = await _db.into(_db.photos).insert(
            PhotosCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              sessionId: sessionId,
              filePath: path.basename(finalPath),
              tempPath: Value(tempPath),
              status: const Value('pending'),
              caption: Value(caption),
              assessmentId: Value(assessmentId),
              ratingValue: Value(ratingValue),
            ),
          );

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.rename(finalPath);
      }

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

      return await (_db.select(_db.photos)..where((p) => p.id.equals(photoId)))
          .getSingle();
    });

    try {
      await EvidenceAnchorRepository(_db).writePhotoAnchors(
        trialId: trialId,
        photoId: photo.id,
        sessionId: sessionId,
        plotPk: plotPk,
        anchoredBy: performedByUserId,
      );
    } catch (_) {}

    // Fire-and-forget: generate thumbnail in background isolate.
    generateThumbnailInBackground(finalPath);

    return photo;
  }

  Future<int> getPhotoCountForSession(int sessionId) async {
    final list = await (_db.select(_db.photos)
          ..where(
              (p) => p.sessionId.equals(sessionId) & p.isDeleted.equals(false)))
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
              p.sessionId.equals(sessionId) &
              p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
  }

  Future<List<Photo>> getPhotosForPlotInSession({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) {
    return getPhotosForPlot(
      trialId: trialId,
      plotPk: plotPk,
      sessionId: sessionId,
    );
  }

  Future<void> updateCaption(
    int id,
    String? caption, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final photo = await (_db.select(_db.photos)
          ..where((p) => p.id.equals(id) & p.isDeleted.equals(false)))
        .getSingleOrNull();
    if (photo == null) return;

    final trimmed = caption?.trim();
    final normalized = trimmed == null || trimmed.isEmpty ? null : trimmed;

    await _db.transaction(() async {
      await (_db.update(_db.photos)..where((p) => p.id.equals(id))).write(
        PhotosCompanion(caption: Value(normalized)),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(photo.trialId),
              sessionId: Value(photo.sessionId),
              plotPk: Value(photo.plotPk),
              eventType: 'PHOTO_CAPTION_UPDATED',
              description: normalized == null
                  ? 'Photo caption cleared'
                  : 'Photo caption updated',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'photo_id': photo.id,
                'file_path': photo.filePath,
                'old_caption': photo.caption,
                'new_caption': normalized,
              })),
            ),
          );
    });
  }

  /// Soft-deletes a photo row. Does not delete the file on disk.
  Future<void> softDeletePhoto(int id,
      {String? deletedBy, int? deletedByUserId}) async {
    final photo = await (_db.select(_db.photos)
          ..where((p) => p.id.equals(id) & p.isDeleted.equals(false)))
        .getSingleOrNull();
    if (photo == null) return;

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.photos)..where((p) => p.id.equals(id))).write(
        PhotosCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(photo.trialId),
              sessionId: Value(photo.sessionId),
              plotPk: Value(photo.plotPk),
              eventType: 'PHOTO_DELETED',
              description: 'Photo soft-deleted',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'file_path': photo.filePath,
              })),
            ),
          );
    });
  }

  /// Soft-deleted photos for a session (Recovery), newest first.
  Future<List<Photo>> getDeletedPhotosForSession(int sessionId) {
    return (_db.select(_db.photos)
          ..where(
              (p) => p.sessionId.equals(sessionId) & p.isDeleted.equals(true))
          ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
        .get();
  }

  /// Hard delete intentional — temp/pending rows were never finalized and have
  /// no audit value.
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
      await (_db.delete(_db.photos)..where((p) => p.id.equals(photo.id))).go();
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
              p.sessionId.equals(sessionId) &
              p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .watch();
  }

  Future<List<Photo>> getPhotosForPlotAllSessions({
    required int trialId,
    required int plotPk,
  }) {
    return (_db.select(_db.photos)
          ..where((p) =>
              p.trialId.equals(trialId) &
              p.plotPk.equals(plotPk) &
              p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.asc(p.sessionId),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .get();
  }

  Stream<List<Photo>> watchPhotosForTrial(int trialId) {
    return (_db.select(_db.photos)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.asc(p.sessionId),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .watch();
  }

  Future<List<Photo>> getPhotosForTrial(int trialId) {
    return (_db.select(_db.photos)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.asc(p.sessionId),
            (p) => OrderingTerm.asc(p.createdAt),
          ]))
        .get();
  }
}
