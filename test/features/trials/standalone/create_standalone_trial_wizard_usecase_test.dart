import 'dart:math';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/assessments/assessment_library.dart';
import 'package:arm_field_companion/features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/create_session_usecase.dart';
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

  test('creates standalone trial, treatments, plots, assignments, assessments', () async {
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
    expect(trial.status, 'draft');
    expect(trial.experimentalDesign, PlotGenerationEngine.designRcbd);

    final treatments =
        await TreatmentRepository(db, AssignmentRepository(db)).getTreatmentsForTrial(trialId);
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

    final legacyIds = await taRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
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
        sessionDateLocal: '2026-04-05',
        assessmentIds: legacyIds,
      ),
    );

    expect(sessionResult.success, true);
    expect(sessionResult.session, isNotNull);
    expect(sessionResult.session!.trialId, trialId);
  });

  test('wizard with guard rows, physical dimensions, and GPS on trial', () async {
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
        'G1-S1', '101', '102', 'G1-E1',
        'G2-S1', '201', '202', 'G2-E1',
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

  test('curated library assessment stores instruction override and LIB code', () async {
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
            name: '% weed control',
            unit: '%',
            scaleMin: 0,
            scaleMax: 100,
            dataType: 'numeric',
            curatedLibraryEntryId: 'herb_weed_control',
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
      curatedLibraryInstructionTag('herb_weed_control'),
    );
    final defs = await AssessmentDefinitionRepository(db).getAll(activeOnly: false);
    final def = defs.firstWhere((d) => d.id == tas.single.assessmentDefinitionId);
    expect(def.code.startsWith('LIB_herb_weed_control_${trialId}_'), true);
    expect(def.category, 'Herbicide Efficacy');
  });
}
