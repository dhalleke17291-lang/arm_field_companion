// Tests for protocolDivergenceProvider.
//
// Uses ProviderContainer with databaseProvider overridden to an in-memory DB.
// armColumnMappingRepositoryProvider and seedingRepositoryProvider resolve
// automatically through the overridden databaseProvider.

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/protocol_divergence.dart';
import 'package:arm_field_companion/domain/relationships/protocol_divergence_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
}

Future<int> _createTrial(AppDatabase db) async {
  return db.into(db.trials).insert(
    TrialsCompanion.insert(name: 'Test Trial'),
  );
}

Future<int> _createSession(
  AppDatabase db,
  int trialId,
  String dateLocal,
) async {
  return db.into(db.sessions).insert(
    SessionsCompanion.insert(
      trialId: trialId,
      name: 'Session $dateLocal',
      sessionDateLocal: dateLocal,
    ),
  );
}

Future<void> _createArmMeta(
  AppDatabase db,
  int sessionId,
  String armRatingDate,
) async {
  await db.into(db.armSessionMetadata).insert(
    ArmSessionMetadataCompanion.insert(
      sessionId: sessionId,
      armRatingDate: armRatingDate,
    ),
  );
}

Future<void> _createSeeding(
  AppDatabase db,
  int trialId,
  DateTime seedingDate,
) async {
  await db.into(db.seedingEvents).insert(
    SeedingEventsCompanion.insert(
      trialId: trialId,
      seedingDate: seedingDate,
    ),
  );
}

/// Creates a minimal plot + assessment, then inserts one rating record.
/// Returns nothing — caller only needs the record to exist.
Future<void> _createRating(
  AppDatabase db,
  int trialId,
  int sessionId,
) async {
  final plotId = await db.into(db.plots).insert(
    PlotsCompanion.insert(trialId: trialId, plotId: 'P1'),
  );
  final assessmentId = await db.into(db.assessments).insert(
    AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
  );
  await db.into(db.ratingRecords).insert(
    RatingRecordsCompanion.insert(
      trialId: trialId,
      plotPk: plotId,
      assessmentId: assessmentId,
      sessionId: sessionId,
      numericValue: const Value(75.0),
    ),
  );
}

Future<List<ProtocolDivergence>> _run(
  ProviderContainer c,
  int trialId,
) => c.read(protocolDivergenceProvider(trialId).future);

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

  // ── Standalone trial ──────────────────────────────────────────────────────

  group('standalone trial (no ARM plan)', () {
    test('returns [] when arm_session_metadata is empty', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-07-01');

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });

    test('returns [] for trial with no sessions at all', () async {
      final trialId = await _createTrial(db);
      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });

  // ── On-plan session ───────────────────────────────────────────────────────

  group('on-plan session', () {
    test('emits no record when sessionDateLocal == armRatingDate', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-01');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });

  // ── Timing divergence ─────────────────────────────────────────────────────

  group('timing divergence', () {
    test('positive delta: session is 5 days late', () async {
      final trialId = await _createTrial(db);
      // ARM planned: Jul 1, actual: Jul 6
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final d = result.first;
      expect(d.type, DivergenceType.timing);
      expect(d.deltaDays, 5);
      expect(d.isMissing, false);
      expect(d.isUnexpected, false);
    });

    test('negative delta: session is 3 days early', () async {
      final trialId = await _createTrial(db);
      // ARM planned: Jul 10, actual: Jul 7
      final sessionId = await _createSession(db, trialId, '2026-07-07');
      await _createArmMeta(db, sessionId, '2026-07-10');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final d = result.first;
      expect(d.type, DivergenceType.timing);
      expect(d.deltaDays, -3);
    });

    test('entityId matches session id', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result.first.entityId, sessionId.toString());
    });

    test('eventKind is assessment', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result.first.eventKind, EventKind.assessment);
    });
  });

  // ── Missing ───────────────────────────────────────────────────────────────

  group('missing (ARM session with zero ratings)', () {
    test('emits missing when ratingCount == 0', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-01');
      await _createArmMeta(db, sessionId, '2026-07-01');
      // No ratings inserted.

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final d = result.first;
      expect(d.type, DivergenceType.missing);
      expect(d.isMissing, true);
      expect(d.isUnexpected, false);
    });

    test('missing record has null deltaDays', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-01');
      await _createArmMeta(db, sessionId, '2026-07-01');

      final result = await _run(container, trialId);
      expect(result.first.deltaDays, isNull);
    });
  });

  // ── Timing + missing together ─────────────────────────────────────────────

  group('timing and missing together', () {
    test('emits two separate records when session is late AND has no ratings',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      // No ratings — both conditions apply.

      final result = await _run(container, trialId);
      expect(result, hasLength(2));
      final types = result.map((d) => d.type).toSet();
      expect(types, containsAll({DivergenceType.timing, DivergenceType.missing}));
      // Both records share the same entityId.
      expect(result.every((d) => d.entityId == sessionId.toString()), isTrue);
    });
  });

  // ── Unexpected ────────────────────────────────────────────────────────────

  group('unexpected (manual session when ARM plan exists)', () {
    test('manual session is unexpected when ARM plan exists', () async {
      final trialId = await _createTrial(db);

      // ARM session (establishes the plan).
      final armSessionId = await _createSession(db, trialId, '2026-07-01');
      await _createArmMeta(db, armSessionId, '2026-07-01');
      await _createRating(db, trialId, armSessionId);

      // Manual session (no arm_session_metadata row).
      await _createSession(db, trialId, '2026-07-15');

      final result = await _run(container, trialId);
      final unexpected = result.where((d) => d.isUnexpected).toList();
      expect(unexpected, hasLength(1));
      expect(unexpected.first.type, DivergenceType.unexpected);
      expect(unexpected.first.deltaDays, isNull);
      expect(unexpected.first.plannedDat, isNull);
    });

    test('standalone trial with manual sessions emits nothing', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, '2026-07-01');
      // No arm_session_metadata → standalone → early exit.

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });

  // ── Null seeding anchor ───────────────────────────────────────────────────

  group('null seeding (no seeding_events row)', () {
    test('deltaDays still computed when seeding date is missing', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);
      // No seeding event inserted.

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final d = result.first;
      expect(d.type, DivergenceType.timing);
      expect(d.deltaDays, 5);           // computed from calendar dates
      expect(d.plannedDat, isNull);     // no seeding anchor
      expect(d.actualDat, isNull);      // no seeding anchor
    });

    test('plannedDat and actualDat are populated when seeding date exists',
        () async {
      final trialId = await _createTrial(db);
      // Seeding: Jun 1. Planned: Jul 1 = DAT 30. Actual: Jul 6 = DAT 35.
      await _createSeeding(
        db,
        trialId,
        DateTime.utc(2026, 6, 1),
      );
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      final d = result.first;
      expect(d.plannedDat, 30);
      expect(d.actualDat, 35);
      expect(d.deltaDays, 5);
    });
  });

  // ── Invalid date handling ─────────────────────────────────────────────────

  group('invalid date handling', () {
    test('session with unparseable sessionDateLocal is skipped', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, 'not-a-date');
      await _createArmMeta(db, sessionId, '2026-07-01');
      await _createRating(db, trialId, sessionId);
      // comparable = false because sessionDateLocal does not parse.
      // ratingCount = 1 → not missing either.

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });

    test('ARM metadata with unparseable armRatingDate is skipped for timing',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, 'INVALID');
      await _createRating(db, trialId, sessionId);

      final result = await _run(container, trialId);
      // comparable = false → no timing record.
      // ratingCount = 1 → not missing.
      expect(result, isEmpty);
    });

    test('unparseable armRatingDate still emits missing when ratingCount == 0',
        () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, sessionId, 'INVALID');
      // No ratings.

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      expect(result.first.type, DivergenceType.missing);
      expect(result.first.deltaDays, isNull);
    });
  });

  // ── Sorting ───────────────────────────────────────────────────────────────

  group('sorting', () {
    test('records sorted by actual date ascending', () async {
      final trialId = await _createTrial(db);

      // Insert in reverse order — Jul 20 before Jul 5.
      final s1 = await _createSession(db, trialId, '2026-07-20');
      await _createArmMeta(db, s1, '2026-07-10'); // +10 → timing
      await _createRating(db, trialId, s1);

      final s2 = await _createSession(db, trialId, '2026-07-05');
      await _createArmMeta(db, s2, '2026-07-01'); // +4 → timing
      await _createRating(db, trialId, s2);

      final result = await _run(container, trialId);
      expect(result, hasLength(2));
      // Earlier actual date (Jul 5) should come first.
      expect(result[0].entityId, s2.toString());
      expect(result[1].entityId, s1.toString());
    });

    test('records without parseable actual date go last', () async {
      final trialId = await _createTrial(db);

      // Normal session with timing divergence.
      final s1 = await _createSession(db, trialId, '2026-07-06');
      await _createArmMeta(db, s1, '2026-07-01');
      await _createRating(db, trialId, s1);

      // Session with bad date — goes last; emits missing (no rating check skipped).
      final s2 = await _createSession(db, trialId, 'BAD');
      await _createArmMeta(db, s2, '2026-06-01');
      // No rating → emits missing with null actualDate.

      final result = await _run(container, trialId);
      // s1 → timing (good date), s2 → missing (null date, goes last).
      final last = result.last;
      expect(last.type, DivergenceType.missing);
      expect(last.actualDat, isNull);
    });
  });
}
