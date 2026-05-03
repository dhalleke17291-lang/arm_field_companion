import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/mode_c_revelation_model.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_purpose_dto.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Direct computation helper — mirrors _computeTrialPurposeDto from providers.dart
TrialPurposeDto computePurposeDto(int trialId, TrialPurpose? purpose) {
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
    provenanceSummary: missing.isEmpty ? 'Confirmed.' : '${missing.length} required field(s) missing.',
    canDriveReadinessClaims: effectiveStatus == 'confirmed' && missing.isEmpty,
  );
}

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

  test('returns unknown state when no purpose exists', () async {
    final trialId = await makeTrial();
    final purpose = await repo.getCurrentTrialPurpose(trialId);
    final dto = computePurposeDto(trialId, purpose);
    expect(dto.purposeStatus, 'unknown');
    expect(dto.canDriveReadinessClaims, false);
    expect(dto.missingIntentFields, containsAll(ModeCQuestionKeys.required));
  });

  test('returns partial state when some fields are present', () async {
    final trialId = await makeTrial();
    await repo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Fungicide X reduces disease',
    );
    final purpose = await repo.getCurrentTrialPurpose(trialId);
    final dto = computePurposeDto(trialId, purpose);
    expect(dto.purposeStatus, 'partial');
    expect(dto.missingIntentFields,
        contains(ModeCQuestionKeys.primaryEndpoint));
    expect(dto.claimBeingTested, 'Fungicide X reduces disease');
    expect(dto.canDriveReadinessClaims, false);
  });

  test('returns confirmed state when all required fields present and confirmed', () async {
    final trialId = await makeTrial();
    final id = await repo.createInitialTrialPurpose(
      trialId: trialId,
      claimBeingTested: 'Claim',
      trialPurpose: 'Regulatory submission',
      primaryEndpoint: 'DISEASE_SEV',
      treatmentRoleSummary: 'T1=untreated, T2=standard, T3=test',
    );
    await repo.confirmTrialPurpose(id);
    final purpose = await repo.getCurrentTrialPurpose(trialId);
    final dto = computePurposeDto(trialId, purpose);
    expect(dto.purposeStatus, 'confirmed');
    expect(dto.canDriveReadinessClaims, true);
    expect(dto.missingIntentFields, isEmpty);
  });
}
