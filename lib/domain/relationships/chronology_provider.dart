import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../primitives/event_ordering.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum ChronologyEventType { seeding, application, session }

class ChronologyEvent {
  final DateTime? date;
  final ChronologyEventType type;

  /// Integer PK of the source row, or null when the source table uses a UUID
  /// primary key (seeding_events, trial_application_events).
  final int? entityId;

  final String label;

  const ChronologyEvent({
    required this.date,
    required this.type,
    required this.entityId,
    required this.label,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final chronologyProvider =
    FutureProvider.autoDispose.family<List<ChronologyEvent>, int>(
        (ref, trialId) async {
  final db = ref.watch(databaseProvider);
  final seedingRepo = ref.watch(seedingRepositoryProvider);
  final appRepo = ref.watch(applicationRepositoryProvider);

  // ── Parallel load ─────────────────────────────────────────────────────────
  final results = await Future.wait([
    seedingRepo.getSeedingEventForTrial(trialId),

    appRepo.getApplicationsForTrial(trialId),

    (db.select(db.sessions)
          ..where(
              (s) => s.trialId.equals(trialId) & s.isDeleted.equals(false))
          ..orderBy([(s) => drift.OrderingTerm.asc(s.startedAt)]))
        .get(),
  ]);

  final seeding = results[0] as SeedingEvent?;
  final applications = results[1] as List<TrialApplicationEvent>;
  final sessions = results[2] as List<Session>;

  // ── Map to ChronologyEvent ────────────────────────────────────────────────
  final events = <ChronologyEvent>[];

  if (seeding != null) {
    events.add(ChronologyEvent(
      date: seeding.seedingDate,
      type: ChronologyEventType.seeding,
      entityId: null, // UUID PK — not representable as int
      label: 'Seeding',
    ));
  }

  for (final app in applications) {
    events.add(ChronologyEvent(
      date: app.applicationDate,
      type: ChronologyEventType.application,
      entityId: null, // UUID PK — not representable as int
      label: 'Application',
    ));
  }

  for (final session in sessions) {
    events.add(ChronologyEvent(
      date: DateTime.tryParse(session.sessionDateLocal),
      type: ChronologyEventType.session,
      entityId: session.id,
      label: 'Rating Session',
    ));
  }

  // ── Sort: date ascending, null last, stable ───────────────────────────────
  final withDate = events.where((e) => e.date != null).toList();
  final withoutDate = events.where((e) => e.date == null).toList();

  return [
    ...sortByTimestamp(withDate, (e) => e.date!),
    ...withoutDate,
  ];
});
