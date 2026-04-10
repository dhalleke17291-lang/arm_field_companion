import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Minimal rows so only assessment check varies.
Future<int> _seedTrialWithPlotsAndTreatment(AppDatabase db) async {
  final trialId = await TrialRepository(db).createTrial(
    name: 'readiness_a_${DateTime.now().microsecondsSinceEpoch}',
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
  final pk = await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
  await db.into(db.assignments).insert(
        AssignmentsCompanion.insert(
          trialId: trialId,
          plotId: pk,
          treatmentId: Value(tid),
        ),
      );
  return trialId;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('only TrialAssessments → assessments_ok', () async {
    final trialId = await _seedTrialWithPlotsAndTreatment(db);
    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CUST_1',
            name: 'X',
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

    final report = await _runReadiness(db, trialId);
    final c = report.checks.singleWhere((x) => x.code == 'assessments_ok');
    expect(c.severity, TrialCheckSeverity.pass);
  });

  test('only legacy Assessments → assessments_ok', () async {
    final trialId = await _seedTrialWithPlotsAndTreatment(db);
    await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'Legacy',
          ),
        );

    final report = await _runReadiness(db, trialId);
    final c = report.checks.singleWhere((x) => x.code == 'assessments_ok');
    expect(c.severity, TrialCheckSeverity.pass);
  });

  test('neither → no_assessments blocker', () async {
    final trialId = await _seedTrialWithPlotsAndTreatment(db);
    final report = await _runReadiness(db, trialId);
    final c = report.checks.singleWhere((x) => x.code == 'no_assessments');
    expect(c.severity, TrialCheckSeverity.blocker);
  });

  test('both → assessments_ok', () async {
    final trialId = await _seedTrialWithPlotsAndTreatment(db);
    await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(
            trialId: trialId,
            name: 'Legacy',
          ),
        );
    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CUST_2',
            name: 'Y',
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

    final report = await _runReadiness(db, trialId);
    final c = report.checks.singleWhere((x) => x.code == 'assessments_ok');
    expect(c.severity, TrialCheckSeverity.pass);
  });
}
