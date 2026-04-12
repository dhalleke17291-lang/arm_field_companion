import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/diagnostics/assessment_completion.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_date_test_utils.dart';

Future<Map<int, AssessmentCompletion>> _completionMap(
    AppDatabase db, int trialId) async {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  return container.read(trialAssessmentCompletionProvider(trialId).future);
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('no assessments → empty map', () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'x',
      workspaceType: 'standalone',
    );
    final map = await _completionMap(db, trialId);
    expect(map, isEmpty);
  });

  test('guard plots excluded from totalDataPlots', () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'g',
      workspaceType: 'standalone',
    );
    await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
    await PlotRepository(db).insertPlot(
      trialId: trialId,
      plotId: 'G',
      isGuardRow: true,
    );
    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'cd',
            name: 'N',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
          ),
        );
    final map = await _completionMap(db, trialId);
    expect(map.length, 1);
    expect(map.values.single.totalDataPlots, 1);
    expect(map.values.single.analyzablePlotCount, 1);
    expect(map.values.single.excludedFromAnalysisCount, 0);
  });

  test('analysis-excluded data plot reduces analyzable count only', () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'ex',
      workspaceType: 'standalone',
    );
    await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
    final pk2 =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: '102');
    await PlotRepository(db).setPlotExcludedFromAnalysis(
      pk2,
      exclusionReason: 'Damage',
      damageType: 'mechanical',
    );
    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'c2',
            name: 'M',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
          ),
        );
    final map = await _completionMap(db, trialId);
    final c = map.values.single;
    expect(c.totalDataPlots, 2);
    expect(c.analyzablePlotCount, 1);
    expect(c.excludedFromAnalysisCount, 1);
  });

  test('two assessments: A1 all rated, A2 none', () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'two',
      workspaceType: 'standalone',
    );
    final tid = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: 'T1',
            name: 'T1',
          ),
        );
    await db.into(db.treatmentComponents).insert(
          TreatmentComponentsCompanion.insert(
            treatmentId: tid,
            trialId: trialId,
            productName: 'C',
          ),
        );
    for (final id in ['101', '102']) {
      final pk =
          await PlotRepository(db).insertPlot(trialId: trialId, plotId: id);
      await db.into(db.assignments).insert(
            AssignmentsCompanion.insert(
              trialId: trialId,
              plotId: pk,
              treatmentId: Value(tid),
            ),
          );
    }
    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    expect(plots.length, 2);

    final d1 = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'd1',
            name: 'A1',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    final d2 = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'd2',
            name: 'A2',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    final ta1 = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: d1,
          ),
        );
    final ta2 = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: d2,
            sortOrder: const Value(1),
          ),
        );
    final taRepo = TrialAssessmentRepository(db);
    final leg = await taRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
      trialId,
      [ta1, ta2],
    );
    final session = await SessionRepository(db).createSession(
      trialId: trialId,
      name: 'S',
      sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
      assessmentIds: leg,
    );
    for (final p in plots) {
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: p.id,
              assessmentId: leg[0],
              sessionId: session.id,
              resultStatus: const Value('RECORDED'),
              isCurrent: const Value(true),
            ),
          );
    }

    final map = await _completionMap(db, trialId);
    expect(map.length, 2);
    final a1 = map.values.firstWhere((c) => c.assessmentName == 'A1');
    final a2 = map.values.firstWhere((c) => c.assessmentName == 'A2');
    expect(a1.ratedPlotCount, 2);
    expect(a1.isComplete, isTrue);
    expect(a2.ratedPlotCount, 0);
    expect(a2.isComplete, isFalse);
  });
}
