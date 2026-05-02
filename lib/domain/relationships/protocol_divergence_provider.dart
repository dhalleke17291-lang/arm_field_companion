import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../primitives/event_ordering.dart';
import 'protocol_divergence.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final protocolDivergenceProvider =
    FutureProvider.autoDispose.family<List<ProtocolDivergence>, int>(
        (ref, trialId) async {
  final db = ref.watch(databaseProvider);
  final armRepo = ref.watch(armColumnMappingRepositoryProvider);
  final seedingRepo = ref.watch(seedingRepositoryProvider);

  // ── Q1–Q4: parallel load ─────────────────────────────────────────────────
  final results = await Future.wait([
    // Q1: non-deleted sessions for trial
    (db.select(db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false))
          ..orderBy([(s) => drift.OrderingTerm.asc(s.startedAt)]))
        .get(),

    // Q2: arm_session_metadata map for trial
    armRepo.getSessionMetadatasForTrial(trialId),

    // Q3: seeding event (single or null)
    seedingRepo.getSeedingEventForTrial(trialId),

    // Q5: rating count per session (aggregate)
    _loadRatingCounts(db, trialId),
  ]);

  final sessions = results[0] as List<Session>;
  final armMetaList = results[1] as List<ArmSessionMetadataData>;
  final seedingEvent = results[2] as SeedingEvent?;
  final ratingCountMap = results[3] as Map<int, int>;

  // ── Early exit: no ARM plan ───────────────────────────────────────────────
  if (armMetaList.isEmpty) return [];

  final armMetaMap = <int, ArmSessionMetadataData>{
    for (final m in armMetaList) m.sessionId: m,
  };

  final seedingDate = seedingEvent?.seedingDate;

  // ── Partition ─────────────────────────────────────────────────────────────
  final armSessions = <Session>[];
  final manualSessions = <Session>[];
  for (final s in sessions) {
    if (armMetaMap.containsKey(s.id)) {
      armSessions.add(s);
    } else {
      manualSessions.add(s);
    }
  }

  final output = <_DivergenceWithDate>[];

  // ── Emit unexpected (manual sessions) ────────────────────────────────────
  for (final session in manualSessions) {
    final actualDate = _tryParseDate(session.sessionDateLocal);
    final actualDat = (seedingDate != null && actualDate != null)
        ? actualDate.difference(seedingDate).inDays
        : null;
    output.add(_DivergenceWithDate(
      divergence: ProtocolDivergence(
        entityId: session.id.toString(),
        eventKind: EventKind.assessment,
        type: DivergenceType.unexpected,
        isMissing: false,
        isUnexpected: true,
        plannedDat: null,
        actualDat: actualDat,
        deltaDays: null,
      ),
      actualDate: actualDate,
    ));
  }

  // ── Emit timing + missing (ARM sessions) ─────────────────────────────────
  for (final session in armSessions) {
    final meta = armMetaMap[session.id]!;
    final ratingCount = ratingCountMap[session.id] ?? 0;

    final actualDate = _tryParseDate(session.sessionDateLocal);
    final plannedDate = _tryParseDate(meta.armRatingDate);
    final comparable = actualDate != null && plannedDate != null;

    final int? deltaDays =
        comparable ? actualDate.difference(plannedDate).inDays : null;

    final actualDat = (seedingDate != null && actualDate != null)
        ? actualDate.difference(seedingDate).inDays
        : null;
    final plannedDat = (seedingDate != null && plannedDate != null)
        ? plannedDate.difference(seedingDate).inDays
        : null;

    if (comparable && deltaDays != 0) {
      output.add(_DivergenceWithDate(
        divergence: ProtocolDivergence(
          entityId: session.id.toString(),
          eventKind: EventKind.assessment,
          type: DivergenceType.timing,
          isMissing: false,
          isUnexpected: false,
          plannedDat: plannedDat,
          actualDat: actualDat,
          deltaDays: deltaDays,
        ),
        actualDate: actualDate,
      ));
    }

    if (ratingCount == 0) {
      output.add(_DivergenceWithDate(
        divergence: ProtocolDivergence(
          entityId: session.id.toString(),
          eventKind: EventKind.assessment,
          type: DivergenceType.missing,
          isMissing: true,
          isUnexpected: false,
          plannedDat: plannedDat,
          actualDat: actualDat,
          deltaDays: null,
        ),
        actualDate: actualDate,
      ));
    }
  }

  // ── Sort: actual date ascending, null dates last, stable ─────────────────
  final withDate = output.where((d) => d.actualDate != null).toList();
  final withoutDate = output.where((d) => d.actualDate == null).toList();

  final sorted = sortByTimestamp(
    withDate,
    (d) => d.actualDate!,
  );

  return [
    ...sorted.map((d) => d.divergence),
    ...withoutDate.map((d) => d.divergence),
  ];
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Aggregate rating count per session for [trialId].
/// One query — not N queries.
Future<Map<int, int>> _loadRatingCounts(AppDatabase db, int trialId) async {
  final rows = await db.customSelect(
    'SELECT session_id, COUNT(*) AS cnt '
    'FROM rating_records '
    'WHERE trial_id = ? AND is_deleted = 0 AND is_current = 1 '
    'GROUP BY session_id',
    variables: [drift.Variable.withInt(trialId)],
    readsFrom: {db.ratingRecords},
  ).get();
  return {
    for (final r in rows)
      r.read<int>('session_id'): r.read<int>('cnt'),
  };
}

/// Parses a YYYY-MM-DD text field to UTC midnight. Returns null on failure.
DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toUtc();
  } catch (_) {
    return null;
  }
}

/// Internal carrier used only for sorting; discarded before return.
class _DivergenceWithDate {
  final ProtocolDivergence divergence;
  final DateTime? actualDate;
  const _DivergenceWithDate({required this.divergence, required this.actualDate});
}
