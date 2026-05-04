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

  group('SignalRepository.recordResearcherDecision', () {
    test('RD-1: confirm with reason records decision and resolves signal',
        () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.confirm,
        reason: 'Deviation reviewed, within field tolerance.',
      );

      final signal = await (db.select(db.signals)
            ..where((s) => s.id.equals(signalId)))
          .getSingle();
      expect(signal.status, 'resolved');

      final events = await repo.getDecisionHistory(signalId);
      expect(events.length, 1);
      expect(events[0].eventType, 'confirm');
      expect(events[0].note, 'Deviation reviewed, within field tolerance.');
      expect(events[0].resultingStatus, 'resolved');
    });

    test('RD-2: confirm with empty reason throws ArgumentError', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      expect(
        () => repo.recordResearcherDecision(
          signalId: signalId,
          eventType: SignalDecisionEventType.confirm,
          reason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('RD-3: suppress with empty reason throws ArgumentError', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      expect(
        () => repo.recordResearcherDecision(
          signalId: signalId,
          eventType: SignalDecisionEventType.suppress,
          reason: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('RD-4: investigate with empty reason throws ArgumentError', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      expect(
        () => repo.recordResearcherDecision(
          signalId: signalId,
          eventType: SignalDecisionEventType.investigate,
          reason: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('RD-5: defer with empty reason succeeds', () async {
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await expectLater(
        repo.recordResearcherDecision(
          signalId: signalId,
          eventType: SignalDecisionEventType.defer,
          reason: '',
        ),
        completes,
      );

      final signal = await (db.select(db.signals)
            ..where((s) => s.id.equals(signalId)))
          .getSingle();
      expect(signal.status, 'deferred');
    });

    test('RD-6: occurredAt is set within one second of call', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      final trialId = await _trial(db);
      final signalId = await _signal(db, trialId);

      await repo.recordResearcherDecision(
        signalId: signalId,
        eventType: SignalDecisionEventType.confirm,
        reason: 'Reviewed.',
      );

      final after = DateTime.now().millisecondsSinceEpoch;
      final events = await repo.getDecisionHistory(signalId);
      expect(events[0].occurredAt, greaterThanOrEqualTo(before));
      expect(events[0].occurredAt, lessThanOrEqualTo(after));
    });
  });
}
