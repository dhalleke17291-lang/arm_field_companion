import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/trial_cognition/mode_c_revelation_model.dart';
import 'package:arm_field_companion/domain/trial_cognition/trial_intent_seeder.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _insertTreatment(AppDatabase db, int trialId, String name,
    {String code = '1', int? armRowSortOrder}) async {
  final tId = await db.into(db.treatments).insert(
        TreatmentsCompanion.insert(
          trialId: trialId,
          code: code,
          name: name,
        ),
      );
  if (armRowSortOrder != null) {
    await db.into(db.armTreatmentMetadata).insert(
          ArmTreatmentMetadataCompanion.insert(
            treatmentId: tId,
            armRowSortOrder: Value(armRowSortOrder),
          ),
        );
  }
  return tId;
}

Future<int> _insertAssessmentDef(AppDatabase db,
    {String name = 'Yield', String code = 'YLD', String unit = 't/ha'}) async {
  return db.into(db.assessmentDefinitions).insert(
        AssessmentDefinitionsCompanion.insert(
          code: code,
          name: name,
          category: 'yield',
          unit: Value(unit),
        ),
      );
}

Future<int> _insertTrialAssessment(AppDatabase db,
    {required int trialId,
    required int defId,
    String? displayNameOverride}) async {
  return db.into(db.trialAssessments).insert(
        TrialAssessmentsCompanion.insert(
          trialId: trialId,
          assessmentDefinitionId: defId,
          displayNameOverride: Value(displayNameOverride),
        ),
      );
}

Future<void> _insertArmAssessmentMeta(AppDatabase db,
    {required int taId,
    int? columnIndex,
    String? ratingUnit}) async {
  await db.into(db.armAssessmentMetadata).insert(
        ArmAssessmentMetadataCompanion.insert(
          trialAssessmentId: taId,
          armImportColumnIndex: Value(columnIndex),
          ratingUnit: Value(ratingUnit),
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late TrialPurposeRepository purposeRepo;
  late TrialIntentSeeder seeder;
  late TrialRepository trialRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    purposeRepo = TrialPurposeRepository(db);
    seeder = TrialIntentSeeder(db, purposeRepo);
    trialRepo = TrialRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> makeTrial({String workspaceType = 'efficacy'}) =>
      trialRepo.createTrial(
        name: 'T${DateTime.now().microsecondsSinceEpoch}',
        workspaceType: workspaceType,
      );

  // T-1: basic confirmed seed
  test('T-1: seeds a confirmed row with sourceMode arm_structure', () async {
    final trialId = await makeTrial();
    await _insertTreatment(db, trialId, 'Treatment A',
        code: '1', armRowSortOrder: 0);

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row, isNotNull);
    expect(row!.status, 'confirmed');
    expect(row.requiresConfirmation, 0);
    expect(row.sourceMode, TrialPurposeSourceMode.armStructure);
  });

  // T-2: skips if confirmed row already exists
  test('T-2: skips seeding when a confirmed row already exists', () async {
    final trialId = await makeTrial();

    // Pre-seed a confirmed row manually
    await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      status: 'confirmed',
      requiresConfirmation: 0,
      sourceMode: TrialPurposeSourceMode.armStructure,
      trialPurpose: 'original',
    );

    // ARM import should not overwrite it
    await seeder.seedFromArmImportConfirmed(trialId);

    final rows = await (db.select(db.trialPurposes)
          ..where((p) => p.trialId.equals(trialId) & p.supersededAt.isNull()))
        .get();
    expect(rows.length, 1);
    expect(rows.first.trialPurpose, 'original');
  });

  // T-3: proceeds when only a draft row exists (guard is confirmed-only)
  test('T-3: proceeds when only a draft row exists', () async {
    final trialId = await makeTrial();

    await purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      status: 'draft',
      requiresConfirmation: 1,
    );

    await seeder.seedFromArmImportConfirmed(trialId);

    // A confirmed row should now exist alongside the draft
    final confirmed = await purposeRepo.getConfirmedTrialPurpose(trialId);
    expect(confirmed, isNotNull);
    expect(confirmed!.status, 'confirmed');
  });

  // T-4: claimBeingTested is null — never fabricated
  test('T-4: claimBeingTested is null on ARM import seed', () async {
    final trialId = await makeTrial();

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.claimBeingTested, isNull);
  });

  // T-5: fields without ARM source are null, not empty string
  test('T-5: regulatoryContext and knownInterpretationFactors are null', () async {
    final trialId = await makeTrial();

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.regulatoryContext, isNull);
    expect(row.knownInterpretationFactors, isNull);
  });

  // T-6: primaryEndpoint from first ARM assessment (lowest armImportColumnIndex)
  test('T-6: primaryEndpoint is first ARM assessment by column index', () async {
    final trialId = await makeTrial();

    final defA = await _insertAssessmentDef(db,
        name: 'Disease Severity', code: 'DSE', unit: '%');
    final defB =
        await _insertAssessmentDef(db, name: 'Yield', code: 'YLD', unit: 't/ha');

    final taA =
        await _insertTrialAssessment(db, trialId: trialId, defId: defA);
    final taB =
        await _insertTrialAssessment(db, trialId: trialId, defId: defB);

    // Column index 5 for A, 1 for B — B should be picked as primary
    await _insertArmAssessmentMeta(db,
        taId: taA, columnIndex: 5, ratingUnit: '%');
    await _insertArmAssessmentMeta(db,
        taId: taB, columnIndex: 1, ratingUnit: 't/ha');

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.primaryEndpoint, 'Yield (t/ha)');
  });

  // T-7: primaryEndpoint is null when no ARM assessment metadata exists
  test('T-7: primaryEndpoint is null when no ARM metadata is present', () async {
    final trialId = await makeTrial();

    // Add trial assessment but no arm_assessment_metadata row
    final defId =
        await _insertAssessmentDef(db, name: 'Yield', code: 'YLD', unit: 't/ha');
    await _insertTrialAssessment(db, trialId: trialId, defId: defId);

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.primaryEndpoint, isNull);
  });

  // T-8: treatmentRoleSummary ordered by ARM row sort order
  test('T-8: treatmentRoleSummary is comma-joined names in ARM sort order',
      () async {
    final trialId = await makeTrial();

    await _insertTreatment(db, trialId, 'Proline', code: '1', armRowSortOrder: 2);
    await _insertTreatment(db, trialId, 'UTC', code: '2', armRowSortOrder: 0);
    await _insertTreatment(db, trialId, 'Reference', code: '3', armRowSortOrder: 1);

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.treatmentRoleSummary, 'UTC, Reference, Proline');
  });

  // T-9: trialPurpose taken from workspaceType
  test('T-9: trialPurpose maps to trial workspaceType', () async {
    final trialId = await makeTrial(workspaceType: 'residue');

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    expect(row!.trialPurpose, 'residue');
  });

  // T-10: inferredFieldsJson is populated with ARM metadata counts
  test('T-10: inferredFieldsJson records source and counts', () async {
    final trialId = await makeTrial();
    await _insertTreatment(db, trialId, 'T1', code: '1', armRowSortOrder: 0);
    await _insertTreatment(db, trialId, 'T2', code: '2', armRowSortOrder: 1);

    final defId =
        await _insertAssessmentDef(db, name: 'Yield', code: 'YLD', unit: 't/ha');
    final taId =
        await _insertTrialAssessment(db, trialId: trialId, defId: defId);
    await _insertArmAssessmentMeta(db, taId: taId, columnIndex: 0);

    await seeder.seedFromArmImportConfirmed(trialId);

    final row = await purposeRepo.getCurrentTrialPurpose(trialId);
    final json = row!.inferredFieldsJson;
    expect(json, isNotNull);
    expect(json, contains('"source":"arm_import"'));
    expect(json, contains('"assessmentCount":1'));
    expect(json, contains('"treatmentCount":2'));
  });
}
