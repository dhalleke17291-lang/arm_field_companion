import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _trial(AppDatabase db) =>
    db.into(db.trials).insert(TrialsCompanion.insert(name: 'T'));

Future<int> _signal(AppDatabase db, int trialId) =>
    SignalRepository.attach(db).raiseSignal(
      trialId: trialId,
      signalType: SignalType.scaleViolation,
      moment: SignalMoment.two,
      severity: SignalSeverity.review,
      referenceContext: const SignalReferenceContext(
        seType: 'PHYGEN',
        scaleMin: 0,
        scaleMax: 100,
        enteredValue: 110,
      ),
      consequenceText: 'Value out of range.',
    );

void main() {
  late AppDatabase db;
  late SignalRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SignalRepository.attach(db);
  });

  tearDown(() async => db.close());

  group('SignalRepository.getDecisionHistoryDtos', () {
    test('DD-1: returns empty list when no events exist', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      final dtos = await repo.getDecisionHistoryDtos(signalId);
      expect(dtos, isEmpty);
    });

    test('DD-2: returns DTO with correct fields', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.confirm,
        reason: 'Confirmed after field review.',
      );

      final dtos = await repo.getDecisionHistoryDtos(signalId);
      expect(dtos.length, 1);
      expect(dtos[0].signalId, signalId);
      expect(dtos[0].eventType, 'confirm');
      expect(dtos[0].note, 'Confirmed after field review.');
      expect(dtos[0].resultingStatus, 'resolved');
      expect(dtos[0].actorName, isNull);
      expect(dtos[0].id, greaterThan(0));
    });

    test('DD-3: returns events in chronological order', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.defer,
        reason: '',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.investigate,
        reason: 'Escalated for review.',
      );

      final dtos = await repo.getDecisionHistoryDtos(signalId);
      expect(dtos.length, 2);
      expect(dtos[0].eventType, 'defer');
      expect(dtos[1].eventType, 'investigate');
      expect(dtos[0].occurredAt, lessThanOrEqualTo(dtos[1].occurredAt));
    });
  });

  group('SignalRepository.getAllResearcherDecisionEventsForTrial', () {
    test('DD-4: returns empty list when trial has no signals', () async {
      final trialId = await _trial(db);

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos, isEmpty);
    });

    test('DD-5: filters out events with empty note', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.defer,
        reason: '',
      );

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos, isEmpty);
    });

    test('DD-6: filters out "Proceeded at session close" canned note',
        () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordDecisionEvent(
        signalId: signalId,
        eventType: SignalDecisionEventType.expire,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
        note: 'Proceeded at session close',
      );

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos, isEmpty);
    });

    test('DD-7: filters out "Not shown at session close" canned note',
        () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordDecisionEvent(
        signalId: signalId,
        eventType: SignalDecisionEventType.expire,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
        note: 'Not shown at session close',
      );

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos, isEmpty);
    });

    test('DD-8: filters out "Trial closed — signals expired" canned note',
        () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordDecisionEvent(
        signalId: signalId,
        eventType: SignalDecisionEventType.expire,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
        note: 'Trial closed — signals expired',
      );

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos, isEmpty);
    });

    test('DD-9: keeps researcher-authored notes that are not canned', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.confirm,
        reason: 'Deviation within field tolerance.',
      );

      final dtos =
          await repo.getAllResearcherDecisionEventsForTrial(trialId);
      expect(dtos.length, 1);
      expect(dtos[0].note, 'Deviation within field tolerance.');
    });

    test('DD-10: scopes to trialId — does not include other trials', () async {
      final trialIdA = await _trial(db);
      final trialIdB = await _trial(db);
      final signalA = await _signal(db, trialIdA);
      await _signal(db, trialIdB);

      await repo.recordResearcherDecision(
        signalId: signalA,
        eventType: SignalDecisionEventType.confirm,
        reason: 'Trial A decision.',
      );

      final dtosB =
          await repo.getAllResearcherDecisionEventsForTrial(trialIdB);
      expect(dtosB, isEmpty);
    });
  });
}
