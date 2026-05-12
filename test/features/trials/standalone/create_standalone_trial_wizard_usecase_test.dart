import 'dart:math';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assessment_guide_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/assessments/assessment_library.dart';
import 'package:arm_field_companion/features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/create_session_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/session_date_test_utils.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  CreateStandaloneTrialWizardUseCase buildUseCase() {
    final assign = AssignmentRepository(db);
    return CreateStandaloneTrialWizardUseCase(
      db,
      TrialRepository(db),
      TreatmentRepository(db, assign),
      PlotRepository(db),
      assign,
      AssessmentDefinitionRepository(db),
      TrialAssessmentRepository(db),
    );
  }

  const mappedLibraryCases = [
    (
      libraryId: 'fung_disease_severity',
      systemCode: 'DISEASE_SEV',
      name: '% disease severity',
      category: 'Fungicide Efficacy',
    ),
    (
      libraryId: 'herb_weed_cover',
      systemCode: 'WEED_COVER',
      name: '% weed cover',
      category: 'Herbicide Efficacy',
    ),
    (
      libraryId: 'growth_canopy_closure',
      systemCode: 'STAND_COVER',
      name: 'Canopy closure',
      category: 'Crop Growth',
    ),
  ];

  test('creates standalone trial, treatments, plots, assignments, assessments',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'Wiz ${DateTime.now().microsecondsSinceEpoch}',
        crop: 'Wheat',
        location: 'Here',
        season: '2026',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'CHK', treatmentType: 'CHK'),
          StandaloneWizardTreatmentInput(code: 'TRT2'),
          StandaloneWizardTreatmentInput(code: 'TRT3'),
          StandaloneWizardTreatmentInput(code: 'TRT4'),
        ],
        repCount: 4,
        plotsPerRep: 4,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% control',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
          ),
        ],
        random: Random(7),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final trial = await TrialRepository(db).getTrialById(trialId);
    expect(trial, isNotNull);
    expect(trial!.workspaceType, 'standalone');
    expect(trial.status, kTrialStatusActive);
    expect(trial.experimentalDesign, PlotGenerationEngine.designRcbd);

    final treatments = await TreatmentRepository(db, AssignmentRepository(db))
        .getTreatmentsForTrial(trialId);
    expect(treatments.length, 4);

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    expect(plots.length, 16);
    expect(plots.first.plotId, '101');
    expect(plots.every((p) => p.armPlotNumber == null), true);

    final assigns = await AssignmentRepository(db).getForTrial(trialId);
    expect(assigns.length, 16);
    for (var rep = 0; rep < 4; rep++) {
      final slice = plots.sublist(rep * 4, rep * 4 + 4);
      final tids = slice.map((pl) {
        final a = assigns.firstWhere((x) => x.plotId == pl.id);
        return a.treatmentId;
      }).toSet();
      expect(tids.length, 4);
    }

    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    expect(tas.length, 1);
  });

  test('skips assessments when list empty', () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'NoAssess ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designNonRandomized,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 2,
        plotsPerRep: 2,
        assessments: const [],
        random: Random(0),
      ),
    );
    expect(result.success, true);
    final tas =
        await TrialAssessmentRepository(db).getForTrial(result.trialId!);
    expect(tas, isEmpty);
  });

  test('empty name fails', () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      const CreateStandaloneTrialWizardInput(
        trialName: '   ',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: [],
      ),
    );
    expect(result.success, false);
  });

  test('duplicate trial name fails', () async {
    final name = 'Dup ${DateTime.now().microsecondsSinceEpoch}';
    final uc = buildUseCase();
    final r1 = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: name,
        experimentalDesign: PlotGenerationEngine.designCrd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [],
        random: Random(1),
      ),
    );
    expect(r1.success, true);
    final r2 = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: name,
        experimentalDesign: PlotGenerationEngine.designCrd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [],
        random: Random(2),
      ),
    );
    expect(r2.success, false);

    final count =
        await (db.select(db.trials)..where((t) => t.name.equals(name))).get();
    expect(count.length, 1);
  });

  test('wizard-created trial with assessments can create a session', () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'SessionPath ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'CHK', treatmentType: 'CHK'),
          StandaloneWizardTreatmentInput(code: 'TRT2'),
        ],
        repCount: 4,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% control',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
          ),
        ],
        random: Random(11),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    expect(plots.length, 8);
    final assigns = await AssignmentRepository(db).getForTrial(trialId);
    expect(assigns.length, 8);
    expect(assigns.every((a) => a.treatmentId != null), true);

    final taRepo = TrialAssessmentRepository(db);
    final trialAssessments = await taRepo.getForTrial(trialId);
    expect(trialAssessments.length, 1);

    final legacyIds =
        await taRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
      trialId,
      [trialAssessments.single.id],
    );
    expect(legacyIds, isNotEmpty);
    expect(legacyIds.length, 1);

    final createSession = CreateSessionUseCase(
      SessionRepository(db),
      promoteTrialToActiveIfReady: (_) async {},
    );
    final sessionResult = await createSession.execute(
      CreateSessionInput(
        trialId: trialId,
        name: 'Field session 1',
        sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
        assessmentIds: legacyIds,
      ),
    );

    expect(sessionResult.success, true);
    expect(sessionResult.session, isNotNull);
    expect(sessionResult.session!.trialId, trialId);
  });

  test('wizard with guard rows, physical dimensions, and GPS on trial',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'Grd ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 2,
        plotsPerRep: 2,
        guardRowsPerRep: 1,
        plotLengthM: 10.5,
        plotWidthM: 3.25,
        alleyLengthM: 1.5,
        latitude: 45.123456,
        longitude: -75.987654,
        assessments: const [],
        random: Random(3),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final trial = await TrialRepository(db).getTrialById(trialId);
    expect(trial, isNotNull);
    expect(trial!.plotLengthM, 10.5);
    expect(trial.plotWidthM, 3.25);
    expect(trial.alleyLengthM, 1.5);
    expect(trial.latitude, closeTo(45.123456, 1e-5));
    expect(trial.longitude, closeTo(-75.987654, 1e-5));

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    expect(plots.length, 8);
    expect(plots.where((p) => p.isGuardRow).length, 4);
    expect(
      plots.map((p) => p.plotId).toList(),
      [
        'G1-S1',
        '101',
        '102',
        'G1-E1',
        'G2-S1',
        '201',
        '202',
        'G2-E1',
      ],
    );
    for (final p in plots.where((x) => x.isGuardRow)) {
      expect(RegExp(r'^G\d+-[SE]\d+$').hasMatch(p.plotId), true);
    }
    for (final p in plots.where((x) => !x.isGuardRow)) {
      expect(RegExp(r'^\d+$').hasMatch(p.plotId), true);
    }

    final assigns = await AssignmentRepository(db).getForTrial(trialId);
    expect(assigns.length, 4);
    for (final p in plots.where((x) => x.isGuardRow)) {
      expect(assigns.any((a) => a.plotId == p.id), false);
    }
  });

  test('curated library assessment stores instruction override and LIB code',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'Lib ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: 'Weed density',
            unit: 'plants/m2',
            scaleMin: 0,
            scaleMax: 999,
            dataType: 'count',
            curatedLibraryEntryId: 'herb_weed_density',
            definitionCategory: 'Herbicide Efficacy',
          ),
        ],
        random: Random(99),
      ),
    );
    expect(result.success, true);
    final trialId = result.trialId!;
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    expect(tas.length, 1);
    expect(
      tas.single.instructionOverride,
      curatedLibraryInstructionTag('herb_weed_density'),
    );
    final defs =
        await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def =
        defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.code.length, lessThanOrEqualTo(50));
    expect(def.category, 'Herbicide Efficacy');
  });

  for (final mappedCase in mappedLibraryCases) {
    test(
        'mapped library assessment ${mappedCase.libraryId} uses ${mappedCase.systemCode} system definition',
        () async {
      final uc = buildUseCase();
      final result = await uc.execute(
        CreateStandaloneTrialWizardInput(
          trialName:
              'Mapped ${mappedCase.libraryId} ${DateTime.now().microsecondsSinceEpoch}',
          experimentalDesign: PlotGenerationEngine.designRcbd,
          treatments: const [
            StandaloneWizardTreatmentInput(code: 'A'),
            StandaloneWizardTreatmentInput(code: 'B'),
          ],
          repCount: 1,
          plotsPerRep: 2,
          assessments: [
            StandaloneWizardAssessmentInput(
              name: mappedCase.name,
              unit: '%',
              scaleMin: 0,
              scaleMax: 100,
              dataType: 'numeric',
              curatedLibraryEntryId: mappedCase.libraryId,
              definitionCategory: mappedCase.category,
            ),
          ],
          random: Random(100),
        ),
      );

      expect(result.success, true);
      final tas =
          await TrialAssessmentRepository(db).getForTrial(result.trialId!);
      final systemDef = await AssessmentDefinitionRepository(db)
          .getByCode(mappedCase.systemCode);
      expect(tas.single.assessmentDefinitionId, systemDef!.id);
      expect(
        tas.single.instructionOverride,
        curatedLibraryInstructionTag(mappedCase.libraryId),
      );
    });
  }

  test('custom assessment without library ID still uses custom definition',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'Custom ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: 'Custom score',
            unit: 'score',
            scaleMin: 0,
            scaleMax: 9,
            dataType: 'ordinal',
          ),
        ],
        random: Random(101),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    final defs =
        await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def =
        defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('CUSTOM_${trialId}_'), true);
    expect(tas.single.instructionOverride, isNull);

    final hasGuide = await AssessmentGuideRepository(db)
        .watchHasAnyGuide(
          trialAssessmentId: tas.single.id,
          assessmentDefinitionId: tas.single.assessmentDefinitionId,
        )
        .first;
    expect(hasGuide, isFalse);
  });

  test('manual standalone percent disease severity maps to DISEASE_SEV',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'ManualDisease ${DateTime.now().microsecondsSinceEpoch}',
        crop: 'Wheat',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% disease severity',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
          ),
        ],
        random: Random(103),
      ),
    );

    expect(result.success, true);
    final tas =
        await TrialAssessmentRepository(db).getForTrial(result.trialId!);
    final systemDef =
        await AssessmentDefinitionRepository(db).getByCode('DISEASE_SEV');
    expect(tas.single.assessmentDefinitionId, systemDef!.id);

    final hasGuide = await AssessmentGuideRepository(db)
        .watchHasAnyGuide(
          trialAssessmentId: tas.single.id,
          assessmentDefinitionId: tas.single.assessmentDefinitionId,
        )
        .first;
    expect(hasGuide, isTrue);
  });

  test('percent crop injury library entry remains LIB because scale mismatches',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'PercentInjury ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% crop injury',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
            curatedLibraryEntryId: 'phyto_crop_injury',
            definitionCategory: 'Crop Safety',
          ),
        ],
        random: Random(104),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    final defs =
        await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def =
        defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.name, '% crop injury');
  });

  test('weed control library entry remains LIB and does not map to weed cover',
      () async {
    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'WeedControl ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% weed control',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
            curatedLibraryEntryId: 'herb_weed_control',
            definitionCategory: 'Herbicide Efficacy',
          ),
        ],
        random: Random(105),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    final defs =
        await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def =
        defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
    expect(def.name, '% weed control');
  });

  test('mapped library assessment falls back when system definition is missing',
      () async {
    await db.customStatement(
      "DELETE FROM assessment_guide_anchors "
      "WHERE source_url = 'assets/reference_guides/lane1/wheat_disease_severity.svg'",
    );
    await db.customStatement(
      "DELETE FROM assessment_definitions WHERE code = 'DISEASE_SEV'",
    );

    final uc = buildUseCase();
    final result = await uc.execute(
      CreateStandaloneTrialWizardInput(
        trialName: 'MissingDef ${DateTime.now().microsecondsSinceEpoch}',
        experimentalDesign: PlotGenerationEngine.designRcbd,
        treatments: const [
          StandaloneWizardTreatmentInput(code: 'A'),
          StandaloneWizardTreatmentInput(code: 'B'),
        ],
        repCount: 1,
        plotsPerRep: 2,
        assessments: const [
          StandaloneWizardAssessmentInput(
            name: '% disease severity',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
            curatedLibraryEntryId: 'fung_disease_severity',
            definitionCategory: 'Fungicide Efficacy',
          ),
        ],
        random: Random(102),
      ),
    );

    expect(result.success, true);
    final trialId = result.trialId!;
    final tas = await TrialAssessmentRepository(db).getForTrial(trialId);
    final defs =
        await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def =
        defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('LIB_${trialId}_'), true);
  });
}
