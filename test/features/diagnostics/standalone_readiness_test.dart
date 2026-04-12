import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_date_test_utils.dart';

final _readinessFamily =
    FutureProvider.family<TrialReadinessReport, int>((ref, trialId) {
  return TrialReadinessService().runChecks('$trialId', ref);
});

Future<TrialReadinessReport> _runReadiness(AppDatabase db, int trialId) async {
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  return container.read(_readinessFamily(trialId).future);
}

Future<int> _seedTrial(AppDatabase db, {required String workspaceType}) {
  return TrialRepository(db).createTrial(
    name: 't_${DateTime.now().microsecondsSinceEpoch}',
    workspaceType: workspaceType,
  );
}

/// Plots, assignments, treatment+component, trial assessment, session, one rating.
Future<void> _seedRatedTrial(AppDatabase db, int trialId) async {
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
  final plotPk =
      await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
  await db.into(db.assignments).insert(
        AssignmentsCompanion.insert(
          trialId: trialId,
          plotId: plotPk,
          treatmentId: Value(tid),
        ),
      );
  final defId = await db.into(db.assessmentDefinitions).insert(
        AssessmentDefinitionsCompanion.insert(
          code: 'C_${trialId}_a',
          name: 'Alpha',
          category: 'custom',
          isSystem: const Value(false),
          isActive: const Value(true),
        ),
      );
  final taId = await db.into(db.trialAssessments).insert(
        TrialAssessmentsCompanion.insert(
          trialId: trialId,
          assessmentDefinitionId: defId,
        ),
      );
  final taRepo = TrialAssessmentRepository(db);
  final legacyIds =
      await taRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
    trialId,
    [taId],
  );
  final session = await SessionRepository(db).createSession(
    trialId: trialId,
    name: 'S1',
    sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
    assessmentIds: legacyIds,
  );
  await db.into(db.ratingRecords).insert(
        RatingRecordsCompanion.insert(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: legacyIds.single,
          sessionId: session.id,
          resultStatus: const Value('RECORDED'),
          isCurrent: const Value(true),
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('standalone: no_seeding and no_applications are info', () async {
    final trialId = await _seedTrial(db, workspaceType: 'standalone');
    await _seedRatedTrial(db, trialId);
    final report = await _runReadiness(db, trialId);
    expect(
      report.checks
          .firstWhere((c) => c.code == 'no_seeding')
          .severity,
      TrialCheckSeverity.info,
    );
    expect(
      report.checks
          .firstWhere((c) => c.code == 'no_applications')
          .severity,
      TrialCheckSeverity.info,
    );
  });

  test('efficacy: no_seeding and no_applications are warnings', () async {
    final trialId = await _seedTrial(db, workspaceType: 'efficacy');
    await _seedRatedTrial(db, trialId);
    final report = await _runReadiness(db, trialId);
    expect(
      report.checks
          .firstWhere((c) => c.code == 'no_seeding')
          .severity,
      TrialCheckSeverity.warning,
    );
    expect(
      report.checks
          .firstWhere((c) => c.code == 'no_applications')
          .severity,
      TrialCheckSeverity.warning,
    );
  });

  test('per-assessment incomplete and all_assessments_complete', () async {
    final trialId = await _seedTrial(db, workspaceType: 'standalone');
    await _seedRatedTrial(db, trialId);
    final def2 = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'C_${trialId}_b',
            name: 'Beta',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: def2,
            sortOrder: const Value(1),
          ),
        );
    final report = await _runReadiness(db, trialId);
    expect(
      report.checks.any((c) => c.code.startsWith('assessment_incomplete_')),
      isTrue,
    );
    expect(
      report.checks.any((c) => c.code == 'all_assessments_complete'),
      isFalse,
    );
    final incomplete = report.checks.firstWhere(
        (c) => c.code.startsWith('assessment_incomplete_'));
    expect(incomplete.label, contains('/'));
    expect(incomplete.label, contains('plots rated'));
  });

  test('all_assessments_complete when each assessment rated on all plots',
      () async {
    final trialId = await _seedTrial(db, workspaceType: 'standalone');
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
    final plotPk =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
    await db.into(db.assignments).insert(
          AssignmentsCompanion.insert(
            trialId: trialId,
            plotId: plotPk,
            treatmentId: Value(tid),
          ),
        );
    final d1 = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'x1',
            name: 'X1',
            category: 'custom',
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
    final d2 = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'x2',
            name: 'X2',
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
    final legs = await taRepo.getOrCreateLegacyAssessmentIdsForTrialAssessments(
      trialId,
      [ta1, ta2],
    );
    final session = await SessionRepository(db).createSession(
      trialId: trialId,
      name: 'S',
      sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
      assessmentIds: legs,
    );
    for (final aid in legs) {
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: aid,
              sessionId: session.id,
              resultStatus: const Value('RECORDED'),
              isCurrent: const Value(true),
            ),
          );
    }

    final report = await _runReadiness(db, trialId);
    expect(
      report.checks.any((c) => c.code == 'all_assessments_complete'),
      isTrue,
    );
  });
}
