import 'dart:convert';

import 'package:arm_field_companion/core/application_state.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/field_operation_date_rules.dart';
import 'package:arm_field_companion/core/protocol_edit_blocked_exception.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart'
    show ApplicationProductRepository, ApplicationProductSaveRow;
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ApplicationRepository repo;
  late ApplicationProductRepository productRepo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ApplicationRepository(db);
    productRepo = ApplicationProductRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTrial() async {
    return trialRepo.createTrial(
      name: 'Trial ${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  DateTime today() => DateTime.now();

  group('createApplication', () {
    test('inserts application event and writes audit', () async {
      final trialId = await createTrial();

      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
        performedBy: 'tester',
      );
      expect(id, isNotEmpty);

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events.length, 1);
      expect(events[0].id, id);
      expect(events[0].status, 'planned');

      final audits = await (db.select(db.auditEvents)
            ..where(
                (a) => a.eventType.equals('TRIAL_APPLICATION_EVENT_CREATED')))
          .get();
      expect(audits.length, 1);
    });

    test('rejects future application date', () async {
      final trialId = await createTrial();
      final future = DateTime.now().add(const Duration(days: 5));

      expect(
        () => repo.createApplication(
          TrialApplicationEventsCompanion.insert(
            trialId: trialId,
            applicationDate: future,
            status: const Value('planned'),
          ),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });

    test('rejects missing trial id and date', () async {
      expect(
        () => repo.createApplication(
          const TrialApplicationEventsCompanion(),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });
  });

  group('updateApplication', () {
    test('updates existing event', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
          applicationMethod: const Value('spray'),
        ),
      );

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          applicationMethod: Value('drench'),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].applicationMethod, 'drench');
    });
  });

  group('updateApplication — confirmed lock', () {
    Future<String> createAppliedApp(int trialId) async {
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          applicationMethod: const Value('spray'),
          operatorName: const Value('original operator'),
          notes: const Value('original notes'),
        ),
      );
      await repo.markApplicationApplied(id: id, appliedAt: DateTime.now());
      return id;
    }

    test('rejects structural fields on confirmed application', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        () => repo.updateApplication(
          id,
          TrialApplicationEventsCompanion(
            applicationDate: Value(yesterday),
            applicationMethod: const Value('drench'),
            rate: const Value(999.0),
            productName: const Value('ShouldNotChange'),
          ),
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].applicationMethod, 'spray',
          reason: 'applicationMethod must not change after rejection');
      expect(events[0].rate, isNull,
          reason: 'rate must not change after rejection');
      expect(events[0].productName, isNull,
          reason: 'productName must not change after rejection');
      expect(events[0].applicationDate.day, today().day,
          reason: 'applicationDate must not change after rejection');
    });

    test('does update editable fields on confirmed application', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          operatorName: Value('new operator'),
          notes: Value('updated notes'),
          windSpeed: Value(4.5),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].operatorName, 'new operator');
      expect(events[0].notes, 'updated notes');
      expect(events[0].windSpeed, closeTo(4.5, 0.001));
    });

    test('unconfirmed application updates all fields normally', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
          applicationMethod: const Value('spray'),
        ),
      );

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          applicationMethod: Value('drench'),
          rate: Value(100.0),
          productName: Value('Herbicide X'),
          operatorName: Value('tester'),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].applicationMethod, 'drench');
      expect(events[0].rate, closeTo(100.0, 0.001));
      expect(events[0].productName, 'Herbicide X');
      expect(events[0].operatorName, 'tester');
    });

    test('writes APPLICATION_EVENT_UPDATED audit when editable field changes',
        () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          operatorName: Value('audited operator'),
        ),
        performedBy: 'tester',
      );

      final audits = await (db.select(db.auditEvents)
            ..where(
                (a) => a.eventType.equals('APPLICATION_EVENT_UPDATED')))
          .get();
      expect(audits.length, 1);
      expect(audits[0].performedBy, 'tester');
    });

    test('no audit event written when only structural fields are passed',
        () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      // Structural-only call must throw and write no annotation audit.
      expect(
        () => repo.updateApplication(
          id,
          TrialApplicationEventsCompanion(
            productName: const Value('ShouldNotChange'),
            applicationDate:
                Value(DateTime.now().subtract(const Duration(days: 1))),
          ),
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) => a.eventType.equals('APPLICATION_EVENT_UPDATED')))
          .get();
      expect(audits, isEmpty);
    });
  });

  group('markApplicationApplied', () {
    test('sets status to applied from pending', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      await repo.markApplicationApplied(
        id: id,
        appliedAt: DateTime.now(),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].status, 'applied');
      expect(events[0].appliedAt, isNotNull);
    });

    test('rejects future applied time', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      expect(
        () => repo.markApplicationApplied(
          id: id,
          appliedAt: DateTime.now().add(const Duration(days: 5)),
        ),
        throwsA(isA<OperationalDateRuleException>()),
      );
    });
  });

  group('application status state machine', () {
    Future<String> createPendingApp(int trialId) {
      return repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );
    }

    Future<String> createAppliedApp(int trialId) async {
      final id = await createPendingApp(trialId);
      await repo.markApplicationApplied(id: id, appliedAt: DateTime.now());
      return id;
    }

    // ── Valid transitions ──

    test('pending → applied succeeds', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);

      await repo.markApplicationApplied(id: id, appliedAt: DateTime.now());

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].status, kAppStatusApplied);
    });

    test('applied → closed succeeds', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.closeApplication(id);

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].status, kAppStatusClosed);
    });

    test('pending → cancelled succeeds', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);

      await repo.cancelApplication(id);

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].status, kAppStatusCancelled);
    });

    test('applied → cancelled succeeds', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.cancelApplication(id);

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].status, kAppStatusCancelled);
    });

    // ── Invalid transitions ──

    test('pending → closed throws', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);

      expect(
        () => repo.closeApplication(id),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    test('closed → applied throws', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);
      await repo.closeApplication(id);

      expect(
        () => repo.markApplicationApplied(id: id, appliedAt: DateTime.now()),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    test('closed → cancelled throws', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);
      await repo.closeApplication(id);

      expect(
        () => repo.cancelApplication(id),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    test('cancelled → applied throws', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);
      await repo.cancelApplication(id);

      expect(
        () => repo.markApplicationApplied(id: id, appliedAt: DateTime.now()),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    test('cancelled → closed throws', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);
      await repo.cancelApplication(id);

      expect(
        () => repo.closeApplication(id),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    test('applied → applied (duplicate) throws', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      expect(
        () => repo.markApplicationApplied(id: id, appliedAt: DateTime.now()),
        throwsA(isA<InvalidApplicationTransitionException>()),
      );
    });

    // ── Audit trail ──

    test('cancelApplication writes audit event', () async {
      final trialId = await createTrial();
      final id = await createPendingApp(trialId);

      await repo.cancelApplication(id, performedBy: 'tester');

      final audits = await (db.select(db.auditEvents)
            ..where((a) => a.eventType.equals('TRIAL_APPLICATION_CANCELLED')))
          .get();
      expect(audits.length, 1);
      expect(audits[0].performedBy, 'tester');
    });
  });

  group('deleteApplication', () {
    test('removes event and its products', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
      );

      // Add products
      await productRepo.saveProductsForEvent(id, [
        const ApplicationProductSaveRow(
            productName: 'Fungicide X', rate: 250.0, rateUnit: 'mL/ha'),
      ]);

      await repo.deleteApplication(id);

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events, isEmpty);

      final products = await productRepo.getProductsForEvent(id);
      expect(products, isEmpty);
    });
  });

  group('ApplicationProductRepository', () {
    test('saves and retrieves products for event', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
      );

      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
            productName: 'Product A', rate: 100.0, rateUnit: 'g/ha'),
        const ApplicationProductSaveRow(
            productName: 'Product B', rate: null, rateUnit: null),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products.length, 2);
      expect(products[0].productName, 'Product A');
      expect(products[0].rate, 100.0);
      expect(products[0].sortOrder, 0);
      expect(products[1].productName, 'Product B');
      expect(products[1].sortOrder, 1);
    });

    test('replaces all products on second save', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
      );

      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
            productName: 'Old', rate: null, rateUnit: null),
      ]);
      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
            productName: 'New A', rate: 50.0, rateUnit: 'mL/ha'),
        const ApplicationProductSaveRow(
            productName: 'New B', rate: 75.0, rateUnit: 'g/ha'),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products.length, 2);
      expect(products[0].productName, 'New A');
      expect(products[1].productName, 'New B');
    });

    test('persists planned protocol fields for deviation tracking', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
      );

      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Herbicide X',
          rate: 1.02,
          rateUnit: 'L/ha',
          plannedProduct: 'Herbicide X',
          plannedRate: 1.0,
          plannedRateUnit: 'L/ha',
        ),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products.length, 1);
      expect(products[0].plannedProduct, 'Herbicide X');
      expect(products[0].plannedRate, 1.0);
      expect(products[0].plannedRateUnit, 'L/ha');
      expect(products[0].rate, closeTo(1.02, 0.0001));
    });

    test('deviationFlag true when rate exceeds 5% tolerance', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      // 10% over planned → flag true
      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Product A',
          rate: 1.1,
          rateUnit: 'L/ha',
          plannedRate: 1.0,
        ),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products[0].deviationFlag, isTrue);
    });

    test('deviationFlag false when rate within 5% tolerance', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      // 2% over planned → within tolerance → flag false
      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Product A',
          rate: 1.02,
          rateUnit: 'L/ha',
          plannedRate: 1.0,
        ),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products[0].deviationFlag, isFalse);
    });

    test('deviationFlag updates when rate is corrected', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      // First save: 20% over → flagged
      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Product A',
          rate: 1.2,
          rateUnit: 'L/ha',
          plannedRate: 1.0,
        ),
      ]);
      var products = await productRepo.getProductsForEvent(eventId);
      expect(products[0].deviationFlag, isTrue);

      // Second save: corrected to match planned → no longer flagged
      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Product A',
          rate: 1.0,
          rateUnit: 'L/ha',
          plannedRate: 1.0,
        ),
      ]);
      products = await productRepo.getProductsForEvent(eventId);
      expect(products[0].deviationFlag, isFalse);
    });

    test('deviationFlag false when no planned rate', () async {
      final trialId = await createTrial();
      final eventId = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );

      await productRepo.saveProductsForEvent(eventId, [
        const ApplicationProductSaveRow(
          productName: 'Product A',
          rate: 5.0,
          rateUnit: 'L/ha',
          // no plannedRate
        ),
      ]);

      final products = await productRepo.getProductsForEvent(eventId);
      expect(products[0].deviationFlag, isFalse);
    });
  });

  group('updateApplicationWeather', () {
    Future<String> createAppliedApp(int trialId) async {
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );
      await repo.markApplicationApplied(id: id, appliedAt: today());
      return id;
    }

    test('writes all weather fields when all null', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationWeather(
        applicationId: id,
        temperatureC: 21.5,
        humidityPct: 60.0,
        windSpeedKmh: 15.0,
        windDirection: 'NW',
        cloudCoverPct: 30.0,
        precipitation: 'Light rain',
        precipitationMm: 1.2,
        soilMoisture: 'Moist',
        soilTemperature: 18.0,
      );

      final row = (await repo.getApplicationsForTrial(trialId)).first;
      expect(row.temperature, 21.5);
      expect(row.humidity, 60.0);
      expect(row.windSpeed, 15.0);
      expect(row.windDirection, 'NW');
      expect(row.cloudCoverPct, 30.0);
      expect(row.precipitation, 'Light rain');
      expect(row.precipitationMm, 1.2);
      expect(row.soilMoisture, 'Moist');
      expect(row.soilTemperature, 18.0);
      expect(row.conditionsRecordedAt, isNotNull);
    });

    test('does NOT overwrite when any weather field already populated', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      // Write once
      await repo.updateApplicationWeather(
        applicationId: id,
        temperatureC: 20.0,
        humidityPct: null,
        windSpeedKmh: null,
        windDirection: null,
        cloudCoverPct: null,
        precipitation: null,
        precipitationMm: null,
      );

      // Attempt overwrite — should be a no-op
      await repo.updateApplicationWeather(
        applicationId: id,
        temperatureC: 99.9,
        humidityPct: 99.9,
        windSpeedKmh: 99.9,
        windDirection: 'S',
        cloudCoverPct: 99.9,
        precipitation: 'Heavy rain',
        precipitationMm: 99.9,
      );

      final row = (await repo.getApplicationsForTrial(trialId)).first;
      expect(row.temperature, 20.0);
      expect(row.humidity, isNull);
    });

    test('writes APPLICATION_WEATHER_CAPTURED audit event', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationWeather(
        applicationId: id,
        temperatureC: 18.0,
        humidityPct: 55.0,
        windSpeedKmh: 10.0,
        windDirection: null,
        cloudCoverPct: null,
        precipitation: null,
        precipitationMm: null,
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('APPLICATION_WEATHER_CAPTURED')))
          .get();
      expect(audits.length, 1);
    });
  });

  group('updateApplicationGps', () {
    Future<String> createAppliedApp(int trialId) async {
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
        ),
      );
      await repo.markApplicationApplied(id: id, appliedAt: today());
      return id;
    }

    test('writes GPS fields when capturedLatitude is null', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationGps(
        applicationId: id,
        latitude: 51.5074,
        longitude: -0.1278,
      );

      final row = (await repo.getApplicationsForTrial(trialId)).first;
      expect(row.capturedLatitude, closeTo(51.5074, 0.0001));
      expect(row.capturedLongitude, closeTo(-0.1278, 0.0001));
      expect(row.locationCapturedAt, isNotNull);
    });

    test('does NOT overwrite when capturedLatitude already set', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationGps(
        applicationId: id,
        latitude: 51.5074,
        longitude: -0.1278,
      );

      // Attempt overwrite — should be no-op
      await repo.updateApplicationGps(
        applicationId: id,
        latitude: 0.0,
        longitude: 0.0,
      );

      final row = (await repo.getApplicationsForTrial(trialId)).first;
      expect(row.capturedLatitude, closeTo(51.5074, 0.0001));
    });

    test('writes APPLICATION_GPS_CAPTURED audit event', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationGps(
        applicationId: id,
        latitude: 40.7128,
        longitude: -74.0060,
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) =>
                a.trialId.equals(trialId) &
                a.eventType.equals('APPLICATION_GPS_CAPTURED')))
          .get();
      expect(audits.length, 1);
    });
  });

  // ─── Graduated annotation lock (ACL-A) ────────────────────────────────────

  group('updateApplication — graduated lock', () {
    Future<String> createAppliedApp(int trialId) async {
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          applicationMethod: const Value('spray'),
          operatorName: const Value('original'),
        ),
      );
      await repo.markApplicationApplied(id: id, appliedAt: DateTime.now());
      return id;
    }

    test(
        'ACL-A1: updateApplicationAnnotationsOnly succeeds on confirmed event '
        '(growthStageBbchAtApplication)', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationAnnotationsOnly(
        id,
        const TrialApplicationEventsCompanion(
          growthStageBbchAtApplication: Value(32),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].growthStageBbchAtApplication, 32);
    });

    test('ACL-A2: updateApplicationAnnotationsOnly rejects applicationDate',
        () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      expect(
        () => repo.updateApplicationAnnotationsOnly(
          id,
          TrialApplicationEventsCompanion(
            applicationDate:
                Value(DateTime.now().subtract(const Duration(days: 1))),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ACL-A3: updateApplicationAnnotationsOnly rejects treatmentId',
        () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      expect(
        () => repo.updateApplicationAnnotationsOnly(
          id,
          const TrialApplicationEventsCompanion(treatmentId: Value(99)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'ACL-A4: updateApplication confirmed + only annotation fields → '
        'succeeds via delegation', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          operatorName: Value('updated operator'),
          growthStageCode: Value('BBCH 32'),
          growthStageBbchAtApplication: Value(32),
          windSpeed: Value(8.0),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].operatorName, 'updated operator');
      expect(events[0].growthStageCode, 'BBCH 32');
      expect(events[0].growthStageBbchAtApplication, 32);
      expect(events[0].windSpeed, closeTo(8.0, 0.001));
    });

    test('ACL-A5: updateApplication confirmed + applicationDate → throws',
        () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      expect(
        () => repo.updateApplication(
          id,
          TrialApplicationEventsCompanion(
            applicationDate:
                Value(DateTime.now().subtract(const Duration(days: 1))),
          ),
        ),
        throwsA(isA<ProtocolEditBlockedException>()),
      );
    });

    test(
        'ACL-A6: updateApplication pending + structural change → updates '
        'normally', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
        ),
      );

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          rate: Value(150.0),
          productName: Value('Herbicide Z'),
          applicationMethod: Value('drench'),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].rate, closeTo(150.0, 0.001));
      expect(events[0].productName, 'Herbicide Z');
      expect(events[0].applicationMethod, 'drench');
    });

    test(
        'ACL-A7: growthStageBbchAtApplication can be set via updateApplication '
        'on confirmed event', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplication(
        id,
        const TrialApplicationEventsCompanion(
          growthStageBbchAtApplication: Value(45),
        ),
      );

      final events = await repo.getApplicationsForTrial(trialId);
      expect(events[0].growthStageBbchAtApplication, 45);
    });

    test('ACL-A8: audit metadata records annotation_only: true', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      await repo.updateApplicationAnnotationsOnly(
        id,
        const TrialApplicationEventsCompanion(
          growthStageBbchAtApplication: Value(32),
        ),
        performedBy: 'tester',
      );

      final audits = await (db.select(db.auditEvents)
            ..where((a) => a.eventType.equals('APPLICATION_EVENT_UPDATED')))
          .get();
      expect(audits.length, 1);
      final meta = jsonDecode(audits[0].metadata!) as Map<String, dynamic>;
      expect(meta['annotation_only'], true);
      expect(
        (meta['changed_fields'] as List).cast<String>(),
        contains('growthStageBbchAtApplication'),
      );
    });

    test(
        'ACL-A9: updateApplicationAnnotationsOnly does not alter structural '
        'fields', () async {
      final trialId = await createTrial();
      final id = await createAppliedApp(trialId);

      // Snapshot before.
      final before = (await repo.getApplicationsForTrial(trialId)).first;

      await repo.updateApplicationAnnotationsOnly(
        id,
        const TrialApplicationEventsCompanion(
          windSpeed: Value(12.0),
          notes: Value('post-applied note'),
        ),
      );

      final after = (await repo.getApplicationsForTrial(trialId)).first;
      expect(after.applicationDate, before.applicationDate);
      expect(after.treatmentId, before.treatmentId);
      expect(after.productName, before.productName);
      expect(after.rate, before.rate);
      expect(after.rateUnit, before.rateUnit);
      expect(after.appliedAt, before.appliedAt);
      expect(after.status, before.status);
      // Annotation fields did change.
      expect(after.windSpeed, closeTo(12.0, 0.001));
      expect(after.notes, 'post-applied note');
    });

    test(
      'ACL-A10: confirmed + full structural mirror .present + only BBCH differs → '
      'delegates, succeeds',
      () async {
        final trialId = await createTrial();
        final id = await createAppliedApp(trialId);
        final row = (await repo.getApplicationsForTrial(trialId)).first;

        await repo.updateApplication(
          id,
          TrialApplicationEventsCompanion(
            applicationDate: Value(row.applicationDate),
            applicationTime: Value(row.applicationTime),
            treatmentId: Value(row.treatmentId),
            productName: Value(row.productName),
            rate: Value(row.rate),
            rateUnit: Value(row.rateUnit),
            plotsTreated: Value(row.plotsTreated),
            status: Value(row.status),
            appliedAt: Value(row.appliedAt),
            startedAt: Value(row.startedAt),
            completedAt: Value(row.completedAt),
            closedAt: Value(row.closedAt),
            sessionName: Value(row.sessionName),
            totalProductMixed: Value(row.totalProductMixed),
            totalAreaSprayedHa: Value(row.totalAreaSprayedHa),
            capturedLatitude: Value(row.capturedLatitude),
            capturedLongitude: Value(row.capturedLongitude),
            locationCapturedAt: Value(row.locationCapturedAt),
            growthStageBbchAtApplication: const Value(71),
          ),
        );

        final after = (await repo.getApplicationsForTrial(trialId)).first;
        expect(after.growthStageBbchAtApplication, 71);
        expect(after.applicationDate, row.applicationDate);
        expect(after.productName, row.productName);
      },
    );

    test(
      'ACL-A11: confirmed + applicationDate.present unchanged + BBCH change → succeeds',
      () async {
        final trialId = await createTrial();
        final id = await createAppliedApp(trialId);
        final row = (await repo.getApplicationsForTrial(trialId)).first;

        await repo.updateApplication(
          id,
          TrialApplicationEventsCompanion(
            applicationDate: Value(row.applicationDate),
            growthStageBbchAtApplication: const Value(55),
          ),
        );

        final after = (await repo.getApplicationsForTrial(trialId)).first;
        expect(after.growthStageBbchAtApplication, 55);
      },
    );

    test(
      'ACL-A12: updateApplicationAnnotationsOnly rejects structural .present even '
      'when value unchanged',
      () async {
        final trialId = await createTrial();
        final id = await createAppliedApp(trialId);
        final row = (await repo.getApplicationsForTrial(trialId)).first;

        expect(
          () => repo.updateApplicationAnnotationsOnly(
            id,
            TrialApplicationEventsCompanion(
              applicationDate: Value(row.applicationDate),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });
}
