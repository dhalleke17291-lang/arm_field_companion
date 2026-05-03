import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/intent_revelation_event_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/mode_c_revelation_model.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors _computeTrialPurposeDto from providers.dart — kept local to avoid
// provider layer dependency in unit tests.
TrialPurposeDto _computeDto(int trialId, TrialPurpose? purpose) {
  if (purpose == null) {
    return TrialPurposeDto(
      trialId: trialId,
      purposeStatus: 'unknown',
      missingIntentFields: List.unmodifiable(ModeCQuestionKeys.required),
      provenanceSummary: 'No purpose captured.',
      canDriveReadinessClaims: false,
    );
  }
  final missing = <String>[
    if (purpose.claimBeingTested == null) ModeCQuestionKeys.claimBeingTested,
    if (purpose.trialPurpose == null) ModeCQuestionKeys.trialPurposeContext,
    if (purpose.primaryEndpoint == null) ModeCQuestionKeys.primaryEndpoint,
    if (purpose.treatmentRoleSummary == null) ModeCQuestionKeys.treatmentRoles,
  ];
  final effectiveStatus = () {
    if (purpose.status == 'confirmed' && missing.isEmpty) return 'confirmed';
    if (missing.length < ModeCQuestionKeys.required.length) return 'partial';
    return purpose.status;
  }();
  return TrialPurposeDto(
    trialId: trialId,
    purposeStatus: effectiveStatus,
    claimBeingTested: purpose.claimBeingTested,
    trialPurpose: purpose.trialPurpose,
    regulatoryContext: purpose.regulatoryContext,
    primaryEndpoint: purpose.primaryEndpoint,
    treatmentRoles: purpose.treatmentRoleSummary,
    knownInterpretationFactors: purpose.knownInterpretationFactors,
    missingIntentFields: List.unmodifiable(missing),
    provenanceSummary: missing.isEmpty
        ? 'Confirmed.'
        : '${missing.length} required field(s) missing.',
    canDriveReadinessClaims: effectiveStatus == 'confirmed' && missing.isEmpty,
  );
}

void main() {
  late AppDatabase db;
  late TrialPurposeRepository purposeRepo;
  late IntentRevelationEventRepository eventRepo;
  late TrialRepository trialRepo;
  late CtqFactorDefinitionRepository ctqRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    purposeRepo = TrialPurposeRepository(db);
    eventRepo = IntentRevelationEventRepository(db);
    trialRepo = TrialRepository(db);
    ctqRepo = CtqFactorDefinitionRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial() =>
      trialRepo.createTrial(name: 'T${DateTime.now().microsecondsSinceEpoch}');

  // 1 — Empty state: no purpose row → dto.isUnknown
  test('empty state: no purpose row produces isUnknown dto', () async {
    final trialId = await makeTrial();
    final purpose = await purposeRepo.getCurrentTrialPurpose(trialId);
    final dto = _computeDto(trialId, purpose);
    expect(dto.isUnknown, isTrue);
    expect(dto.canDriveReadinessClaims, isFalse);
    expect(dto.missingIntentFields, hasLength(ModeCQuestionKeys.required.length));
  });

  // 2 — Answer captured: event written with answerState=captured
  test('answer action writes intent_revelation_event with state=captured',
      () async {
    final trialId = await makeTrial();
    await eventRepo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.manualOverview,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: kModeCQuestionText[ModeCQuestionKeys.claimBeingTested]!,
      answerValue: 'Fungicide reduces disease severity',
      answerState: IntentAnswerState.captured,
      source: 'field_researcher_input',
      capturedBy: 'test_researcher',
    );
    final events =
        await eventRepo.watchIntentRevelationEventsForTrial(trialId).first;
    expect(events, hasLength(1));
    expect(events.first.answerState, IntentAnswerState.captured);
    expect(events.first.answerValue, 'Fungicide reduces disease severity');
    expect(events.first.capturedBy, 'test_researcher');
  });

  // 3 — Skip action: event written with answerState=skipped
  test('skip action writes intent_revelation_event with state=skipped',
      () async {
    final trialId = await makeTrial();
    await eventRepo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.manualOverview,
      questionKey: ModeCQuestionKeys.knownInterpretationFactors,
      questionText:
          kModeCQuestionText[ModeCQuestionKeys.knownInterpretationFactors]!,
      answerValue: null,
      answerState: IntentAnswerState.skipped,
      source: 'field_researcher_input',
    );
    final events =
        await eventRepo.watchIntentRevelationEventsForTrial(trialId).first;
    expect(events.first.answerState, IntentAnswerState.skipped);
    expect(events.first.answerValue, isNull);
  });

  // 4 — Confirm: purpose created with status=confirmed after full flow
  test('confirm action creates purpose with status=confirmed', () async {
    final trialId = await makeTrial();
    final id = await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Herbicide weed control efficacy',
      trialPurpose: 'Registration support',
      primaryEndpoint: 'WEED_CTRL at 28 DAT',
      treatmentRoleSummary: 'T1=untreated check, T2=standard, T3=new compound',
    );
    await purposeRepo.confirmTrialPurpose(id, confirmedBy: 'test_researcher');
    final purpose = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(purpose!.status, 'confirmed');
    expect(purpose.confirmedBy, 'test_researcher');
    expect(purpose.confirmedAt, isNotNull);
  });

  // 5 — Revise action: event written with answerState=revised
  test('revise action writes intent_revelation_event with state=revised',
      () async {
    final trialId = await makeTrial();
    await eventRepo.addIntentRevelationEvent(
      trialId: trialId,
      touchpoint: ModeCTouchpoints.manualOverview,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: kModeCQuestionText[ModeCQuestionKeys.claimBeingTested]!,
      answerValue: 'Updated claim after field observation',
      answerState: IntentAnswerState.revised,
      source: 'field_researcher_input',
    );
    final events =
        await eventRepo.watchIntentRevelationEventsForTrial(trialId).first;
    expect(events.first.answerState, IntentAnswerState.revised);
  });

  // 6 — Versioning: existing purpose is superseded when new version created
  test('confirm with existing purpose creates new version and supersedes old',
      () async {
    final trialId = await makeTrial();
    await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Original claim',
    );
    final v1 = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(v1!.version, 1);

    final newId = await purposeRepo.createNewTrialPurposeVersion(
      v1,
      TrialPurposesCompanion.insert(
        trialId: trialId,
        claimBeingTested: const Value('Revised claim'),
        trialPurpose: const Value('Registration support'),
        primaryEndpoint: const Value('DISEASE_SEV'),
        treatmentRoleSummary: const Value('T1=check, T2=new'),
      ),
    );
    await purposeRepo.confirmTrialPurpose(newId, confirmedBy: 'researcher');

    final current = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(current!.version, 2);
    expect(current.claimBeingTested, 'Revised claim');
    expect(current.status, 'confirmed');
    expect(v1.supersededAt, isNull);
    final old = await (db.select(db.trialPurposes)
          ..where((p) => p.id.equals(v1.id)))
        .getSingleOrNull();
    expect(old!.supersededAt, isNotNull);
  });

  // 7 — Partial status: some required fields answered but not all
  test('dto reports partial when some but not all required fields are present',
      () async {
    final trialId = await makeTrial();
    await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Fungicide efficacy',
      trialPurpose: 'Label expansion',
    );
    final purpose = await purposeRepo.getCurrentTrialPurpose(trialId);
    final dto = _computeDto(trialId, purpose);
    expect(dto.isPartial, isTrue);
    expect(dto.missingIntentFields,
        containsAll([ModeCQuestionKeys.primaryEndpoint, ModeCQuestionKeys.treatmentRoles]));
  });

  // 8 — canDriveReadinessClaims: true when all required fields confirmed
  test('canDriveReadinessClaims is true when all required fields confirmed',
      () async {
    final trialId = await makeTrial();
    final id = await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Fungicide efficacy',
      trialPurpose: 'Registration',
      primaryEndpoint: 'DISEASE_SEV at 21 DAT',
      treatmentRoleSummary: 'T1=untreated, T2=product',
    );
    await purposeRepo.confirmTrialPurpose(id, confirmedBy: 'researcher');
    final purpose = await purposeRepo.getCurrentTrialPurpose(trialId);
    final dto = _computeDto(trialId, purpose);
    expect(dto.isConfirmed, isTrue);
    expect(dto.canDriveReadinessClaims, isTrue);
    expect(dto.missingIntentFields, isEmpty);
  });

  // 10 — confirming Mode C seeds 10 default CTQ factors for the confirmed purpose
  test('confirming Mode C flow seeds default CTQ factors for the purpose',
      () async {
    final trialId = await makeTrial();
    final purposeId = await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Fungicide efficacy on wheat.',
      trialPurpose: 'Registration support',
      primaryEndpoint: 'DISEASE_SEV at 21 DAT',
      treatmentRoleSummary: 'T1=untreated, T2=product',
    );
    await purposeRepo.confirmTrialPurpose(purposeId, confirmedBy: 'researcher');

    await ctqRepo.seedDefaultCtqFactorsForPurpose(
      trialId: trialId,
      trialPurposeId: purposeId,
    );

    final factors = await ctqRepo.watchCtqFactorsForTrial(trialId).first;
    expect(factors, hasLength(kCtqDefaultFactorKeys.length));
    expect(
      factors.map((f) => f.factorKey),
      containsAll(kCtqDefaultFactorKeys),
    );
  });

  // 9 — getIntentRevelationEventsForPurpose returns only events for that purpose
  test('getIntentRevelationEventsForPurpose scopes to correct purpose id',
      () async {
    final trialId = await makeTrial();
    final purposeId = await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
    );

    await eventRepo.addIntentRevelationEvent(
      trialId: trialId,
      trialPurposeId: purposeId,
      touchpoint: ModeCTouchpoints.manualOverview,
      questionKey: ModeCQuestionKeys.claimBeingTested,
      questionText: kModeCQuestionText[ModeCQuestionKeys.claimBeingTested]!,
      answerValue: 'Claim A',
      answerState: IntentAnswerState.confirmed,
      source: 'field_researcher_input',
    );
    await eventRepo.addIntentRevelationEvent(
      trialId: trialId,
      trialPurposeId: null,
      touchpoint: ModeCTouchpoints.manualOverview,
      questionKey: ModeCQuestionKeys.primaryEndpoint,
      questionText: kModeCQuestionText[ModeCQuestionKeys.primaryEndpoint]!,
      answerValue: 'Endpoint B',
      answerState: IntentAnswerState.captured,
      source: 'field_researcher_input',
    );

    final purposeEvents =
        await eventRepo.getIntentRevelationEventsForPurpose(purposeId);
    expect(purposeEvents, hasLength(1));
    expect(purposeEvents.first.questionKey, ModeCQuestionKeys.claimBeingTested);
  });
}
