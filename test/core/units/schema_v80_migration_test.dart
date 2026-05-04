import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables: [Variable.withString(table)],
  ).get();
  return rows.isNotEmpty;
}

void main() {
  group('Schema v80 migration — ctq_factor_acknowledgments', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('ctq_factor_acknowledgments table exists', () async {
      expect(await _tableExists(db, 'ctq_factor_acknowledgments'), isTrue);
    });

    test('ctq_factor_acknowledgments has required columns', () async {
      final cols = await _columnNames(db, 'ctq_factor_acknowledgments');
      expect(cols, containsAll([
        'id',
        'trial_id',
        'factor_key',
        'acknowledged_at',
        'acknowledged_by_user_id',
        'reason',
        'factor_status_at_acknowledgment',
        'purpose_version_id',
        'created_at',
      ]));
    });

    test('reason NOT NULL — insert without reason throws', () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'T'));
      expect(
        () => db.customStatement(
          'INSERT INTO ctq_factor_acknowledgments '
          '(trial_id, factor_key, acknowledged_at, '
          'factor_status_at_acknowledgment, created_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [trialId, 'plot_completeness', 1000, 'review_needed', 1000],
        ),
        throwsA(anything),
      );
    });

    test('valid insert round-trips all fields', () async {
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'T'));
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.ctqFactorAcknowledgments).insert(
            CtqFactorAcknowledgmentsCompanion.insert(
              trialId: trialId,
              factorKey: 'application_timing',
              acknowledgedAt: now,
              reason: 'Protocol constraint documented in study plan.',
              factorStatusAtAcknowledgment: 'review_needed',
            ),
          );
      final rows = await db.select(db.ctqFactorAcknowledgments).get();
      expect(rows.length, 1);
      expect(rows[0].factorKey, 'application_timing');
      expect(rows[0].reason, 'Protocol constraint documented in study plan.');
      expect(rows[0].factorStatusAtAcknowledgment, 'review_needed');
    });

    test('multiple acknowledgments for same trial+factor are allowed', () async {
      // No unique constraint — history accumulates; latest selected by query.
      final trialId = await db
          .into(db.trials)
          .insert(TrialsCompanion.insert(name: 'T'));
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 3; i++) {
        await db.into(db.ctqFactorAcknowledgments).insert(
              CtqFactorAcknowledgmentsCompanion.insert(
                trialId: trialId,
                factorKey: 'plot_completeness',
                acknowledgedAt: now + i,
                reason: 'Reason $i.',
                factorStatusAtAcknowledgment: 'review_needed',
              ),
            );
      }
      final rows = await (db.select(db.ctqFactorAcknowledgments)
            ..where((a) => a.trialId.equals(trialId)))
          .get();
      expect(rows.length, 3);
    });
  });
}
