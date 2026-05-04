import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CtqFactorDefinitionRepository repo;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CtqFactorDefinitionRepository(db);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  group('CtqFactorDefinitionRepository.getAllAcknowledgmentsForTrial', () {
    test('GAT-1: returns empty list when no acknowledgments exist', () async {
      final trialId = await makeTrial();

      final result = await repo.getAllAcknowledgmentsForTrial(trialId);
      expect(result, isEmpty);
    });

    test('GAT-2: returns acknowledgments for trial in chronological order',
        () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'application_timing',
        reason: 'First ack.',
        factorStatusAtAcknowledgment: 'review_needed',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'plot_completeness',
        reason: 'Second ack.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final result = await repo.getAllAcknowledgmentsForTrial(trialId);
      expect(result.length, 2);
      expect(result[0].reason, 'First ack.');
      expect(result[1].reason, 'Second ack.');
      expect(
        result[0].acknowledgedAt.millisecondsSinceEpoch,
        lessThanOrEqualTo(result[1].acknowledgedAt.millisecondsSinceEpoch),
      );
    });

    test('GAT-3: returns correct DTO fields', () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'rater_consistency',
        reason: 'Single rater — check not applicable.',
        factorStatusAtAcknowledgment: 'unknown',
      );

      final result = await repo.getAllAcknowledgmentsForTrial(trialId);
      expect(result.length, 1);
      expect(result[0].factorKey, 'rater_consistency');
      expect(result[0].reason, 'Single rater — check not applicable.');
      expect(result[0].factorStatusAtAcknowledgment, 'unknown');
      expect(result[0].actorName, isNull);
      expect(result[0].id, greaterThan(0));
    });

    test('GAT-4: scopes to trialId — does not include other trials', () async {
      final trialIdA = await makeTrial();
      final trialIdB = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialIdA,
        factorKey: 'application_timing',
        reason: 'Trial A ack.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final resultB = await repo.getAllAcknowledgmentsForTrial(trialIdB);
      expect(resultB, isEmpty);
    });

    test('GAT-5: multiple acks for same factorKey are all returned', () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'data_variance',
        reason: 'Initial review.',
        factorStatusAtAcknowledgment: 'review_needed',
      );
      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'data_variance',
        reason: 'Follow-up review.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final result = await repo.getAllAcknowledgmentsForTrial(trialId);
      expect(result.length, 2);
    });
  });
}
