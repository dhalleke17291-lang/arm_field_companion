import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/domain/session_completeness_report.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/compute_session_completeness_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ComputeSessionCompletenessUseCase useCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    useCase = ComputeSessionCompletenessUseCase(
      SessionRepository(db),
      PlotRepository(db),
      RatingRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ComputeSessionCompletenessUseCase', () {
    test('session not found → blocker, zeros, cannot close', () async {
      final r = await useCase.execute(sessionId: 99999);
      expect(r.expectedPlots, 0);
      expect(r.completedPlots, 0);
      expect(r.incompletePlots, 0);
      expect(r.canClose, false);
      expect(r.issues, hasLength(1));
      expect(r.issues.single.code, SessionCompletenessIssueCode.sessionNotFound);
      expect(r.issues.single.severity, SessionCompletenessIssueSeverity.blocker);
    });

    test('no session assessments → all target plots incomplete, blocker', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T1', workspaceType: 'efficacy');
      final plotRepo = PlotRepository(db);
      await plotRepo.insertPlot(trialId: trialId, plotId: 'P1');
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.expectedPlots, 1);
      expect(r.completedPlots, 0);
      expect(r.incompletePlots, 1);
      expect(r.canClose, false);
      expect(
        r.issues.map((e) => e.code).toSet(),
        contains(SessionCompletenessIssueCode.noSessionAssessments),
      );
    });

    test('target plot fully RECORDED → complete; guard-only extra plot ignored',
        () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T2', workspaceType: 'efficacy');
      final plotRepo = PlotRepository(db);
      final targetPk =
          await plotRepo.insertPlot(trialId: trialId, plotId: 'TGT');
      await plotRepo.insertPlot(
        trialId: trialId,
        plotId: 'GRD',
        isGuardRow: true,
      );

      final a1 = await db.into(db.assessments).insert(
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
              assessmentId: a1,
              sortOrder: const Value(0),
            ),
          );

      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: targetPk,
              assessmentId: a1,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.recorded),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.expectedPlots, 1);
      expect(r.completedPlots, 1);
      expect(r.incompletePlots, 0);
      expect(r.canClose, true);
      expect(r.issues, isEmpty);
    });

    test('missing current rating → blocker per assessment', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T3', workspaceType: 'efficacy');
      final plotRepo = PlotRepository(db);
      final plotPk =
          await plotRepo.insertPlot(trialId: trialId, plotId: 'P1');

      final a1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
          );
      final a2 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A2'),
          );

      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-01',
            ),
          );

      for (var i = 0; i < 2; i++) {
        await db.into(db.sessionAssessments).insert(
              SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: i == 0 ? a1 : a2,
                sortOrder: Value(i),
              ),
            );
      }

      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: a1,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.recorded),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.completedPlots, 0);
      expect(r.incompletePlots, 1);
      expect(r.canClose, false);
      expect(
        r.issues.where((e) => e.code == SessionCompletenessIssueCode.missingCurrentRating),
        hasLength(1),
      );
      expect(
        r.issues.singleWhere((e) => e.code == SessionCompletenessIssueCode.missingCurrentRating).assessmentId,
        a2,
      );
    });

    test('VOID current rating → blocker; plot incomplete', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T4', workspaceType: 'efficacy');
      final plotPk =
          await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P1');
      final a1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
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
              assessmentId: a1,
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: a1,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.voided),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.completedPlots, 0);
      expect(r.canClose, false);
      expect(
        r.issues.single.code,
        SessionCompletenessIssueCode.voidRating,
      );
    });

    test('NOT_APPLICABLE → warning only; plot still complete; can close', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T5', workspaceType: 'efficacy');
      final plotPk =
          await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P1');
      final a1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
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
              assessmentId: a1,
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: a1,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.notApplicable),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.completedPlots, 1);
      expect(r.incompletePlots, 0);
      expect(r.canClose, true);
      expect(r.issues, hasLength(1));
      expect(r.issues.single.code, SessionCompletenessIssueCode.nonRecordedStatus);
      expect(r.issues.single.severity, SessionCompletenessIssueSeverity.warning);
    });

    test('rating for assessment not in session is ignored (still missing)', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T6', workspaceType: 'efficacy');
      final plotPk =
          await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P1');
      final inSession = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'In'),
          );
      final notInSession = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'Out'),
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
              assessmentId: inSession,
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: notInSession,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.recorded),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.canClose, false);
      expect(
        r.issues.single.code,
        SessionCompletenessIssueCode.missingCurrentRating,
      );
      expect(r.issues.single.assessmentId, inSession);
    });

    test('analysis-excluded data plot is skipped for session completeness',
        () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T8', workspaceType: 'efficacy');
      final plotRepo = PlotRepository(db);
      final analyzablePk =
          await plotRepo.insertPlot(trialId: trialId, plotId: 'OK');
      final excludedPk =
          await plotRepo.insertPlot(trialId: trialId, plotId: 'BAD');
      await plotRepo.setPlotExcludedFromAnalysis(
        excludedPk,
        exclusionReason: 'Contamination',
        damageType: 'contamination',
      );

      final a1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
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
              assessmentId: a1,
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: analyzablePk,
              assessmentId: a1,
              sessionId: sessionId,
              resultStatus: const Value(ResultStatusDb.recorded),
              isCurrent: const Value(true),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.expectedPlots, 1);
      expect(r.completedPlots, 1);
      expect(r.canClose, isTrue);
      expect(r.issues, isEmpty);
    });

    test('zero target plots with assessments → vacuously complete', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'T7', workspaceType: 'efficacy');
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: 'G1',
        isGuardRow: true,
      );
      final a1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(trialId: trialId, name: 'A1'),
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
              assessmentId: a1,
              sortOrder: const Value(0),
            ),
          );

      final r = await useCase.execute(sessionId: sessionId);
      expect(r.expectedPlots, 0);
      expect(r.completedPlots, 0);
      expect(r.incompletePlots, 0);
      expect(r.canClose, true);
      expect(r.issues, isEmpty);
    });
  });
}
