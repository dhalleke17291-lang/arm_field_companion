// Tests for SeTypeProfileRepository and the two guard helpers.
//
// NativeDatabase.memory() triggers AppDatabase.onCreate which seeds CONTRO
// and PHYGEN via _seedSeTypeProfiles(). All tests run against those seed rows
// — no manual inserts required.

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/se_type_profiles/se_type_profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeTypeProfileRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SeTypeProfileRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // getByPrefix
  // ---------------------------------------------------------------------------

  group('getByPrefix', () {
    test('returns CONTRO with correct seeded field values', () async {
      final p = await repo.getByPrefix('CONTRO');

      expect(p, isNotNull);
      expect(p!.ratingTypePrefix, 'CONTRO');
      expect(p.displayName, 'Weed Control');
      expect(p.measurementCategory, 'percent');
      expect(p.responseDirection, 'higher_better');
      expect(p.validObservationWindowMinDat, 7);
      expect(p.scaleMin, 0.0);
      expect(p.scaleMax, 100.0);
      expect(p.source, 'ARM_CONVENTION');
    });

    test('returns PHYGEN with correct seeded field values', () async {
      final p = await repo.getByPrefix('PHYGEN');

      expect(p, isNotNull);
      expect(p!.ratingTypePrefix, 'PHYGEN');
      expect(p.displayName, 'Crop Injury — Phytotoxicity');
      expect(p.measurementCategory, 'percent');
      expect(p.responseDirection, 'lower_better');
      expect(p.validObservationWindowMinDat, 3);
      expect(p.scaleMin, 0.0);
      expect(p.scaleMax, 100.0);
      expect(p.source, 'EPPO_PP1');
    });

    test('MVP nullable fields are null on both seed rows', () async {
      for (final prefix in ['CONTRO', 'PHYGEN']) {
        final p = await repo.getByPrefix(prefix);
        expect(p, isNotNull, reason: '$prefix must be seeded');
        expect(p!.validObservationWindowMaxDat, isNull,
            reason: '$prefix maxDat is not yet calibrated');
        expect(p.expectedCvMin, isNull,
            reason: '$prefix cvMin is not yet calibrated');
        expect(p.expectedCvMax, isNull,
            reason: '$prefix cvMax is not yet calibrated');
      }
    });

    test('returns null for an unknown prefix', () async {
      final p = await repo.getByPrefix('DOES_NOT_EXIST');
      expect(p, isNull);
    });

    test('returns null for empty string prefix', () async {
      final p = await repo.getByPrefix('');
      expect(p, isNull);
    });

    test('match is case-sensitive — lowercase prefix returns null', () async {
      final p = await repo.getByPrefix('contro');
      expect(p, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getAll
  // ---------------------------------------------------------------------------

  group('getAll', () {
    test('returns exactly the two seeded profiles', () async {
      final all = await repo.getAll();
      expect(all.length, 2);
      expect(
        all.map((p) => p.ratingTypePrefix).toSet(),
        containsAll({'CONTRO', 'PHYGEN'}),
      );
    });

    test('results are ordered by prefix ascending', () async {
      final all = await repo.getAll();
      // CONTRO < PHYGEN alphabetically.
      expect(all[0].ratingTypePrefix, 'CONTRO');
      expect(all[1].ratingTypePrefix, 'PHYGEN');
    });
  });

  // ---------------------------------------------------------------------------
  // hasValidWindow
  // ---------------------------------------------------------------------------

  group('hasValidWindow', () {
    test('true for CONTRO — minDat is 7', () async {
      final p = await repo.getByPrefix('CONTRO');
      expect(hasValidWindow(p!), isTrue);
    });

    test('true for PHYGEN — minDat is 3', () async {
      final p = await repo.getByPrefix('PHYGEN');
      expect(hasValidWindow(p!), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // hasCvBounds
  // ---------------------------------------------------------------------------

  group('hasCvBounds', () {
    test('false for CONTRO — both CV bounds are null (MVP defaults)', () async {
      final p = await repo.getByPrefix('CONTRO');
      expect(hasCvBounds(p!), isFalse);
    });

    test('false for PHYGEN — both CV bounds are null (MVP defaults)', () async {
      final p = await repo.getByPrefix('PHYGEN');
      expect(hasCvBounds(p!), isFalse);
    });
  });
}
