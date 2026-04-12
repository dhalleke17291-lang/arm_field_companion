import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/field_operation_date_rules.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeedingRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SeedingRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTrial() async {
    return trialRepo.createTrial(
      name: 'Trial ${DateTime.now().microsecondsSinceEpoch}',
      workspaceType: 'efficacy',
    );
  }

  /// Today is the only date that is both >= trialCreatedAt and not in the future.
  DateTime today() => DateTime.now();

  group('upsertSeedingEvent', () {
    test('inserts new seeding event for trial', () async {
      final trialId = await createTrial();
      final seedingDate = today();

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: seedingDate,
          status: const Value('pending'),
        ),
        performedBy: 'tester',
      );

      final event = await repo.getSeedingEventForTrial(trialId);
      expect(event, isNotNull);
      expect(event!.trialId, trialId);
      expect(event.seedingDate.year, seedingDate.year);
      expect(event.seedingDate.month, seedingDate.month);
      expect(event.seedingDate.day, seedingDate.day);
    });

    test('updates existing event on second upsert (same trial)', () async {
      final trialId = await createTrial();
      final seedingDate = today();

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: seedingDate,
          status: const Value('pending'),
          variety: const Value('Variety A'),
        ),
      );

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: seedingDate,
          status: const Value('pending'),
          variety: const Value('Variety B'),
        ),
      );

      final event = await repo.getSeedingEventForTrial(trialId);
      expect(event, isNotNull);
      expect(event!.variety, 'Variety B');
    });

    test('rejects future seeding date', () async {
      final trialId = await createTrial();
      final futureDate = DateTime.now().add(const Duration(days: 5));

      expect(
        () => repo.upsertSeedingEvent(
          SeedingEventsCompanion.insert(
            trialId: trialId,
            seedingDate: futureDate,
            status: const Value('pending'),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('rejects non-existent trial', () async {
      expect(
        () => repo.upsertSeedingEvent(
          SeedingEventsCompanion.insert(
            trialId: 99999,
            seedingDate: today(),
            status: const Value('pending'),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('rejects emergence date before seeding date', () async {
      final trialId = await createTrial();
      final seedingDate = today();
      final earlyEmergence = seedingDate.subtract(const Duration(days: 1));

      expect(
        () => repo.upsertSeedingEvent(
          SeedingEventsCompanion.insert(
            trialId: trialId,
            seedingDate: seedingDate,
            status: const Value('pending'),
            emergenceDate: Value(earlyEmergence),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('accepts emergence date equal to seeding date', () async {
      final trialId = await createTrial();
      final seedingDate = today();

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: seedingDate,
          status: const Value('pending'),
          emergenceDate: Value(seedingDate),
        ),
      );

      final event = await repo.getSeedingEventForTrial(trialId);
      expect(event!.emergenceDate, isNotNull);
    });

    test('rejects emergence percent outside 0-100', () async {
      final trialId = await createTrial();

      expect(
        () => repo.upsertSeedingEvent(
          SeedingEventsCompanion.insert(
            trialId: trialId,
            seedingDate: today(),
            status: const Value('pending'),
            emergencePct: const Value(150.0),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('accepts valid emergence percent', () async {
      final trialId = await createTrial();

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          status: const Value('pending'),
          emergencePct: const Value(85.0),
        ),
      );

      final event = await repo.getSeedingEventForTrial(trialId);
      expect(event!.emergencePct, 85.0);
    });

    test('writes audit event on upsert', () async {
      final trialId = await createTrial();
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          status: const Value('pending'),
        ),
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('SEEDING_EVENT_UPSERTED')))
          .get();
      expect(audits.length, 1);
    });
  });

  group('markSeedingCompleted', () {
    test('sets status to completed', () async {
      final trialId = await createTrial();
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          status: const Value('pending'),
        ),
      );
      final event = await repo.getSeedingEventForTrial(trialId);

      await repo.markSeedingCompleted(
        id: event!.id,
        completedAt: DateTime.now(),
      );

      final updated = await repo.getSeedingEventForTrial(trialId);
      expect(updated!.status, 'completed');
      expect(updated.completedAt, isNotNull);
    });

    test('rejects future completion date', () async {
      final trialId = await createTrial();
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          status: const Value('pending'),
        ),
      );
      final event = await repo.getSeedingEventForTrial(trialId);

      expect(
        () => repo.markSeedingCompleted(
          id: event!.id,
          completedAt: DateTime.now().add(const Duration(days: 5)),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });
  });

  group('getSeedingEventForTrial', () {
    test('returns null when no seeding event exists', () async {
      final trialId = await createTrial();
      final event = await repo.getSeedingEventForTrial(trialId);
      expect(event, isNull);
    });
  });
}
