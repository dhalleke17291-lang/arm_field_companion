import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/application_plot_assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ApplicationPlotAssignmentRepository repo;
  late ApplicationRepository appRepo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ApplicationPlotAssignmentRepository(db);
    appRepo = ApplicationRepository(db);
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

  Future<String> createApp(int trialId) async {
    return appRepo.createApplication(
      TrialApplicationEventsCompanion.insert(
        trialId: trialId,
        applicationDate: DateTime.now(),
      ),
    );
  }

  group('ApplicationPlotAssignmentRepository', () {
    test('saveForEvent writes junction rows and getForEvent retrieves them',
        () async {
      final trialId = await createTrial();
      final eventId = await createApp(trialId);

      await repo.saveForEvent(eventId, [
        (label: '101', plotId: null),
        (label: '102', plotId: null),
        (label: '201', plotId: null),
      ]);

      final assignments = await repo.getForEvent(eventId);
      expect(assignments.length, 3);
      expect(assignments.map((a) => a.plotLabel).toList(),
          containsAll(['101', '102', '201']));
    });

    test('saveForEvent replaces all rows on second call', () async {
      final trialId = await createTrial();
      final eventId = await createApp(trialId);

      await repo.saveForEvent(eventId, [
        (label: '101', plotId: null),
        (label: '102', plotId: null),
      ]);

      await repo.saveForEvent(eventId, [
        (label: '301', plotId: null),
      ]);

      final assignments = await repo.getForEvent(eventId);
      expect(assignments.length, 1);
      expect(assignments[0].plotLabel, '301');
    });

    test('saveForEvent with empty list clears all rows', () async {
      final trialId = await createTrial();
      final eventId = await createApp(trialId);

      await repo.saveForEvent(eventId, [
        (label: '101', plotId: null),
      ]);

      await repo.saveForEvent(eventId, []);

      final assignments = await repo.getForEvent(eventId);
      expect(assignments, isEmpty);
    });

    test('saveForEvent stores plotId when resolved', () async {
      final trialId = await createTrial();
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(trialId: trialId, plotId: '101'),
          );
      final eventId = await createApp(trialId);

      await repo.saveForEvent(eventId, [
        (label: '101', plotId: plotPk),
      ]);

      final assignments = await repo.getForEvent(eventId);
      expect(assignments.length, 1);
      expect(assignments[0].plotLabel, '101');
      expect(assignments[0].plotId, plotPk);
    });

    test('saveForEvent stores null plotId when unresolved', () async {
      final trialId = await createTrial();
      final eventId = await createApp(trialId);

      await repo.saveForEvent(eventId, [
        (label: 'UnknownPlot', plotId: null),
      ]);

      final assignments = await repo.getForEvent(eventId);
      expect(assignments.length, 1);
      expect(assignments[0].plotLabel, 'UnknownPlot');
      expect(assignments[0].plotId, isNull);
    });
  });

  group('migration v55 — plotsTreated TEXT to junction rows', () {
    test('in-memory DB creates junction table', () async {
      // Verify the table exists by querying it
      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='application_plot_assignments'",
      ).get();
      expect(result.length, 1);
    });
  });

  group('migration v55 — rate TEXT to REAL', () {
    test('rate column is REAL type in treatment_components', () async {
      final trialId = await createTrial();
      final trtId = await db.into(db.treatments).insert(
            TreatmentsCompanion.insert(
                trialId: trialId, code: '1', name: 'T1'),
          );

      // Insert with a double rate
      await db.into(db.treatmentComponents).insert(
            TreatmentComponentsCompanion.insert(
              treatmentId: trtId,
              trialId: trialId,
              productName: 'Product A',
              rate: const Value(250.0),
            ),
          );

      final comps = await (db.select(db.treatmentComponents)
            ..where((c) => c.treatmentId.equals(trtId)))
          .get();
      expect(comps.length, 1);
      expect(comps[0].rate, 250.0);
    });
  });
}
