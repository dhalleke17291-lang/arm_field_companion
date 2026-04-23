import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_date_test_utils.dart';
import 'stress_import_helpers.dart';

/// Parameterized ARM scale stress harness (Phase 0b-ta / Unit 6).
///
/// Runs the same end-to-end ARM workflow (import → extra sessions → rating →
/// export) across a matrix of RCBD-grounded trial shapes, and enforces
/// per-unit time budgets (µs per work item) rather than fixed wallclock
/// seconds. The goal is a regression net that holds across any trial shape
/// within ARM's acceptance range, not a point benchmark at a single size.
///
/// Budget ratios (top of file) are deliberately lax — 2–3× the measured
/// cost on a typical dev machine. Tighten them only after the matrix has
/// been stable for a while; the first run prints observed µs/unit so you
/// can calibrate.
///
/// The existing [scale_stress_test.dart] (fixed 200×10×3 case) stays as a
/// known-good smoke test; this file covers the *shape* axis instead of a
/// single maximum-size point.

// ── Per-unit budgets (µs per work item). Adjustable. ─────────────────────────
/// CSV import (parse + persist) per (plot × assessment column).
const _budgetCsvImportUsPerPlotAssessment = 6000;

/// Creating an additional rating session per (plot × assessment).
const _budgetCreateSessionUsPerPlotAssessment = 1500;

/// Saving one rating row (end-to-end via SaveRatingUseCase).
const _budgetSaveRatingUsPerRating = 6000;

/// Flat-CSV export per rating row emitted.
const _budgetExportCsvUsPerRating = 1500;

/// Fetching all plots for the trial, per plot.
const _budgetQueryPlotsUsPerPlot = 1000;

/// Loading the full arm_assessment_metadata map per AAM row.
///
/// Set slightly above the tightest observed baseline (~1510 µs/unit on a
/// cold run) so CI does not flake on scheduler / cache variance.
const _budgetAamLookupUsPerAssessment = 1800;

// ── Matrix cases. Adjustable. ────────────────────────────────────────────────
/// One row of the scale matrix. Keep these small and realistic: RCBD trials
/// rarely exceed ~200 plots per block, even wide efficacy screens stay under
/// ~20 assessments × 6 sessions. ARM's theoretical ceiling is much higher
/// (9,999 treatments / 999 data columns) but is not representative.
class _ScaleCase {
  const _ScaleCase({
    required this.name,
    required this.treatments,
    required this.reps,
    required this.assessments,
    required this.sessions,
  });

  final String name;
  final int treatments;
  final int reps;
  final int assessments;
  final int sessions;

  int get plots => treatments * reps;

  int get ratingsPerSession => plots * assessments;

  int get totalRatings => ratingsPerSession * sessions;

  int get plotAssessments => plots * assessments;
}

const _matrix = <_ScaleCase>[
  _ScaleCase(
    name: 'baseline',
    treatments: 12,
    reps: 3,
    assessments: 4,
    sessions: 3,
  ),
  _ScaleCase(
    name: 'high_reps',
    treatments: 6,
    reps: 10,
    assessments: 3,
    sessions: 3,
  ),
  _ScaleCase(
    name: 'grow_R_reps',
    treatments: 4,
    reps: 16,
    assessments: 2,
    sessions: 2,
  ),
  _ScaleCase(
    name: 'wide_and_deep',
    treatments: 20,
    reps: 8,
    assessments: 10,
    sessions: 6,
  ),
];

String _buildArmCsv(_ScaleCase c) {
  // Distinct header per assessment so dedup doesn't collapse columns.
  final headers = <String>['Plot No.', 'trt', 'reps'];
  for (var a = 1; a <= c.assessments; a++) {
    headers.add('WEED$a 1-Jul-26 CONTRO %');
  }
  final rows = <String>[headers.join(',')];
  var plotNum = 101;
  for (var rep = 1; rep <= c.reps; rep++) {
    for (var trt = 1; trt <= c.treatments; trt++) {
      final cols = <String>['$plotNum', '$trt', '$rep'];
      for (var a = 0; a < c.assessments; a++) {
        cols.add('${(trt * 3 + a * 7 + rep) % 100}');
      }
      rows.add(cols.join(','));
      plotNum++;
    }
  }
  return rows.join('\n');
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  for (final c in _matrix) {
    group('ARM scale matrix — ${c.name} '
        '(T=${c.treatments} R=${c.reps} A=${c.assessments} S=${c.sessions})', () {
      test('end-to-end workflow within per-unit budgets', () async {
        // 1 — Import.
        final csv = _buildArmCsv(c);
        final swImport = Stopwatch()..start();
        final r = await stressArmImportUseCase(db)
            .execute(csv, sourceFileName: 'matrix_${c.name}.csv');
        swImport.stop();
        expect(r.success, isTrue, reason: r.errorMessage ?? '');
        final trialId = r.trialId!;
        final importSessionId = r.importSessionId!;

        _expectWithinPerUnitBudget(
          label: 'Import ${c.name}',
          elapsed: swImport.elapsed,
          units: c.plotAssessments,
          budgetUsPerUnit: _budgetCsvImportUsPerPlotAssessment,
        );

        // 2 — Shape sanity. Catches regressions in importer's trial/plot/
        //     assessment creation paths.
        final plots = await (db.select(db.plots)
              ..where(
                  (p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
            .get();
        expect(plots.length, c.plots, reason: 'plot count mismatch');

        final treatments = await (db.select(db.treatments)
              ..where(
                  (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false)))
            .get();
        expect(treatments.length, c.treatments,
            reason: 'treatment count mismatch');

        final tas = await (db.select(db.trialAssessments)
              ..where((t) => t.trialId.equals(trialId)))
            .get();
        expect(tas.length, c.assessments,
            reason: 'trial-assessment count mismatch');

        // 3 — AAM parity (Unit 4 invariant). Every ARM-imported TA must have
        //     an arm_assessment_metadata row with armImportColumnIndex set.
        final swAam = Stopwatch()..start();
        final aamRows = await ArmColumnMappingRepository(db)
            .getAssessmentMetadatasForTrial(trialId);
        swAam.stop();
        final aamByTa = {for (final a in aamRows) a.trialAssessmentId: a};
        expect(aamByTa.length, c.assessments,
            reason: 'AAM row count mismatch');
        for (final ta in tas) {
          expect(aamByTa[ta.id]?.armImportColumnIndex, isNotNull,
              reason:
                  'TA ${ta.id} has no AAM.armImportColumnIndex after import');
        }
        _expectWithinPerUnitBudget(
          label: 'AAM lookup ${c.name}',
          elapsed: swAam.elapsed,
          units: c.assessments,
          budgetUsPerUnit: _budgetAamLookupUsPerAssessment,
        );

        // 4 — Query all plots.
        final swQuery = Stopwatch()..start();
        final queried = await PlotRepository(db).getPlotsForTrial(trialId);
        swQuery.stop();
        expect(queried.length, c.plots);
        _expectWithinPerUnitBudget(
          label: 'Query plots ${c.name}',
          elapsed: swQuery.elapsed,
          units: c.plots,
          budgetUsPerUnit: _budgetQueryPlotsUsPerPlot,
        );

        // 5 — Create (S-1) extra sessions and rate every plot×assessment in
        //     each. The import already seeded session 1, so we measure
        //     create + save across the remaining (S-1).
        await SessionRepository(db).closeSession(importSessionId);

        final importRatings = await (db.select(db.ratingRecords)
              ..where((rr) =>
                  rr.trialId.equals(trialId) &
                  rr.sessionId.equals(importSessionId)))
            .get();
        final assessmentIds =
            importRatings.map((rr) => rr.assessmentId).toSet().toList();
        expect(assessmentIds.length, c.assessments,
            reason: 'legacy assessment count mismatch');

        final extraSessions = c.sessions - 1;
        if (extraSessions > 0) {
          final sessionDateLocal =
              await sessionDateLocalValidForTrial(db, trialId);

          final save = SaveRatingUseCase(
            RatingRepository(db),
            RatingIntegrityGuard(
              PlotRepository(db),
              SessionRepository(db),
              TreatmentRepository(db, AssignmentRepository(db)),
            ),
          );

          // Only one session may be open at a time; create → rate → close for
          // each extra session. We accumulate create-time and rate-time
          // separately so the per-unit budgets remain meaningful.
          var createElapsedUs = 0;
          var rateElapsedUs = 0;
          for (var s = 0; s < extraSessions; s++) {
            final swCreate = Stopwatch()..start();
            final session = await SessionRepository(db).createSession(
              trialId: trialId,
              name: 'Scale session ${s + 2}',
              sessionDateLocal: sessionDateLocal,
              assessmentIds: assessmentIds,
            );
            swCreate.stop();
            createElapsedUs += swCreate.elapsedMicroseconds;

            final swRate = Stopwatch()..start();
            for (final plot in queried) {
              for (final aid in assessmentIds) {
                final res = await save.execute(
                  SaveRatingInput(
                    trialId: trialId,
                    plotPk: plot.id,
                    assessmentId: aid,
                    sessionId: session.id,
                    resultStatus: 'RECORDED',
                    numericValue: (plot.id * 7 + aid * 3) % 100,
                    textValue: null,
                    isSessionClosed: false,
                  ),
                );
                expect(res.isSuccess, isTrue,
                    reason:
                        'Plot ${plot.plotId}, assessment $aid: ${res.errorMessage}');
              }
            }
            swRate.stop();
            rateElapsedUs += swRate.elapsedMicroseconds;

            await SessionRepository(db).closeSession(session.id);
          }
          _expectWithinPerUnitBudget(
            label: 'Create $extraSessions sessions ${c.name}',
            elapsed: Duration(microseconds: createElapsedUs),
            units: c.plotAssessments * extraSessions,
            budgetUsPerUnit: _budgetCreateSessionUsPerPlotAssessment,
          );
          _expectWithinPerUnitBudget(
            label: 'Save ratings ${c.name}',
            elapsed: Duration(microseconds: rateElapsedUs),
            units: c.plotAssessments * extraSessions,
            budgetUsPerUnit: _budgetSaveRatingUsPerRating,
          );
        }

        // 6 — Integrity: total current rating count matches T·R·A·S.
        final allCurrent = await (db.select(db.ratingRecords)
              ..where((rr) =>
                  rr.trialId.equals(trialId) &
                  rr.isCurrent.equals(true)))
            .get();
        expect(allCurrent.length, c.totalRatings,
            reason:
                'Expected T·R·A·S = ${c.totalRatings} current ratings; got ${allCurrent.length}');

        // 7 — Export flat CSV.
        final trial = await (db.select(db.trials)
              ..where((t) => t.id.equals(trialId)))
            .getSingle();
        final swExport = Stopwatch()..start();
        final bundle = await exportStressTrialUseCase(db)
            .execute(trial: trial, format: ExportFormat.flatCsv);
        swExport.stop();
        final observationLines = bundle.observationsCsv.split('\n');
        // One header line + one data line per current rating (minus possible
        // trailing newline).
        final dataLines =
            observationLines.where((l) => l.isNotEmpty).length - 1;
        expect(dataLines, greaterThanOrEqualTo(c.totalRatings),
            reason:
                'Export omitted rows: got $dataLines, expected ≥ ${c.totalRatings}');
        _expectWithinPerUnitBudget(
          label: 'Export CSV ${c.name}',
          elapsed: swExport.elapsed,
          units: c.totalRatings,
          budgetUsPerUnit: _budgetExportCsvUsPerRating,
        );
      });
    });
  }
}

/// Asserts [elapsed] stays under [units] × [budgetUsPerUnit] microseconds.
/// Prints the observed µs/unit so budgets can be calibrated by inspection.
void _expectWithinPerUnitBudget({
  required String label,
  required Duration elapsed,
  required int units,
  required int budgetUsPerUnit,
}) {
  if (units <= 0) return;
  final observedUs = elapsed.inMicroseconds;
  final perUnitUs = observedUs / units;
  final budgetUs = units * budgetUsPerUnit;
  final perUnitLabel = '${perUnitUs.toStringAsFixed(1)}µs/unit';
  // ignore: avoid_print
  print('[stress] $label: $observedUs µs / $units units = $perUnitLabel '
      '(budget $budgetUsPerUnit µs/unit)');
  expect(
    observedUs <= budgetUs,
    isTrue,
    reason: '$label exceeded budget: $perUnitLabel > '
        '$budgetUsPerUnit µs/unit over $units units',
  );
}
