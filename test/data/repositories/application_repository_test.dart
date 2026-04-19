import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/field_operation_date_rules.dart';
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

  group('markApplicationApplied', () {
    test('sets status to applied', () async {
      final trialId = await createTrial();
      final id = await repo.createApplication(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: today(),
          status: const Value('planned'),
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
          status: const Value('planned'),
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
  });
}
