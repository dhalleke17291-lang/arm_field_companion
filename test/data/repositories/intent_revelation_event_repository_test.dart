import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/intent_revelation_event_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/mode_c_revelation_model.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late IntentRevelationEventRepository repo;
  late TrialRepository trialRepo;
  late TrialPurposeRepository purposeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IntentRevelationEventRepository(db);
    trialRepo = TrialRepository(db);
    purposeRepo = TrialPurposeRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  test('append captured revelation event', () async {
    final trialId = await makeTrial();
    final id = await repo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.trialCreation,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: kModeCQuestionText[ModeCQuestionKeys.claimBeingTested]!,
      answerValue: 'Fungicide X reduces weed pressure',
      answerState: IntentAnswerState.captured,
      source: 'user',
    );
    expect(id, greaterThan(0));
  });

  test('append skipped revelation event', () async {
    final trialId = await makeTrial();
    final id = await repo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.trialCreation,
      questionKey: ModeCQuestionKeys.primaryEndpoint,
      questionText: kModeCQuestionText[ModeCQuestionKeys.primaryEndpoint]!,
      answerState: IntentAnswerState.skipped,
      source: 'user',
    );
    expect(id, greaterThan(0));
    final events = await repo.getIntentRevelationEventsForPurpose(-1);
    expect(events, isEmpty); // no purpose linked
  });

  test('retrieve revelation events by trial', () async {
    final trialId = await makeTrial();
    await repo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.trialCreation,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: 'Q1',
      answerState: IntentAnswerState.captured,
      source: 'user',
    );
    await repo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.firstAssessmentSetup,
      questionKey: ModeCQuestionKeys.primaryEndpoint,
      questionText: 'Q2',
      answerState: IntentAnswerState.skipped,
      source: 'user',
    );
    final events = await repo
        .watchIntentRevelationEventsForTrial(trialId)
        .first;
    expect(events.length, 2);
    expect(events.map((e) => e.questionKey),
        containsAll([ModeCQuestionKeys.claimBeingTested, ModeCQuestionKeys.primaryEndpoint]));
  });

  test('retrieve revelation events by purpose', () async {
    final trialId = await makeTrial();
    final purposeId = await purposeRepo.createInitialTrialPurpose(trialId: trialId);
    await repo.addIntentRevelationEvent(
      trialId: trialId,
      trialPurposeId: purposeId,
      touchpoint: ModeCTouchpoints.trialCreation,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: 'What?',
      answerState: IntentAnswerState.captured,
      source: 'user',
    );
    final events = await repo.getIntentRevelationEventsForPurpose(purposeId);
    expect(events.length, 1);
    expect(events.first.trialPurposeId, purposeId);
  });
}
