import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/application_state.dart';
import '../../core/database/app_database.dart' hide SeTypeCausalProfile;
import '../../core/providers.dart';
import '../signals/se_type_causal_profile_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum CausalEventType { application, weather }

class CausalEvent {
  final CausalEventType type;
  final DateTime? eventDate;
  final int? daysBefore;
  final String label;

  const CausalEvent({
    required this.type,
    required this.eventDate,
    required this.daysBefore,
    required this.label,
  });
}

class CausalContext {
  final int ratingId;
  final List<CausalEvent> priorEvents;
  final String? seType;
  final SeTypeCausalProfile? profile;

  const CausalContext({
    required this.ratingId,
    required this.priorEvents,
    this.seType,
    this.profile,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final causalContextProvider =
    FutureProvider.autoDispose.family<CausalContext, int>(
        (ref, ratingId) async {
  final db = ref.watch(databaseProvider);

  // ── Load rating record ────────────────────────────────────────────────────
  final rating = await (db.select(db.ratingRecords)
        ..where((r) => r.id.equals(ratingId)))
      .getSingleOrNull();

  if (rating == null) {
    return CausalContext(ratingId: ratingId, priorEvents: []);
  }

  // ── Parallel load ─────────────────────────────────────────────────────────
  final results = await Future.wait([
    // 0: all application events for this trial (filter confirmed below)
    (db.select(db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(rating.trialId)))
        .get(),
    // 1: weather snapshot for this session (parentType = 'rating_session')
    (db.select(db.weatherSnapshots)
          ..where((w) => w.parentId.equals(rating.sessionId))
          ..limit(1))
        .get(),
  ]);

  final applications = results[0] as List<TrialApplicationEvent>;
  final snapshots = results[1] as List<WeatherSnapshot>;

  final ratingDateOnly = _dateOnly(rating.createdAt);
  final events = <CausalEvent>[];

  // ── Application events ────────────────────────────────────────────────────
  for (final app in applications) {
    final isConfirmed = app.appliedAt != null ||
        app.status == kAppStatusApplied ||
        app.status == 'complete';
    if (!isConfirmed) continue;

    final appDate = app.appliedAt ?? app.applicationDate;
    final appDateOnly = _dateOnly(appDate);
    final daysBefore = ratingDateOnly.difference(appDateOnly).inDays;
    if (daysBefore < 0) continue;

    events.add(CausalEvent(
      type: CausalEventType.application,
      eventDate: appDate,
      daysBefore: daysBefore,
      label: 'Application',
    ));
  }

  // ── Weather event ─────────────────────────────────────────────────────────
  if (snapshots.isNotEmpty) {
    final snap = snapshots.first;
    events.add(CausalEvent(
      type: CausalEventType.weather,
      eventDate:
          DateTime.fromMillisecondsSinceEpoch(snap.recordedAt, isUtc: true),
      daysBefore: null,
      label: 'Weather conditions recorded for session',
    ));
  }

  // ── SE type + causal profile lookup ──────────────────────────────────────
  String? seType;
  SeTypeCausalProfile? profile;

  if (rating.trialAssessmentId != null) {
    final meta = await (db.select(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(rating.trialAssessmentId!)))
        .getSingleOrNull();
    seType = meta?.ratingType;

    if (seType != null) {
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(rating.trialId)))
          .getSingleOrNull();
      profile = await lookupCausalProfile(
        db,
        seType,
        trial?.workspaceType ?? 'efficacy',
        trial?.region,
      );
    }
  }

  return CausalContext(
    ratingId: ratingId,
    priorEvents: events,
    seType: seType,
    profile: profile,
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
