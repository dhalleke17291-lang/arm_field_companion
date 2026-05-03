import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('Schema v78 migration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh install creates trial_purposes table', () async {
      final names = await _tableNames(db);
      expect(names, contains('trial_purposes'));
    });

    test('fresh install creates intent_revelation_events table', () async {
      final names = await _tableNames(db);
      expect(names, contains('intent_revelation_events'));
    });

    test('fresh install creates ctq_factor_definitions table', () async {
      final names = await _tableNames(db);
      expect(names, contains('ctq_factor_definitions'));
    });

    test('fresh install creates protocol_document_references table', () async {
      final names = await _tableNames(db);
      expect(names, contains('protocol_document_references'));
    });

    test('trials table gains field_orientation_degrees column', () async {
      final cols = await _columnNames(db, 'trials');
      expect(cols, contains('field_orientation_degrees'));
    });

    test('trials table gains field_anchor_type column', () async {
      final cols = await _columnNames(db, 'trials');
      expect(cols, contains('field_anchor_type'));
    });

    test('existing trials survive migration — geometry columns nullable', () async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(name: 'Legacy trial'),
          );
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(trialId)))
          .getSingle();
      expect(trial.fieldOrientationDegrees, isNull);
      expect(trial.fieldAnchorType, isNull);
    });

    test('current purpose selection returns newest non-superseded version', () async {
      final trialId = await db.into(db.trials).insert(
            TrialsCompanion.insert(name: 'Purpose trial'),
          );
      // Insert v1 then supersede it, insert v2.
      final v1Id = await db.into(db.trialPurposes).insert(
            TrialPurposesCompanion.insert(
              trialId: trialId,
              version: const Value(1),
            ),
          );
      await (db.update(db.trialPurposes)..where((p) => p.id.equals(v1Id)))
          .write(TrialPurposesCompanion(
        status: const Value('superseded'),
        supersededAt: Value(DateTime.now().toUtc()),
      ));
      final v2Id = await db.into(db.trialPurposes).insert(
            TrialPurposesCompanion.insert(
              trialId: trialId,
              version: const Value(2),
              status: const Value('draft'),
            ),
          );
      // Query current (non-superseded, newest version).
      final current = await (db.select(db.trialPurposes)
            ..where(
              (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
            )
            ..orderBy([(p) => OrderingTerm.desc(p.version)])
            ..limit(1))
          .getSingleOrNull();
      expect(current, isNotNull);
      expect(current!.id, v2Id);
      expect(current.version, 2);
    });
  });
}
