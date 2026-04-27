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

  group('upsertSeedingEvent — completed lock', () {
    Future<SeedingEvent> createCompletedEvent(int trialId) async {
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          variety: const Value('Barley Prime'),
          seedLotNumber: const Value('LOT-001'),
          operatorName: const Value('original operator'),
          notes: const Value('original notes'),
        ),
      );
      final event = await repo.getSeedingEventForTrial(trialId);
      await repo.markSeedingCompleted(
        id: event!.id,
        completedAt: DateTime.now(),
      );
      return (await repo.getSeedingEventForTrial(trialId))!;
    }

    test('execution fields not updated after seeding completed', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          variety: const Value('Should not change'),
          seedLotNumber: const Value('LOT-CHANGED'),
          seedingRate: const Value(999.0),
          seedingDepth: const Value(99.0),
          rowSpacing: const Value(88.0),
          plantingMethod: const Value('Broadcast'),
          seedTreatment: const Value('Changed treatment'),
          germinationPct: const Value(99.0),
        ),
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.variety, 'Barley Prime');
      expect(after.seedLotNumber, 'LOT-001');
      expect(after.seedingRate, isNull);
      expect(after.seedingDepth, isNull);
      expect(after.rowSpacing, isNull);
      expect(after.plantingMethod, isNull);
      expect(after.seedTreatment, isNull);
      expect(after.germinationPct, isNull);
    });

    test('editable fields ARE updated after seeding completed', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          operatorName: const Value('updated operator'),
          notes: const Value('updated notes'),
          equipmentUsed: const Value('Updated Planter'),
          temperatureC: const Value(22.5),
          humidityPct: const Value(65.0),
          windSpeedKmh: const Value(12.0),
          windDirection: const Value('NW'),
        ),
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.operatorName, 'updated operator');
      expect(after.notes, 'updated notes');
      expect(after.equipmentUsed, 'Updated Planter');
      expect(after.temperatureC, 22.5);
      expect(after.humidityPct, 65.0);
      expect(after.windSpeedKmh, 12.0);
      expect(after.windDirection, 'NW');
    });

    test('emergenceDate and emergencePct are updatable after completion', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          emergenceDate: Value(today()),
          emergencePct: const Value(78.0),
        ),
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.emergenceDate, isNotNull);
      expect(after.emergencePct, 78.0);
    });

    test('unconfirmed event updates all fields', () async {
      final trialId = await createTrial();
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          variety: const Value('Original'),
        ),
      );

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
          variety: const Value('Updated'),
          seedLotNumber: const Value('NEW-LOT'),
          seedingDepth: const Value(3.5),
        ),
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.variety, 'Updated');
      expect(after.seedLotNumber, 'NEW-LOT');
      expect(after.seedingDepth, 3.5);
    });

    test('audit event SEEDING_EVENT_UPDATED written when editable field changes', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          operatorName: const Value('new operator'),
        ),
        performedBy: 'tester',
        performedByUserId: 1,
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('SEEDING_EVENT_UPDATED')))
          .get();
      expect(audits.length, 1);
    });

    test('no audit event written when no editable fields change', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          variety: const Value('Should not trigger audit — execution field'),
        ),
        performedBy: 'tester',
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('SEEDING_EVENT_UPDATED')))
          .get();
      expect(audits.isEmpty, isTrue);
    });

    test('invalid emergence date rejected even on completed event', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      final pastBeforeSeeding = completed.seedingDate.subtract(const Duration(days: 1));

      expect(
        () => repo.upsertSeedingEvent(
          SeedingEventsCompanion(
            id: Value(completed.id),
            trialId: Value(trialId),
            seedingDate: Value(today()),
            emergenceDate: Value(pastBeforeSeeding),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('GPS fields not updated on completed event', () async {
      final trialId = await createTrial();
      final completed = await createCompletedEvent(trialId);

      await repo.upsertSeedingEvent(
        SeedingEventsCompanion(
          id: Value(completed.id),
          trialId: Value(trialId),
          seedingDate: Value(today()),
          capturedLatitude: const Value(51.5),
          capturedLongitude: const Value(-0.12),
        ),
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.capturedLatitude, isNull);
      expect(after.capturedLongitude, isNull);
    });
  });

  group('updateSeedingWeather', () {
    Future<SeedingEvent> createCompletedSeedingEvent(int trialId) async {
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
        ),
      );
      final event = await repo.getSeedingEventForTrial(trialId);
      await repo.markSeedingCompleted(
        id: event!.id,
        completedAt: DateTime.now(),
      );
      return (await repo.getSeedingEventForTrial(trialId))!;
    }

    test('writes all weather fields when temperatureC is null', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingWeather(
        seedingEventId: completed.id,
        temperatureC: 18.5,
        humidityPct: 65.0,
        windSpeedKmh: 12.0,
        windDirection: 'NW',
        cloudCoverPct: 40.0,
        precipitation: 'Light rain',
        precipitationMm: 1.5,
        soilMoisture: 'Moist',
        soilTemperature: 15.0,
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.temperatureC, 18.5);
      expect(after.humidityPct, 65.0);
      expect(after.windSpeedKmh, 12.0);
      expect(after.windDirection, 'NW');
      expect(after.cloudCoverPct, 40.0);
      expect(after.precipitation, 'Light rain');
      expect(after.precipitationMm, 1.5);
      expect(after.soilMoisture, 'Moist');
      expect(after.soilTemperature, 15.0);
      expect(after.conditionsRecordedAt, isNotNull);
    });

    test('does NOT overwrite when temperatureC already set (lock)', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingWeather(
        seedingEventId: completed.id,
        temperatureC: 20.0,
        humidityPct: null,
        windSpeedKmh: null,
        windDirection: null,
        cloudCoverPct: null,
        precipitation: null,
        precipitationMm: null,
        soilMoisture: null,
        soilTemperature: null,
      );

      await repo.updateSeedingWeather(
        seedingEventId: completed.id,
        temperatureC: 99.9,
        humidityPct: 99.9,
        windSpeedKmh: 99.9,
        windDirection: 'S',
        cloudCoverPct: 99.9,
        precipitation: 'Heavy rain',
        precipitationMm: 99.9,
        soilMoisture: 'Wet',
        soilTemperature: 99.9,
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.temperatureC, 20.0);
      expect(after.humidityPct, isNull);
    });

    test('writes SEEDING_WEATHER_CAPTURED audit event', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingWeather(
        seedingEventId: completed.id,
        temperatureC: 22.0,
        humidityPct: 55.0,
        windSpeedKmh: 8.0,
        windDirection: null,
        cloudCoverPct: null,
        precipitation: null,
        precipitationMm: null,
        soilMoisture: null,
        soilTemperature: null,
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('SEEDING_WEATHER_CAPTURED')))
          .get();
      expect(audits.length, 1);
    });
  });

  group('updateSeedingGps', () {
    Future<SeedingEvent> createCompletedSeedingEvent(int trialId) async {
      await repo.upsertSeedingEvent(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: today(),
        ),
      );
      final event = await repo.getSeedingEventForTrial(trialId);
      await repo.markSeedingCompleted(
        id: event!.id,
        completedAt: DateTime.now(),
      );
      return (await repo.getSeedingEventForTrial(trialId))!;
    }

    test('writes GPS fields when capturedLatitude is null', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingGps(
        seedingEventId: completed.id,
        latitude: 51.5074,
        longitude: -0.1278,
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.capturedLatitude, closeTo(51.5074, 0.0001));
      expect(after.capturedLongitude, closeTo(-0.1278, 0.0001));
      expect(after.locationCapturedAt, isNotNull);
    });

    test('does NOT overwrite when capturedLatitude already set (lock)', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingGps(
        seedingEventId: completed.id,
        latitude: 51.5074,
        longitude: -0.1278,
      );

      await repo.updateSeedingGps(
        seedingEventId: completed.id,
        latitude: 0.0,
        longitude: 0.0,
      );

      final after = await repo.getSeedingEventForTrial(trialId);
      expect(after!.capturedLatitude, closeTo(51.5074, 0.0001));
    });

    test('writes SEEDING_GPS_CAPTURED audit event', () async {
      final trialId = await createTrial();
      final completed = await createCompletedSeedingEvent(trialId);

      await repo.updateSeedingGps(
        seedingEventId: completed.id,
        latitude: 40.7128,
        longitude: -74.0060,
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('SEEDING_GPS_CAPTURED')))
          .get();
      expect(audits.length, 1);
    });
  });
}
