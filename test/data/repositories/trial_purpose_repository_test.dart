import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrialPurposeRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TrialPurposeRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  group('createInitialTrialPurpose', () {
    test('inserts a draft purpose with version 1', () async {
      final trialId = await makeTrial();
      final id = await repo.createInitialTrialPurpose(trialId: trialId);
      expect(id, greaterThan(0));
      final p = await repo.getCurrentTrialPurpose(trialId);
      expect(p, isNotNull);
      expect(p!.version, 1);
      expect(p.status, 'draft');
    });

    test('captures optional fields', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Fungicide reduces disease severity',
        primaryEndpoint: 'DISEASE_SEV at 21 DAT',
      );
      final p = await repo.getCurrentTrialPurpose(trialId);
      expect(p!.claimBeingTested, 'Fungicide reduces disease severity');
      expect(p.primaryEndpoint, 'DISEASE_SEV at 21 DAT');
    });
  });

  group('confirmTrialPurpose', () {
    test('sets status to confirmed and records timestamp', () async {
      final trialId = await makeTrial();
      final id = await repo.createInitialTrialPurpose(trialId: trialId);
      await repo.confirmTrialPurpose(id, confirmedBy: 'test_user');
      final p = await repo.getCurrentTrialPurpose(trialId);
      expect(p!.status, 'confirmed');
      expect(p.confirmedAt, isNotNull);
      expect(p.confirmedBy, 'test_user');
    });
  });

  group('createNewTrialPurposeVersion', () {
    test('supersedes previous and creates next version', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);
      final v1 = await repo.getCurrentTrialPurpose(trialId);
      expect(v1, isNotNull);

      await repo.createNewTrialPurposeVersion(
        v1!,
        TrialPurposesCompanion.insert(
          trialId: trialId,
          claimBeingTested: const Value('Updated claim'),
        ),
      );

      final current = await repo.getCurrentTrialPurpose(trialId);
      expect(current!.version, 2);
      expect(current.claimBeingTested, 'Updated claim');

      // v1 must be superseded
      final old = await (db.select(db.trialPurposes)
            ..where((p) => p.id.equals(v1.id)))
          .getSingle();
      expect(old.status, 'superseded');
      expect(old.supersededAt, isNotNull);
    });
  });

  group('watchCurrentTrialPurpose', () {
    test('emits null when no purpose exists', () async {
      final trialId = await makeTrial();
      final stream = repo.watchCurrentTrialPurpose(trialId);
      expect(await stream.first, isNull);
    });

    test('emits purpose after creation', () async {
      final trialId = await makeTrial();
      await repo.createInitialTrialPurpose(trialId: trialId);
      final p = await repo.watchCurrentTrialPurpose(trialId).first;
      expect(p, isNotNull);
    });
  });
}
