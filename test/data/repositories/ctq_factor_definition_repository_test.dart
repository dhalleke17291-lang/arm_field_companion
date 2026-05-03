import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CtqFactorDefinitionRepository repo;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CtqFactorDefinitionRepository(db);
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
  });

  tearDown(() async => db.close());

  Future<({int trialId, int purposeId})> makeTrialAndPurpose() async {
    final trialId =
        await trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');
    final purposeId = await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    return (trialId: trialId, purposeId: purposeId);
  }

  test('add and retrieve CTQ factor definition', () async {
    final ctx = await makeTrialAndPurpose();
    final id = await repo.addCtqFactorDefinition(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
      factorKey: 'application_timing',
      factorLabel: 'Application Timing',
      factorType: 'operational',
      importance: 'critical',
      source: 'user',
    );
    expect(id, greaterThan(0));
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(factors.length, 1);
    expect(factors.first.factorKey, 'application_timing');
    expect(factors.first.importance, 'critical');
  });

  test('retire CTQ factor definition hides it from watch', () async {
    final ctx = await makeTrialAndPurpose();
    final id = await repo.addCtqFactorDefinition(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
      factorKey: 'gps_evidence',
      factorLabel: 'GPS Evidence',
      factorType: 'documentation',
      source: 'user',
    );
    await repo.retireCtqFactorDefinition(id);
    final active = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(active, isEmpty);
  });

  test('seedDefaultCtqFactorsForPurpose inserts all 10 default factors', () async {
    final ctx = await makeTrialAndPurpose();
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(factors.length, kCtqDefaultFactorKeys.length);
    expect(
      factors.map((f) => f.factorKey).toSet(),
      containsAll(kCtqDefaultFactorKeys),
    );
  });

  test('seedDefaultCtqFactorsForPurpose is idempotent', () async {
    final ctx = await makeTrialAndPurpose();
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(factors.length, kCtqDefaultFactorKeys.length); // not doubled
  });

  test(
      'seedDefaultCtqFactorsForPurpose adds missing keys when partially seeded',
      () async {
    final ctx = await makeTrialAndPurpose();
    // Manually insert only one factor to simulate a trial seeded before V1.5.
    await repo.addCtqFactorDefinition(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
      factorKey: 'application_timing',
      factorLabel: 'Application Timing',
      factorType: 'operational',
      source: 'system_default',
    );
    // Re-seed: should add the remaining keys without touching the existing row.
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(factors.length, kCtqDefaultFactorKeys.length);
    expect(
      factors.where((f) => f.factorKey == 'application_timing').length,
      1, // not duplicated
    );
  });

  test('data_variance is included in the default seeded factors', () async {
    final ctx = await makeTrialAndPurpose();
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(factors.map((f) => f.factorKey), contains('data_variance'));
  });

  test('untreated_check_pressure is included in the default seeded factors',
      () async {
    final ctx = await makeTrialAndPurpose();
    await repo.seedDefaultCtqFactorsForPurpose(
      trialId: ctx.trialId,
      trialPurposeId: ctx.purposeId,
    );
    final factors = await repo.watchCtqFactorsForTrial(ctx.trialId).first;
    expect(
        factors.map((f) => f.factorKey), contains('untreated_check_pressure'));
  });
}
