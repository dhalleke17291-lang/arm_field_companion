import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum EvidenceEventType { session, application }

class EvidenceAnchor {
  final String eventId;
  final EvidenceEventType eventType;
  final List<int> photoIds;
  final bool hasGps;
  final bool hasWeather;
  final bool hasTimestamp;

  const EvidenceAnchor({
    required this.eventId,
    required this.eventType,
    required this.photoIds,
    required this.hasGps,
    required this.hasWeather,
    required this.hasTimestamp,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final evidenceAnchorsProvider =
    FutureProvider.autoDispose.family<List<EvidenceAnchor>, int>(
        (ref, trialId) async {
  final db = ref.watch(databaseProvider);
  final appRepo = ref.watch(applicationRepositoryProvider);

  // ── Parallel load (no session dependency) ────────────────────────────────
  final baseResults = await Future.wait([
    // 0: sessions — soft-delete enforced here
    (db.select(db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false)))
        .get(),
    // 1: application events — all rows (no soft-delete column)
    appRepo.getApplicationsForTrial(trialId),
    // 2: photos — soft-delete enforced here
    (db.select(db.photos)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get(),
  ]);

  final sessions = baseResults[0] as List<Session>;
  final applications = baseResults[1] as List<TrialApplicationEvent>;
  final photos = baseResults[2] as List<Photo>;

  if (sessions.isEmpty && applications.isEmpty) return [];

  final sessionIds = sessions.map((s) => s.id).toList();

  // ── Session-dependent queries (weather, GPS) ──────────────────────────────
  final List<WeatherSnapshot> weatherSnapshots;
  final List<RatingRecord> gpsRecords;

  if (sessionIds.isEmpty) {
    weatherSnapshots = [];
    gpsRecords = [];
  } else {
    final sessionResults = await Future.wait([
      // weather snapshots for filtered session ids
      (db.select(db.weatherSnapshots)
            ..where((w) => w.parentId.isIn(sessionIds)))
          .get(),
      // rating records with both lat and lng set — existence per session only
      (db.select(db.ratingRecords)
            ..where((r) =>
                r.sessionId.isIn(sessionIds) &
                r.capturedLatitude.isNotNull() &
                r.capturedLongitude.isNotNull()))
          .get(),
    ]);
    weatherSnapshots = sessionResults[0] as List<WeatherSnapshot>;
    gpsRecords = sessionResults[1] as List<RatingRecord>;
  }

  // ── Index structures ──────────────────────────────────────────────────────
  final photosBySession = <int, List<int>>{};
  for (final p in photos) {
    photosBySession.putIfAbsent(p.sessionId, () => []).add(p.id);
  }

  final sessionIdsWithWeather = {for (final w in weatherSnapshots) w.parentId};
  final sessionIdsWithGps = {for (final r in gpsRecords) r.sessionId};

  // ── Map to anchors ────────────────────────────────────────────────────────
  final anchors = <EvidenceAnchor>[];

  for (final session in sessions) {
    anchors.add(EvidenceAnchor(
      eventId: session.id.toString(),
      eventType: EvidenceEventType.session,
      photoIds: photosBySession[session.id] ?? [],
      hasGps: sessionIdsWithGps.contains(session.id),
      hasWeather: sessionIdsWithWeather.contains(session.id),
      hasTimestamp: DateTime.tryParse(session.sessionDateLocal) != null,
    ));
  }

  for (final app in applications) {
    anchors.add(EvidenceAnchor(
      eventId: app.id,
      eventType: EvidenceEventType.application,
      photoIds: const [],
      hasGps: app.capturedLatitude != null && app.capturedLongitude != null,
      hasWeather: app.temperature != null ||
          app.windSpeed != null ||
          app.humidity != null,
      hasTimestamp: true, // applicationDate is non-nullable
    ));
  }

  return anchors;
});
