import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
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

  group('CtqFactorDefinitionRepository — acknowledgments (ACK)', () {
    test('ACK-1: acknowledgeCtqFactor inserts row with correct fields',
        () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'application_timing',
        reason: 'Protocol constraint documented in sponsor guidance.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final rows = await db.select(db.ctqFactorAcknowledgments).get();
      expect(rows.length, 1);
      expect(rows[0].trialId, trialId);
      expect(rows[0].factorKey, 'application_timing');
      expect(rows[0].reason,
          'Protocol constraint documented in sponsor guidance.');
      expect(rows[0].factorStatusAtAcknowledgment, 'review_needed');
    });

    test('ACK-2: empty reason throws ArgumentError', () async {
      final trialId = await makeTrial();

      expect(
        () => repo.acknowledgeCtqFactor(
          trialId: trialId,
          factorKey: 'application_timing',
          reason: '',
          factorStatusAtAcknowledgment: 'review_needed',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ACK-3: whitespace-only reason throws ArgumentError', () async {
      final trialId = await makeTrial();

      expect(
        () => repo.acknowledgeCtqFactor(
          trialId: trialId,
          factorKey: 'application_timing',
          reason: '   ',
          factorStatusAtAcknowledgment: 'review_needed',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ACK-4: acknowledgedAt is within one second of call', () async {
      final trialId = await makeTrial();
      final before = DateTime.now().millisecondsSinceEpoch;

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'plot_completeness',
        reason: 'Three plots excluded per protocol amendment.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final after = DateTime.now().millisecondsSinceEpoch;
      final rows = await db.select(db.ctqFactorAcknowledgments).get();
      expect(rows[0].acknowledgedAt, greaterThanOrEqualTo(before));
      expect(rows[0].acknowledgedAt, lessThanOrEqualTo(after));
    });

    test('ACK-5: getLatestAcknowledgment returns null when none exist',
        () async {
      final trialId = await makeTrial();

      final result = await repo.getLatestAcknowledgment(
        trialId: trialId,
        factorKey: 'application_timing',
      );
      expect(result, isNull);
    });

    test(
        'ACK-6: getLatestAcknowledgment returns most recent when multiple exist',
        () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'application_timing',
        reason: 'First acknowledgment.',
        factorStatusAtAcknowledgment: 'review_needed',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'application_timing',
        reason: 'Second acknowledgment with updated rationale.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final result = await repo.getLatestAcknowledgment(
        trialId: trialId,
        factorKey: 'application_timing',
      );
      expect(result, isNotNull);
      expect(result!.reason, 'Second acknowledgment with updated rationale.');
    });

    test('ACK-7: getLatestAcknowledgment scopes by factorKey', () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'application_timing',
        reason: 'Timing ack.',
        factorStatusAtAcknowledgment: 'review_needed',
      );

      final result = await repo.getLatestAcknowledgment(
        trialId: trialId,
        factorKey: 'plot_completeness',
      );
      expect(result, isNull);
    });

    test('ACK-8: getLatestAcknowledgment returns correct DTO fields', () async {
      final trialId = await makeTrial();

      await repo.acknowledgeCtqFactor(
        trialId: trialId,
        factorKey: 'rater_consistency',
        reason: 'Single rater trial — consistency check not applicable.',
        factorStatusAtAcknowledgment: 'unknown',
      );

      final result = await repo.getLatestAcknowledgment(
        trialId: trialId,
        factorKey: 'rater_consistency',
      );
      expect(result!.factorKey, 'rater_consistency');
      expect(result.reason,
          'Single rater trial — consistency check not applicable.');
      expect(result.factorStatusAtAcknowledgment, 'unknown');
      expect(result.actorName, isNull); // no user linked
      expect(result.id, greaterThan(0));
    });
  });
}
