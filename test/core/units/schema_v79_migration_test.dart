import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('Schema v79 migration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'trial_application_events gains growth_stage_bbch_at_application column',
      () async {
        final cols = await _columnNames(db, 'trial_application_events');
        expect(cols, contains('growth_stage_bbch_at_application'));
      },
    );

    test(
      'treatment_components gains pesticide_category column',
      () async {
        final cols = await _columnNames(db, 'treatment_components');
        expect(cols, contains('pesticide_category'));
      },
    );

    test(
      'existing trial_application_events rows survive migration with null bbch',
      () async {
        final trialId = await db
            .into(db.trials)
            .insert(TrialsCompanion.insert(name: 'Legacy trial'));
        await db.into(db.trialApplicationEvents).insert(
              TrialApplicationEventsCompanion.insert(
                trialId: trialId,
                applicationDate: DateTime(2025, 4, 1),
              ),
            );
        final rows = await db.customSelect(
          'SELECT growth_stage_bbch_at_application FROM trial_application_events',
        ).get();
        expect(rows.length, 1);
        expect(rows.first.data['growth_stage_bbch_at_application'], isNull);
      },
    );

    test(
      'existing treatment_components rows survive migration with null pesticide_category',
      () async {
        final trialId = await db
            .into(db.trials)
            .insert(TrialsCompanion.insert(name: 'Legacy trial'));
        final treatmentId = await db.into(db.treatments).insert(
              TreatmentsCompanion.insert(
                trialId: trialId,
                code: 'T1',
                name: 'Treatment 1',
              ),
            );
        await db.into(db.treatmentComponents).insert(
              TreatmentComponentsCompanion.insert(
                treatmentId: treatmentId,
                trialId: trialId,
                productName: 'ProductA',
              ),
            );
        final rows = await db.customSelect(
          'SELECT pesticide_category FROM treatment_components',
        ).get();
        expect(rows.length, 1);
        expect(rows.first.data['pesticide_category'], isNull);
      },
    );
  });
}
