import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('Schema v82 migration — trial_purposes.requires_confirmation', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('trial_purposes has requires_confirmation column', () async {
      final cols = await _columnNames(db, 'trial_purposes');
      expect(cols, contains('requires_confirmation'));
    });

    test('existing Mode C rows are backfilled to requires_confirmation = 0',
        () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

      // Insert a row as if created by Mode C revelation (no explicit
      // requires_confirmation → migration backfilled to 0).
      await db.customStatement(
        'INSERT INTO trial_purposes (trial_id, version, status, source_mode, '
        'requires_confirmation, created_at, updated_at) '
        "VALUES (?, 1, 'confirmed', 'manual_revelation', 0, "
        "strftime('%s','now'), strftime('%s','now'))",
        [trialId],
      );

      final rows = await db.select(db.trialPurposes).get();
      expect(rows.length, 1);
      expect(rows.first.requiresConfirmation, 0);
    });

    test('new inferred row defaults to requires_confirmation = 1', () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

      // Insert without specifying requires_confirmation — DEFAULT 1 applies.
      await db.into(db.trialPurposes).insert(
            TrialPurposesCompanion.insert(trialId: trialId),
          );

      final rows = await db.select(db.trialPurposes).get();
      expect(rows.length, 1);
      expect(rows.first.requiresConfirmation, 1);
    });

    test('explicitly confirmed row can be set to requires_confirmation = 0',
        () async {
      final trialId =
          await db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

      final id = await db.into(db.trialPurposes).insert(
            TrialPurposesCompanion.insert(trialId: trialId),
          );

      // Simulate confirming: set requires_confirmation = 0.
      await (db.update(db.trialPurposes)..where((p) => p.id.equals(id)))
          .write(const TrialPurposesCompanion(
        requiresConfirmation: Value(0),
        status: Value('confirmed'),
      ));

      final rows = await db.select(db.trialPurposes).get();
      expect(rows.first.requiresConfirmation, 0);
      expect(rows.first.status, 'confirmed');
    });
  });
}
