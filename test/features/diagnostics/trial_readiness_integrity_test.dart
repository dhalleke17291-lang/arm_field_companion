import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/providers.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [TrialReadinessService.runChecks] with a real [Ref] (ProviderContainer).
final _readinessForTrialTestProvider =
    FutureProvider.family<TrialReadinessReport, int>((ref, trialId) {
  return TrialReadinessService().runChecks('$trialId', ref);
});

Future<TrialReadinessReport> _runReadiness(AppDatabase db, int trialId) async {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(container.dispose);
  return container.read(_readinessForTrialTestProvider(trialId).future);
}

TrialReadinessCheck _check(List<TrialReadinessCheck> checks, String code) {
  return checks.singleWhere((c) => c.code == code);
}

/// Minimal trial state so [TrialReadinessService] reaches integrity checks without
/// unrelated blockers (plots, treatments, assessments, assignments, sessions,
/// ratings, seeding, applied applications, components, etc.).
Future<int> _seedBaselineTrial(AppDatabase db, {required String name}) async {
  final trialId = await TrialRepository(db).createTrial(
    name: name,
    workspaceType: 'efficacy',
  );

  final treatmentId = await db.into(db.treatments).insert(
        TreatmentsCompanion.insert(
          trialId: trialId,
          code: 'TR',
          name: 'Tr',
        ),
      );
  await db.into(db.treatmentComponents).insert(
        TreatmentComponentsCompanion.insert(
          treatmentId: treatmentId,
          trialId: trialId,
          productName: 'Component',
        ),
      );

  final plotRepo = PlotRepository(db);
  final plotPk =
      await plotRepo.insertPlot(trialId: trialId, plotId: 'P1');

  await db.into(db.assignments).insert(
        AssignmentsCompanion.insert(
          trialId: trialId,
          plotId: plotPk,
          treatmentId: Value(treatmentId),
        ),
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
          startedAt: Value(DateTime.utc(2026, 6, 1)),
        ),
      );

  await db.into(db.sessionAssessments).insert(
        SessionAssessmentsCompanion.insert(
          sessionId: sessionId,
          assessmentId: assessmentId,
          sortOrder: const Value(0),
        ),
      );

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

  await db.into(db.seedingEvents).insert(
        SeedingEventsCompanion.insert(
          trialId: trialId,
          seedingDate: DateTime.utc(2025, 11, 1),
        ),
      );

  await db.into(db.trialApplicationEvents).insert(
        TrialApplicationEventsCompanion.insert(
          trialId: trialId,
          applicationDate: DateTime.utc(2026, 1, 1),
          productName: const Value('Prod'),
          rate: const Value(1.0),
          status: const Value('applied'),
          appliedAt: Value(DateTime.utc(2026, 1, 2)),
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

  test('T1: all plots assigned treatments → plots_without_treatment pass',
      () async {
    final trialId = await _seedBaselineTrial(
      db,
      name: 'int_t1_${DateTime.now().microsecondsSinceEpoch}',
    );
    final report = await _runReadiness(db, trialId);
    final c = _check(report.checks, 'plots_without_treatment');
    expect(c.severity, TrialCheckSeverity.pass);
    expect(c.label, 'All plots have treatments assigned');
  });

  test(
      'T2: one plot missing treatment → plots_without_treatment warning',
      () async {
    final trialId = await _seedBaselineTrial(
      db,
      name: 'int_t2_${DateTime.now().microsecondsSinceEpoch}',
    );
    final plotPk2 =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P2');

    final report = await _runReadiness(db, trialId);
    final c = _check(report.checks, 'plots_without_treatment');
    expect(c.severity, TrialCheckSeverity.warning);
    expect(c.label, contains('1 plot'));
    expect(c.label, contains('no treatment'));
    expect(plotPk2, greaterThan(0));
  });

  test(
      'T3: all corrections have reasons → corrections_missing_reason pass',
      () async {
    final trialId = await _seedBaselineTrial(
      db,
      name: 'int_t3_${DateTime.now().microsecondsSinceEpoch}',
    );
    final report = await _runReadiness(db, trialId);
    final c = _check(report.checks, 'corrections_missing_reason');
    expect(c.severity, TrialCheckSeverity.pass);
    expect(c.label, 'All corrections have reasons recorded');
  });

  test(
      'T4: one correction with empty reason → corrections_missing_reason blocker',
      () async {
    final trialId = await _seedBaselineTrial(
      db,
      name: 'int_t4_${DateTime.now().microsecondsSinceEpoch}',
    );
    final ratingRow = await (db.select(db.ratingRecords)
          ..where((r) => r.trialId.equals(trialId)))
        .getSingle();

    await db.into(db.ratingCorrections).insert(
          RatingCorrectionsCompanion.insert(
            ratingId: ratingRow.id,
            oldResultStatus: ResultStatusDb.recorded,
            newResultStatus: ResultStatusDb.recorded,
            reason: '',
          ),
        );

    final report = await _runReadiness(db, trialId);
    final c = _check(report.checks, 'corrections_missing_reason');
    expect(c.severity, TrialCheckSeverity.blocker);
    expect(c.label, contains('1 correction'));
    expect(c.label, contains('no reason'));
  });

  test(
      'T5: corrections on other trial ignored for corrections_missing_reason',
      () async {
    final trial1 = await _seedBaselineTrial(
      db,
      name: 'int_t5a_${DateTime.now().microsecondsSinceEpoch}',
    );
    final trial2 = await _seedBaselineTrial(
      db,
      name: 'int_t5b_${DateTime.now().microsecondsSinceEpoch}',
    );

    final t2Rating = await (db.select(db.ratingRecords)
          ..where((r) => r.trialId.equals(trial2)))
        .getSingle();
    await db.into(db.ratingCorrections).insert(
          RatingCorrectionsCompanion.insert(
            ratingId: t2Rating.id,
            oldResultStatus: ResultStatusDb.recorded,
            newResultStatus: ResultStatusDb.recorded,
            reason: '',
          ),
        );

    final report = await _runReadiness(db, trial1);
    final c = _check(report.checks, 'corrections_missing_reason');
    expect(c.severity, TrialCheckSeverity.pass);
  });
}
