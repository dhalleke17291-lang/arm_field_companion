import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('guard row containment', () {
    test('buildTrialExportRows omits ratings on guard plots', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final trialId = await TrialRepository(db).createTrial(
        name: 'Gx ${DateTime.now().microsecondsSinceEpoch}',
        workspaceType: 'efficacy',
      );
      final plotRepo = PlotRepository(db);
      final dataPk =
          await plotRepo.insertPlot(trialId: trialId, plotId: '101');
      final guardPk = await plotRepo.insertPlot(
        trialId: trialId,
        plotId: 'G1-L',
        isGuardRow: true,
      );

      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'A1',
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sessionId,
              assessmentId: assessmentId,
              sortOrder: const Value(0),
            ),
          );

      Future<void> insertRating(int plotPk) async {
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: assessmentId,
                sessionId: sessionId,
                resultStatus: const Value(ResultStatusDb.recorded),
                isCurrent: const Value(true),
              ),
            );
      }

      await insertRating(dataPk);
      final exportRepo = ExportRepository(db);
      var rows = await exportRepo.buildTrialExportRows(trialId: trialId);
      expect(rows.length, 1);
      expect(rows.single['plot_id'], '101');

      await insertRating(guardPk);
      rows = await exportRepo.buildTrialExportRows(trialId: trialId);
      expect(rows.length, 1);
      expect(rows.single['plot_id'], '101');
    });

    test('getRatedPlotCountForTrial ignores guard plot PKs', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final trialId = await TrialRepository(db).createTrial(
        name: 'R ${DateTime.now().microsecondsSinceEpoch}',
        workspaceType: 'efficacy',
      );
      final plotRepo = PlotRepository(db);
      final dataPk =
          await plotRepo.insertPlot(trialId: trialId, plotId: '101');
      final guardPk = await plotRepo.insertPlot(
        trialId: trialId,
        plotId: 'G',
        isGuardRow: true,
      );
      final assessmentId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );
      Future<void> rate(int plotPk) async {
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: assessmentId,
                sessionId: sessionId,
                resultStatus: const Value(ResultStatusDb.recorded),
                isCurrent: const Value(true),
              ),
            );
      }

      await rate(guardPk);
      final repo = RatingRepository(db);
      expect(await repo.getRatedPlotCountForTrial(trialId), 0);
      await rate(dataPk);
      expect(await repo.getRatedPlotCountForTrial(trialId), 1);
    });

    test('wizard guard plots have excludeFromAnalysis true', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final assign = AssignmentRepository(db);
      final uc = CreateStandaloneTrialWizardUseCase(
        db,
        TrialRepository(db),
        TreatmentRepository(db, assign),
        PlotRepository(db),
        assign,
        AssessmentDefinitionRepository(db),
        TrialAssessmentRepository(db),
      );
      final result = await uc.execute(
        CreateStandaloneTrialWizardInput(
          trialName: 'Gf ${DateTime.now().microsecondsSinceEpoch}',
          experimentalDesign: PlotGenerationEngine.designRcbd,
          treatments: const [
            StandaloneWizardTreatmentInput(code: 'A'),
            StandaloneWizardTreatmentInput(code: 'B'),
          ],
          repCount: 1,
          plotsPerRep: 2,
          guardRowsPerRep: 1,
          assessments: const [],
          random: Random(0),
        ),
      );
      expect(result.success, true);
      final plots = await PlotRepository(db).getPlotsForTrial(result.trialId!);
      for (final p in plots.where((x) => x.isGuardRow)) {
        expect(p.excludeFromAnalysis, true);
      }
      for (final p in plots.where((x) => !x.isGuardRow)) {
        expect(p.excludeFromAnalysis, false);
      }
    });
  });
}
