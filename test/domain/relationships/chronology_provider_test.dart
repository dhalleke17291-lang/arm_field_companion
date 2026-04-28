// Tests for chronologyProvider.
//
// Uses ProviderContainer with databaseProvider overridden to an in-memory DB.
// seedingRepositoryProvider and applicationRepositoryProvider resolve
// automatically through the overridden databaseProvider.

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/relationships/chronology_provider.dart';
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

Future<void> _createSeeding(AppDatabase db, int trialId, DateTime date) =>
    db.into(db.seedingEvents).insert(
          SeedingEventsCompanion.insert(trialId: trialId, seedingDate: date),
        );

Future<void> _createApplication(
        AppDatabase db, int trialId, DateTime date) =>
    db.into(db.trialApplicationEvents).insert(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: date,
          ),
        );

Future<int> _createSession(
        AppDatabase db, int trialId, String dateLocal) =>
    db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S $dateLocal',
            sessionDateLocal: dateLocal,
          ),
        );

Future<List<ChronologyEvent>> _run(ProviderContainer c, int trialId) =>
    c.read(chronologyProvider(trialId).future);

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
    test('returns [] when no events exist', () async {
      final trialId = await _createTrial(db);
      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });

  // ── One event per type ────────────────────────────────────────────────────

  group('one event per type', () {
    test('seeding event is mapped correctly', () async {
      final trialId = await _createTrial(db);
      final date = DateTime.utc(2026, 4, 1);
      await _createSeeding(db, trialId, date);

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      expect(result.first.type, ChronologyEventType.seeding);
      expect(result.first.label, 'Seeding');
      expect(result.first.date!.isAtSameMomentAs(date), isTrue);
      expect(result.first.entityId, isNull); // UUID PK
    });

    test('application event is mapped correctly', () async {
      final trialId = await _createTrial(db);
      final date = DateTime.utc(2026, 5, 10);
      await _createApplication(db, trialId, date);

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      expect(result.first.type, ChronologyEventType.application);
      expect(result.first.label, 'Application');
      expect(result.first.date!.isAtSameMomentAs(date), isTrue);
      expect(result.first.entityId, isNull); // UUID PK
    });

    test('session event is mapped correctly', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-15');

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      expect(result.first.type, ChronologyEventType.session);
      expect(result.first.label, 'Rating Session');
      expect(result.first.date, isNotNull);
      expect(result.first.entityId, sessionId);
    });
  });

  // ── Multiple events mixed ─────────────────────────────────────────────────

  group('multiple events', () {
    test('all three types are returned together', () async {
      final trialId = await _createTrial(db);
      await _createSeeding(db, trialId, DateTime.utc(2026, 4, 1));
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 10));
      await _createSession(db, trialId, '2026-6-20');

      final result = await _run(container, trialId);
      expect(result, hasLength(3));
      final types = result.map((e) => e.type).toSet();
      expect(
        types,
        containsAll({
          ChronologyEventType.seeding,
          ChronologyEventType.application,
          ChronologyEventType.session,
        }),
      );
    });

    test('multiple applications all appear', () async {
      final trialId = await _createTrial(db);
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 1));
      await _createApplication(db, trialId, DateTime.utc(2026, 5, 20));

      final result = await _run(container, trialId);
      expect(result.where((e) => e.type == ChronologyEventType.application),
          hasLength(2));
    });
  });

  // ── Null date handling ────────────────────────────────────────────────────

  group('null date handling', () {
    test('session with unparseable dateLocal has null date', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, 'NOT-A-DATE');

      final result = await _run(container, trialId);
      expect(result, hasLength(1));
      expect(result.first.date, isNull);
      expect(result.first.type, ChronologyEventType.session);
    });

    test('event with null date is still included in output', () async {
      final trialId = await _createTrial(db);
      await _createSession(db, trialId, 'BAD');
      await _createSeeding(db, trialId, DateTime.utc(2026, 4, 1));

      final result = await _run(container, trialId);
      expect(result, hasLength(2));
    });
  });

  // ── Sort correctness ──────────────────────────────────────────────────────

  group('sort correctness', () {
    test('events sorted by date ascending', () async {
      final trialId = await _createTrial(db);
      // Insert in reverse order.
      await _createApplication(db, trialId, DateTime.utc(2026, 7, 1));
      await _createSeeding(db, trialId, DateTime.utc(2026, 4, 1));
      await _createSession(db, trialId, '2026-05-15');

      final result = await _run(container, trialId);
      expect(result[0].type, ChronologyEventType.seeding);    // Apr 1
      expect(result[1].type, ChronologyEventType.session);    // May 15
      expect(result[2].type, ChronologyEventType.application); // Jul 1
    });

    test('null-date events go last', () async {
      final trialId = await _createTrial(db);
      await _createSeeding(db, trialId, DateTime.utc(2026, 4, 1));
      await _createSession(db, trialId, 'BAD-DATE'); // null date

      final result = await _run(container, trialId);
      expect(result.first.type, ChronologyEventType.seeding);
      expect(result.last.date, isNull);
    });

    test('events on same date preserve insertion order (stable sort)', () async {
      final trialId = await _createTrial(db);
      final sameDate = DateTime.utc(2026, 6, 1);
      // Seeding first, then application, both on same date.
      await _createSeeding(db, trialId, sameDate);
      await _createApplication(db, trialId, sameDate);

      final result = await _run(container, trialId);
      expect(result, hasLength(2));
      expect(result[0].type, ChronologyEventType.seeding);
      expect(result[1].type, ChronologyEventType.application);
    });

    test('deleted sessions are excluded', () async {
      final trialId = await _createTrial(db);
      final sessionId = await _createSession(db, trialId, '2026-06-01');
      // Soft-delete the session.
      await (db.update(db.sessions)..where((s) => s.id.equals(sessionId)))
          .write(const SessionsCompanion(isDeleted: Value(true)));

      final result = await _run(container, trialId);
      expect(result, isEmpty);
    });
  });
}
