import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Writes rows into `evidence_anchors` that link evidence artefacts
/// (photos, weather, GPS readings) to analytical claims (sessions, ratings).
///
/// All writes are idempotent: a Dart-level check skips the insert if an
/// identical (evidenceType, evidenceId, claimType, claimId) row already exists.
class EvidenceAnchorRepository {
  EvidenceAnchorRepository(this._db);

  final AppDatabase _db;

  /// Called after a session is successfully closed.
  ///
  /// Anchors every non-deleted photo, the weather snapshot (if any), and a
  /// single GPS record (if any rating carries coordinates) to the session claim.
  Future<void> writeSessionCloseAnchors({
    required int trialId,
    required int sessionId,
    int? anchoredBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final photos = await (_db.select(_db.photos)
          ..where(
              (p) => p.sessionId.equals(sessionId) & p.isDeleted.equals(false)))
        .get();
    for (final photo in photos) {
      await _insertIfAbsent(
        trialId: trialId,
        evidenceType: 'photo',
        evidenceId: photo.id,
        claimType: 'session',
        claimId: sessionId,
        anchoredAt: now,
        anchoredBy: anchoredBy,
      );
    }

    final weather = await (_db.select(_db.weatherSnapshots)
          ..where((w) => w.parentId.equals(sessionId)))
        .getSingleOrNull();
    if (weather != null) {
      await _insertIfAbsent(
        trialId: trialId,
        evidenceType: 'weather_snapshot',
        evidenceId: weather.id,
        claimType: 'session',
        claimId: sessionId,
        anchoredAt: now,
        anchoredBy: anchoredBy,
      );
    }

    // One GPS anchor per session: the first current rating with coordinates.
    final gpsRating = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false) &
              r.capturedLatitude.isNotNull()))
        .getSingleOrNull();
    if (gpsRating != null) {
      await _insertIfAbsent(
        trialId: trialId,
        evidenceType: 'gps_record',
        evidenceId: gpsRating.id,
        claimType: 'session',
        claimId: sessionId,
        anchoredAt: now,
        anchoredBy: anchoredBy,
      );
    }
  }

  /// Called after a photo is saved.
  ///
  /// Anchors the photo to its session, and to the current rating for [plotPk]
  /// in [sessionId] if one exists.
  Future<void> writePhotoAnchors({
    required int trialId,
    required int photoId,
    required int sessionId,
    required int plotPk,
    int? anchoredBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _insertIfAbsent(
      trialId: trialId,
      evidenceType: 'photo',
      evidenceId: photoId,
      claimType: 'session',
      claimId: sessionId,
      anchoredAt: now,
      anchoredBy: anchoredBy,
    );

    final rating = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.plotPk.equals(plotPk) &
              r.sessionId.equals(sessionId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false)))
        .getSingleOrNull();
    if (rating != null) {
      await _insertIfAbsent(
        trialId: trialId,
        evidenceType: 'photo',
        evidenceId: photoId,
        claimType: 'rating',
        claimId: rating.id,
        anchoredAt: now,
        anchoredBy: anchoredBy,
      );
    }
  }

  Future<void> _insertIfAbsent({
    required int trialId,
    required String evidenceType,
    required int evidenceId,
    required String claimType,
    required int claimId,
    required int anchoredAt,
    int? anchoredBy,
  }) async {
    final existing = await (_db.select(_db.evidenceAnchors)
          ..where((a) =>
              a.evidenceType.equals(evidenceType) &
              a.evidenceId.equals(evidenceId) &
              a.claimType.equals(claimType) &
              a.claimId.equals(claimId)))
        .getSingleOrNull();
    if (existing != null) return;

    await _db.into(_db.evidenceAnchors).insert(
          EvidenceAnchorsCompanion.insert(
            trialId: trialId,
            evidenceType: evidenceType,
            evidenceId: evidenceId,
            claimType: claimType,
            claimId: claimId,
            anchoredAt: anchoredAt,
            createdAt: anchoredAt,
            anchoredBy: Value(anchoredBy),
          ),
        );
  }
}
