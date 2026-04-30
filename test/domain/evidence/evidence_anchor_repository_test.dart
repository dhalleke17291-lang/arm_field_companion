import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/evidence/evidence_anchor_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<({int trialId, int sessionId, int plotPk})> _seed(AppDatabase db) async {
  final trialId =
      await db.into(db.trials).insert(TrialsCompanion.insert(name: 'EvTest'));
  final sessionId = await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          trialId: trialId,
          name: 'S1',
          sessionDateLocal: '2026-04-29',
        ),
      );
  final plotPk = await db.into(db.plots).insert(
        PlotsCompanion.insert(trialId: trialId, plotId: '101'),
      );
  return (trialId: trialId, sessionId: sessionId, plotPk: plotPk);
}

Future<int> _insertPhoto(AppDatabase db,
        {required int trialId,
        required int sessionId,
        required int plotPk}) =>
    db.into(db.photos).insert(
          PhotosCompanion.insert(
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            filePath: 'photo_$sessionId.jpg',
          ),
        );

Future<int> _insertRatingWithGps(AppDatabase db,
    {required int trialId,
    required int sessionId,
    required int plotPk,
    double? lat = 51.5,
    double? lng = -0.1}) async {
  final assessmentId = await db
      .into(db.assessments)
      .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'W003'));
  return db.into(db.ratingRecords).insert(
        RatingRecordsCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: assessmentId,
          sessionId: sessionId,
          capturedLatitude: Value(lat),
          capturedLongitude: Value(lng),
        ),
      );
}

Future<int> _insertWeather(AppDatabase db,
    {required int trialId, required int sessionId}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.into(db.weatherSnapshots).insert(
        WeatherSnapshotsCompanion.insert(
          uuid: 'uuid-$sessionId',
          trialId: trialId,
          parentId: sessionId,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 'test',
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EvidenceAnchorRepository', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('1 — session close anchors photos and weather to session', () async {
      final seed = await _seed(db);
      final photoId = await _insertPhoto(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);
      final weatherId =
          await _insertWeather(db, trialId: seed.trialId, sessionId: seed.sessionId);

      await EvidenceAnchorRepository(db).writeSessionCloseAnchors(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      final anchors = await db.select(db.evidenceAnchors).get();
      expect(anchors, hasLength(2));
      expect(
        anchors.any((a) =>
            a.evidenceType == 'photo' &&
            a.evidenceId == photoId &&
            a.claimType == 'session' &&
            a.claimId == seed.sessionId),
        isTrue,
      );
      expect(
        anchors.any((a) =>
            a.evidenceType == 'weather_snapshot' &&
            a.evidenceId == weatherId &&
            a.claimType == 'session' &&
            a.claimId == seed.sessionId),
        isTrue,
      );
    });

    test('2 — session close writes GPS anchor when ratings have coords',
        () async {
      final seed = await _seed(db);
      final ratingId = await _insertRatingWithGps(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);

      await EvidenceAnchorRepository(db).writeSessionCloseAnchors(
        trialId: seed.trialId,
        sessionId: seed.sessionId,
      );

      final gpsAnchors = await (db.select(db.evidenceAnchors)
            ..where((a) => a.evidenceType.equals('gps_record')))
          .get();
      expect(gpsAnchors, hasLength(1));
      expect(gpsAnchors.single.evidenceId, ratingId);
      expect(gpsAnchors.single.claimType, 'session');
      expect(gpsAnchors.single.claimId, seed.sessionId);
    });

    test('3 — photo save writes session anchor (and rating anchor when present)',
        () async {
      final seed = await _seed(db);
      final ratingId = await _insertRatingWithGps(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk,
          lat: null,
          lng: null);
      final photoId = await _insertPhoto(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);

      await EvidenceAnchorRepository(db).writePhotoAnchors(
        trialId: seed.trialId,
        photoId: photoId,
        sessionId: seed.sessionId,
        plotPk: seed.plotPk,
      );

      final anchors = await db.select(db.evidenceAnchors).get();
      expect(anchors, hasLength(2));
      expect(
        anchors.any((a) =>
            a.evidenceType == 'photo' &&
            a.evidenceId == photoId &&
            a.claimType == 'session' &&
            a.claimId == seed.sessionId),
        isTrue,
      );
      expect(
        anchors.any((a) =>
            a.evidenceType == 'photo' &&
            a.evidenceId == photoId &&
            a.claimType == 'rating' &&
            a.claimId == ratingId),
        isTrue,
      );
    });

    test('4 — duplicate calls do not create duplicate rows', () async {
      final seed = await _seed(db);
      final photoId = await _insertPhoto(db,
          trialId: seed.trialId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);
      await _insertWeather(db,
          trialId: seed.trialId, sessionId: seed.sessionId);

      final repo = EvidenceAnchorRepository(db);
      await repo.writeSessionCloseAnchors(
          trialId: seed.trialId, sessionId: seed.sessionId);
      await repo.writeSessionCloseAnchors(
          trialId: seed.trialId, sessionId: seed.sessionId);
      await repo.writePhotoAnchors(
          trialId: seed.trialId,
          photoId: photoId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);
      await repo.writePhotoAnchors(
          trialId: seed.trialId,
          photoId: photoId,
          sessionId: seed.sessionId,
          plotPk: seed.plotPk);

      final anchors = await db.select(db.evidenceAnchors).get();
      // photo→session (1), weather→session (1). No rating exists, so no
      // photo→rating row. Calling twice must not duplicate.
      expect(anchors, hasLength(2));
    });
  });
}
