import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AssessmentDefinitionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AssessmentDefinitionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getAll', () {
    test('returns system-seeded definitions by default', () async {
      // AppDatabase seeds 9 system definitions on creation.
      final all = await repo.getAll();
      expect(all.length, greaterThanOrEqualTo(9));
      // All should be active
      for (final d in all) {
        expect(d.isActive, true);
      }
    });

    test('filters by category', () async {
      final pest = await repo.getAll(category: 'pest');
      final growth = await repo.getAll(category: 'growth');
      // Categories should be disjoint
      final pestIds = pest.map((d) => d.id).toSet();
      final growthIds = growth.map((d) => d.id).toSet();
      expect(pestIds.intersection(growthIds), isEmpty);
    });
  });

  group('insertCustom', () {
    test('inserts custom definition with all fields', () async {
      final id = await repo.insertCustom(
        code: 'CUSTOM_TEST',
        name: 'Custom Test',
        category: 'custom',
        dataType: 'numeric',
        unit: '%',
        scaleMin: 0,
        scaleMax: 100,
        resultDirection: 'lowerBetter',
      );

      final def = await repo.getById(id);
      expect(def, isNotNull);
      expect(def!.code, 'CUSTOM_TEST');
      expect(def.name, 'Custom Test');
      expect(def.category, 'custom');
      expect(def.unit, '%');
      expect(def.scaleMin, 0);
      expect(def.scaleMax, 100);
      expect(def.isSystem, false);
      expect(def.isActive, true);
      expect(def.resultDirection, 'lowerBetter');
    });
  });

  group('getByCode', () {
    test('finds system definition by code', () async {
      // CROP_INJURY is seeded by the database.
      final def = await repo.getByCode('CROP_INJURY');
      expect(def, isNotNull);
      expect(def!.isSystem, true);
    });

    test('returns null for non-existent code', () async {
      final def = await repo.getByCode('DOES_NOT_EXIST');
      expect(def, isNull);
    });
  });

  group('updateDefinition', () {
    test('updates only specified fields', () async {
      final id = await repo.insertCustom(
        code: 'UPD_TEST',
        name: 'Original',
        category: 'custom',
        unit: 'kg/ha',
      );

      await repo.updateDefinition(id, name: 'Updated', scaleMax: 500);

      final def = await repo.getById(id);
      expect(def!.name, 'Updated');
      expect(def.scaleMax, 500);
      expect(def.code, 'UPD_TEST');
      expect(def.unit, 'kg/ha');
    });
  });

  group('getCategories', () {
    test('returns distinct active categories', () async {
      final cats = await repo.getCategories();
      expect(cats, isNotEmpty);
      // Should be sorted
      final sorted = List<String>.from(cats)..sort();
      expect(cats, sorted);
    });
  });
}
