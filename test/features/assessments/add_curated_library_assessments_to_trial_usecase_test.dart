import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/assessments/add_curated_library_assessments_to_trial_usecase.dart';
import 'package:arm_field_companion/features/assessments/assessment_library.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  AddCuratedLibraryAssessmentsToTrialUseCase buildUseCase() {
    return AddCuratedLibraryAssessmentsToTrialUseCase(
      AssessmentDefinitionRepository(db),
      TrialAssessmentRepository(db),
    );
  }

  Future<int> createTrial() {
    return TrialRepository(db).createTrial(
      name: 'Library ${DateTime.now().microsecondsSinceEpoch}',
      workspaceType: 'standalone',
    );
  }

  LibraryAssessment entryById(String id) {
    return AssessmentLibrary.entries.firstWhere((entry) => entry.id == id);
  }

  Future<AssessmentDefinition> trialDefinition(int trialId) async {
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    final def = await AssessmentDefinitionRepository(db)
        .getById(tas.single.assessmentDefinitionId);
    return def!;
  }

  const mappedLibraryCases = [
    (libraryId: 'fung_disease_severity', systemCode: 'DISEASE_SEV'),
    (libraryId: 'herb_weed_cover', systemCode: 'WEED_COVER'),
    (libraryId: 'growth_canopy_closure', systemCode: 'STAND_COVER'),
  ];

  for (final mappedCase in mappedLibraryCases) {
    test(
        'library picker ${mappedCase.libraryId} uses ${mappedCase.systemCode} system definition',
        () async {
      final trialId = await createTrial();

      await buildUseCase().execute(
        trialId: trialId,
        selections: [entryById(mappedCase.libraryId)],
      );

      final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
      final systemDef = await AssessmentDefinitionRepository(db)
          .getByCode(mappedCase.systemCode);
      expect(tas.single.assessmentDefinitionId, systemDef!.id);
      expect(
        tas.single.instructionOverride,
        curatedLibraryInstructionTag(mappedCase.libraryId),
      );
    });
  }

  test('library picker unmapped library entry falls back to LIB definition',
      () async {
    final trialId = await createTrial();

    await buildUseCase().execute(
      trialId: trialId,
      selections: [entryById('herb_weed_density')],
    );

    final def = await trialDefinition(trialId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.category, 'Herbicide Efficacy');
  });

  test('library picker weed control does not map to weed cover guide',
      () async {
    final trialId = await createTrial();

    await buildUseCase().execute(
      trialId: trialId,
      selections: [entryById('herb_weed_control')],
    );

    final def = await trialDefinition(trialId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.name, '% weed control');
  });

  test('library picker percent crop injury does not map to 0-4 injury score',
      () async {
    final trialId = await createTrial();

    await buildUseCase().execute(
      trialId: trialId,
      selections: [entryById('phyto_crop_injury')],
    );

    final def = await trialDefinition(trialId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.name, '% crop injury');
  });

  test(
      'library picker mapped entry falls back when system definition is missing',
      () async {
    await db.customStatement(
      "DELETE FROM assessment_guides WHERE assessment_definition_id = "
      "(SELECT id FROM assessment_definitions WHERE code = 'DISEASE_SEV')",
    );
    await db.customStatement(
      "DELETE FROM assessment_definitions WHERE code = 'DISEASE_SEV'",
    );
    final trialId = await createTrial();

    await buildUseCase().execute(
      trialId: trialId,
      selections: [entryById('fung_disease_severity')],
    );

    final def = await trialDefinition(trialId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.category, 'Fungicide Efficacy');
  });
}
