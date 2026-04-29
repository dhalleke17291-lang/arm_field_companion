// Tests for evidenceAnchorsProvider.
//
// Uses ProviderContainer with databaseProvider overridden to an in-memory DB.
// applicationRepositoryProvider resolves automatically through databaseProvider.

import 'package:arm_field_companion/core/database/app_database.dart'
    hide EvidenceAnchor;
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/evidence_anchors_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(AppDatabase db) => ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

Future<int> _createTrial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

Future<int> _createSession(
  AppDatabase db,
  int trialId,
  String dateLocal,
) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S $dateLocal',
            sessionDateLocal: dateLocal,
          ),
        );

Future<void> _softDeleteSession(AppDatabase db, int sessionId) =>
    (db.update(db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(const SessionsCompanion(isDeleted: Value(true)));

Future<void> _createApplication(
  AppDatabase db,
  int trialId,
  DateTime date, {
  double? lat,
  double? lng,
  double? temperature,
  double? windSpeed,
  double? humidity,
}) =>
    db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: date,
            capturedLatitude: Value(lat),
            capturedLongitude: Value(lng),
            temperature: Value(temperature),
            windSpeed: Value(windSpeed),
            humidity: Value(humidity),
          ),
        );

Future<int> _createPlot(AppDatabase db, int trialId) =>
    db.into(db.plots).insert(
          PlotsCompanion.insert(trialId: trialId, plotId: 'P1'),
        );

Future<int> _createPhoto(
  AppDatabase db,
  int trialId,
  int sessionId,
  int plotPk, {
  bool isDeleted = false,
}) =>
    db.into(db.photos).insert(
          PhotosCompanion.insert(
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            filePath: 'photo_$sessionId.jpg',
            isDeleted: Value(isDeleted),
          ),
        );

Future<void> _createWeatherSnapshot(
  AppDatabase db,
  int trialId,
  int sessionId,
) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.weatherSnapshots).insert(
        WeatherSnapshotsCompanion.insert(
          uuid: 'uuid-$sessionId',
          trialId: trialId,
          parentId: sessionId,
          recordedAt: nowMs,
          createdAt: nowMs,
          modifiedAt: nowMs,
          createdBy: 'test',
        ),
      );
}

Future<void> _createRatingWithGps(
  AppDatabase db,
  int trialId,
  int sessionId, {
  double? lat = 51.5,
  double? lng = -0.1,
}) async {
  final plotPk = await _createPlot(db, trialId);
  final assessmentId = await db
      .into(db.assessments)
      .insert(AssessmentsCompanion.insert(trialId: trialId, name: 'A'));
  await db.into(db.ratingRecords).insert(
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

Future<List<EvidenceAnchor>> _run(ProviderContainer c, int trialId) =>
    c.read(evidenceAnchorsProvider(trialId).future);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = _makeContainer(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ── Empty trial ───────────────────────────────────────────────────────────

  group('empty trial', () {
    test('returns [] when no sessions or applications exist', () async {
      final trialId = await _createTrial(db);
      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });

  // ── Session anchors ───────────────────────────────────────────────────────

  group('session anchor — no evidence', () {
    test('produces anchor with all false flags and empty photoIds', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-06-01');

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final a = result.first;
      expect(a.eventType, EvidenceEventType.session);
      expect(a.photoIds, isEmpty);
      expect(a.hasGps, false);
      expect(a.hasWeather, false);
      expect(a.hasTimestamp, true); // valid date
    });

    test('invalid sessionDateLocal gives hasTimestamp false', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, 'NOT-A-DATE');

      final result = await _run(container, trialId);
      expect(result.first.hasTimestamp, false);
    });
  });

  group('session anchor — photos', () {
    test('photos linked by sessionId appear in photoIds', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      final plotPk = await _createPlot(db, trialId);
      final photoId = await _createPhoto(db, trialId, sessionId, plotPk);

      final result = await _run(container, trialId);
      expect(result.first.photoIds, contains(photoId));
    });

    test('deleted photos are excluded from photoIds', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      final plotPk = await _createPlot(db, trialId);
      await _createPhoto(db, trialId, sessionId, plotPk, isDeleted: true);

      final result = await _run(container, trialId);
      expect(result.first.photoIds, isEmpty);
    });

    test('multiple photos from same session all appear', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      final plotPk = await _createPlot(db, trialId);
      final id1 = await _createPhoto(db, trialId, sessionId, plotPk);
      final id2 = await _createPhoto(db, trialId, sessionId, plotPk);

      final result = await _run(container, trialId);
      expect(result.first.photoIds, containsAll([id1, id2]));
    });
  });

  group('session anchor — GPS', () {
    test('hasGps true when rating record has both lat and lng', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      await _createRatingWithGps(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result.first.hasGps, true);
    });

    test('hasGps false when rating record has only latitude', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      await _createRatingWithGps(db, trialId, sessionId, lat: 51.5, lng: null);

      final result = await _run(container, trialId);
      expect(result.first.hasGps, false);
    });

    test('hasGps false when rating record has only longitude', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      await _createRatingWithGps(db, trialId, sessionId, lat: null, lng: -0.1);

      final result = await _run(container, trialId);
      expect(result.first.hasGps, false);
    });

    test('hasGps false when no rating records exist', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-06-01');

      final result = await _run(container, trialId);
      expect(result.first.hasGps, false);
    });
  });

  group('session anchor — weather', () {
    test('hasWeather true when WeatherSnapshot row exists for session', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      await _createWeatherSnapshot(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result.first.hasWeather, true);
    });

    test('hasWeather false when no WeatherSnapshot row exists', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-06-01');

      final result = await _run(container, trialId);
      expect(result.first.hasWeather, false);
    });
  });

  group('deleted sessions excluded', () {
    test('soft-deleted session does not appear in output', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      await _softDeleteSession(db, sessionId);

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });

    test('only non-deleted sessions appear when mixed', () async {
      final trialId = await _createTrial(db);
      final s1 = await _createSession(db, trialId, '2026-06-01');
      await _createSession(db, trialId, '2026-06-10');
      await _softDeleteSession(db, s1);

      final result = await _run(container, trialId);
      expect(result.where((a) => a.eventType == EvidenceEventType.session),
          hasLength(1));
    });
  });

  // ── Application anchors ───────────────────────────────────────────────────

  group('application anchor', () {
    test('photoIds is always empty (schema gap)', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.photoIds, isEmpty);
    });

    test('hasTimestamp always true (applicationDate is non-nullable)', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasTimestamp, true);
    });

    test('hasGps true when both lat and lng are set', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1),
          lat: 51.5, lng: -0.1);

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasGps, true);
    });

    test('hasGps false when only lat is set', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1),
          lat: 51.5);

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasGps, false);
    });

    test('hasGps false when no GPS captured', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasGps, false);
    });

    test('hasWeather true when temperature is set', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1),
          temperature: 22.0);

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasWeather, true);
    });

    test('hasWeather true when windSpeed is set', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1),
          windSpeed: 12.0);

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasWeather, true);
    });

    test('hasWeather false when all weather columns are null', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.hasWeather, false);
    });

    test('eventId is the UUID string (non-null, non-empty)', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      final app = result.firstWhere((a) => a.eventType == EvidenceEventType.application);
      expect(app.eventId, isNotEmpty);
    });
  });

  // ── Mixed trial — single load ─────────────────────────────────────────────

  group('mixed trial — provider owns all loading', () {
    test('returns anchors for both sessions and applications in one call',
        () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-06-01');
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));

      final result = await _run(container, trialId);
      expect(result, hasLength(2));
      final types = result.map((a) => a.eventType).toSet();
      expect(types,
          containsAll({EvidenceEventType.session, EvidenceEventType.application}));
    });

    test('photos from one session do not appear on another session', () async {
      final trialId = await _createTrial(db);
      final s1 = await _createSession(db, trialId, '2026-06-01');
      final s2 = await _createSession(db, trialId, '2026-06-10');
      final plotPk = await _createPlot(db, trialId);
      final photoId = await _createPhoto(db, trialId, s1, plotPk);

      final result = await _run(container, trialId);
      final a1 = result.firstWhere((a) => a.eventId == s1.toString());
      final a2 = result.firstWhere((a) => a.eventId == s2.toString());
      expect(a1.photoIds, contains(photoId));
      expect(a2.photoIds, isEmpty);
    });

    test('weather on one session does not bleed to another', () async {
      final trialId = await _createTrial(db);
      final s1 = await _createSession(db, trialId, '2026-06-01');
      final s2 = await _createSession(db, trialId, '2026-06-10');
      await _createWeatherSnapshot(db, trialId, s1);

      final result = await _run(container, trialId);
      final a1 = result.firstWhere((a) => a.eventId == s1.toString());
      final a2 = result.firstWhere((a) => a.eventId == s2.toString());
      expect(a1.hasWeather, true);
      expect(a2.hasWeather, false);
    });
  });
}
