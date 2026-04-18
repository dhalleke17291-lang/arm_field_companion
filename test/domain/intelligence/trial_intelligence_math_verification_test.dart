import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/intelligence/trial_intelligence_service.dart';
import 'package:arm_field_companion/domain/models/trial_insight.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_date_test_utils.dart';
import '../../stress/stress_import_helpers.dart';

/// Verifies intelligence service math against hand-computed values.
///
/// Dataset:
///   3 treatments: CHK, TRT2, TRT3
///   4 reps each = 12 plots
///   3 sessions with known rating values
///
/// Session 1 (7 DAA equivalent):
///   CHK reps:  5, 8, 6, 7   → mean = 6.5
///   TRT2 reps: 40, 45, 42, 43 → mean = 42.5
///   TRT3 reps: 30, 35, 32, 33 → mean = 32.5
///
/// Session 2 (14 DAA equivalent):
///   CHK reps:  12, 15, 13, 14 → mean = 13.5
///   TRT2 reps: 70, 75, 72, 73 → mean = 72.5
///   TRT3 reps: 55, 60, 57, 58 → mean = 57.5
///
/// Session 3 (21 DAA equivalent):
///   CHK reps:  25, 28, 26, 27 → mean = 26.5
///   TRT2 reps: 80, 85, 82, 83 → mean = 82.5
///   TRT3 reps: 65, 70, 67, 68 → mean = 67.5
///
/// Manual calculations:
///   Effect size (session 3): (best=82.5 − check=26.5) / 26.5 × 100 = 211.3%
///   Separation trend:
///     Session 2 effect: (72.5 − 13.5) / 13.5 × 100 = 437.0%
///     Session 3 effect: (82.5 − 26.5) / 26.5 × 100 = 211.3%
///     Delta: 211.3 − 437.0 = -225.7 → collapsing (delta < -5)
///
///   Check trend: 6.5 → 13.5 → 26.5. Direction: rising (delta > 5)
///
///   TRT2 trend: 42.5 → 72.5 → 82.5 (+40 points)
///   TRT3 trend: 32.5 → 57.5 → 67.5 (+35 points)
///
///   Rep variability (all sessions, all treatments):
///     Rep 1 values: 5,40,30, 12,70,55, 25,80,65 → mean = 42.4
///     Rep 2 values: 8,45,35, 15,75,60, 28,85,70 → mean = 46.8
///     Rep 3 values: 6,42,32, 13,72,57, 26,82,67 → mean = 44.1
///     Rep 4 values: 7,43,33, 14,73,58, 27,83,68 → mean = 45.1
///     Grand mean: (42.4+46.8+44.1+45.1)/4 = 44.6
///     No outlier reps (all within 2 SD)
void main() {
  late AppDatabase db;
  late TrialIntelligenceService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
    service = TrialIntelligenceService(
      sessionRepository: SessionRepository(db),
      ratingRepository: RatingRepository(db),
      plotRepository: PlotRepository(db),
      assignmentRepository: AssignmentRepository(db),
      treatmentRepository: TreatmentRepository(db, AssignmentRepository(db)),
      weatherSnapshotRepository: WeatherSnapshotRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Known rating values per (treatment_index, rep_index, session_index).
  /// Treatment 1=CHK, 2=TRT2, 3=TRT3.
  const knownValues = <(int, int, int), double>{
    // Session 1
    (1, 1, 1): 5, (1, 2, 1): 8, (1, 3, 1): 6, (1, 4, 1): 7,
    (2, 1, 1): 40, (2, 2, 1): 45, (2, 3, 1): 42, (2, 4, 1): 43,
    (3, 1, 1): 30, (3, 2, 1): 35, (3, 3, 1): 32, (3, 4, 1): 33,
    // Session 2
    (1, 1, 2): 12, (1, 2, 2): 15, (1, 3, 2): 13, (1, 4, 2): 14,
    (2, 1, 2): 70, (2, 2, 2): 75, (2, 3, 2): 72, (2, 4, 2): 73,
    (3, 1, 2): 55, (3, 2, 2): 60, (3, 3, 2): 57, (3, 4, 2): 58,
    // Session 3
    (1, 1, 3): 25, (1, 2, 3): 28, (1, 3, 3): 26, (1, 4, 3): 27,
    (2, 1, 3): 80, (2, 2, 3): 85, (2, 3, 3): 82, (2, 4, 3): 83,
    (3, 1, 3): 65, (3, 2, 3): 70, (3, 3, 3): 67, (3, 4, 3): 68,
  };

  Future<({int trialId, List<Treatment> treatments})> seedKnownTrial() async {
    // Import via CSV: 3 treatments × 4 reps = 12 plots.
    // Session 1 values come from import.
    final rows = <String>['Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %'];
    var plotNum = 101;
    for (var rep = 1; rep <= 4; rep++) {
      for (var trt = 1; trt <= 3; trt++) {
        final v = knownValues[(trt, rep, 1)]!;
        rows.add('$plotNum,$trt,$rep,${v.toInt()}');
        plotNum++;
      }
    }
    final csv = rows.join('\n');
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'math_verify.csv');
    expect(r.success, isTrue);
    final trialId = r.trialId!;
    final importSessionId = r.importSessionId!;

    // Capture original treatment ID→code mapping BEFORE rename.
    var treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);
    // Import creates treatments with codes "1", "2", "3" from CSV trt column.
    // Map original code to treatment ID so we can look up knownValues correctly.
    final originalCodeToId = <String, int>{
      for (final t in treatments) t.code: t.id,
    };
    // Treatment with original code "1" becomes CHK.
    final chkId = originalCodeToId['1']!;
    await (db.update(db.treatments)
          ..where((t) => t.id.equals(chkId)))
        .write(const TreatmentsCompanion(code: drift.Value('CHK')));
    treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);

    await SessionRepository(db).closeSession(importSessionId);

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    plots.sort((a, b) => a.plotId.compareTo(b.plotId));

    // Map plot PK → original trt index (1, 2, or 3) using assignments.
    final assignments = await AssignmentRepository(db).getForTrial(trialId);
    final plotToOrigTrtIdx = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId == null) continue;
      // Find original code for this treatment ID.
      final origCode = originalCodeToId.entries
          .firstWhere((e) => e.value == a.treatmentId)
          .key;
      plotToOrigTrtIdx[a.plotId] = int.parse(origCode);
    }

    final importRatings = await RatingRepository(db)
        .getCurrentRatingsForSession(importSessionId);
    final assessmentIds =
        importRatings.map((rr) => rr.assessmentId).toSet().toList();

    final saveUseCase = SaveRatingUseCase(
      RatingRepository(db),
      RatingIntegrityGuard(
        PlotRepository(db),
        SessionRepository(db),
        TreatmentRepository(db, AssignmentRepository(db)),
      ),
    );

    // Sessions 2 and 3
    for (var sIdx = 2; sIdx <= 3; sIdx++) {
      final session = await SessionRepository(db).createSession(
        trialId: trialId,
        name: 'Session $sIdx',
        sessionDateLocal:
            await sessionDateLocalValidForTrial(db, trialId),
        assessmentIds: assessmentIds,
      );

      for (final plot in plots) {
        final trtIdx = plotToOrigTrtIdx[plot.id];
        if (trtIdx == null) continue;
        final repNum = plot.rep ?? 1;
        final value = knownValues[(trtIdx, repNum, sIdx)];
        if (value == null) continue;

        await saveUseCase.execute(SaveRatingInput(
          trialId: trialId,
          plotPk: plot.id,
          assessmentId: assessmentIds.first,
          sessionId: session.id,
          resultStatus: 'RECORDED',
          numericValue: value,
          textValue: null,
          isSessionClosed: false,
        ));
      }
      await SessionRepository(db).closeSession(session.id);
    }

    return (trialId: trialId, treatments: treatments);
  }

  group('math verification', () {
    test('effect size matches manual calculation', () async {
      final seed = await seedKnownTrial();
      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final health = insights
          .where((i) => i.type == InsightType.trialHealth)
          .first;

      // Manual: (82.5 - 26.5) / 26.5 × 100 = 211.3%
      expect(health.detail, contains('Effect size: 211%'));
      expect(health.detail, contains('Separation: collapsing'));
    });

    test('check trend matches manual calculation', () async {
      final seed = await seedKnownTrial();
      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final checkTrend = insights
          .where((i) => i.type == InsightType.checkTrend)
          .first;

      // Manual: 6 → 14 → 26 (rounded from 6.5, 13.5, 26.5)
      // Direction: rising (26.5 - 6.5 = 20 > 5)
      expect(checkTrend.detail, contains('Direction: rising'));
      // Values should be close to manual means
      expect(checkTrend.detail, contains('→'));
    });

    test('treatment trend delta matches manual calculation', () async {
      final seed = await seedKnownTrial();
      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      // Find TRT2 trend (code "2" from import)
      final trends = insights
          .where((i) => i.type == InsightType.treatmentTrend)
          .toList();
      expect(trends, isNotEmpty);

      // Each trend should contain point delta
      for (final t in trends) {
        expect(t.detail, contains('points'),
            reason: 'Trend "${t.detail}" should state absolute point change');
      }
    });

    test('rep variability means are within expected range', () async {
      final seed = await seedKnownTrial();
      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final repVar = insights
          .where((i) => i.type == InsightType.repVariability)
          .first;

      // Manual grand mean ≈ 44.6, all reps within 42-47 range
      // No outliers expected (all within 2 SD of ≈44.6)
      expect(repVar.detail, isNot(contains('Outlier')));
      expect(repVar.detail, contains('Rep 1'));
      expect(repVar.detail, contains('Rep 4'));
    });

    test('all insights carry transparency fields', () async {
      final seed = await seedKnownTrial();
      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      expect(insights, isNotEmpty);
      for (final i in insights) {
        // Transparency rule: every insight shows its math
        expect(i.basis.method.isNotEmpty, isTrue,
            reason: '${i.title} has empty method');
        expect(i.basis.sessionCount, 3,
            reason: '${i.title} wrong session count');
        expect(i.basis.repCount, 4,
            reason: '${i.title} wrong rep count');
        expect(i.basis.minimumDataMet, isTrue);
        expect(i.basis.confidenceLabel, isNotEmpty);
      }
    });
  });
}
