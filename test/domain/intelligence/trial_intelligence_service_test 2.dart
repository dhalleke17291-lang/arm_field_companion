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

  /// Creates a trial with treatments (including a check), plots, and
  /// multiple sessions with ratings. Returns trial ID and treatment list.
  Future<({int trialId, List<Treatment> treatments})> seedTrial({
    int treatmentCount = 4,
    int repsPerTreatment = 4,
    int sessionCount = 3,
    bool includeCheck = true,
  }) async {
    // Import a base CSV to get the trial structure
    final headers = <String>['Plot No.', 'trt', 'reps', 'WEED1 1-Jul-26 CONTRO %'];
    final rows = <String>[headers.join(',')];
    var plotNum = 101;
    for (var rep = 1; rep <= repsPerTreatment; rep++) {
      for (var trt = 1; trt <= treatmentCount; trt++) {
        rows.add('$plotNum,$trt,$rep,${trt * 10 + rep}');
        plotNum++;
      }
    }
    final csv = rows.join('\n');

    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'intel_test.csv');
    expect(r.success, isTrue);
    final trialId = r.trialId!;
    final importSessionId = r.importSessionId!;

    // Mark first treatment as CHK if requested
    var treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);
    if (includeCheck && treatments.isNotEmpty) {
      final chk = treatments.first;
      await (db.update(db.treatments)
            ..where((t) => t.id.equals(chk.id)))
          .write(const TreatmentsCompanion(code: drift.Value('CHK')));
      treatments =
          await TreatmentRepository(db, AssignmentRepository(db))
              .getTreatmentsForTrial(trialId);
    }

    // Close the import session
    await SessionRepository(db).closeSession(importSessionId);

    // Get assessment IDs from import ratings
    final importRatings = await RatingRepository(db)
        .getCurrentRatingsForSession(importSessionId);
    final assessmentIds =
        importRatings.map((rr) => rr.assessmentId).toSet().toList();

    // Create additional sessions with ratings
    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    final saveUseCase = SaveRatingUseCase(
      RatingRepository(db),
      RatingIntegrityGuard(
        PlotRepository(db),
        SessionRepository(db),
        TreatmentRepository(db, AssignmentRepository(db)),
      ),
    );

    for (var s = 1; s < sessionCount; s++) {
      final session = await SessionRepository(db).createSession(
        trialId: trialId,
        name: 'Session ${s + 1}',
        sessionDateLocal:
            await sessionDateLocalValidForTrial(db, trialId),
        assessmentIds: assessmentIds,
      );
      for (final plot in plots) {
        for (final aid in assessmentIds) {
          await saveUseCase.execute(SaveRatingInput(
            trialId: trialId,
            plotPk: plot.id,
            assessmentId: aid,
            sessionId: session.id,
            resultStatus: 'RECORDED',
            numericValue: (plot.id * 7 + aid * 3 + s * 10) % 100,
            textValue: null,
            isSessionClosed: false,
          ));
        }
      }
      await SessionRepository(db).closeSession(session.id);
    }

    return (trialId: trialId, treatments: treatments);
  }

  group('TrialIntelligenceService', () {
    test('no closed-session analytics when only open session exists', () async {
      const csv = 'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,50\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'empty.csv');
      final trialId = r.trialId!;
      // Session is still open (not closed)
      final treatments =
          await TreatmentRepository(db, AssignmentRepository(db))
              .getTreatmentsForTrial(trialId);

      final insights = await service.computeInsights(
        trialId: trialId,
        treatments: treatments,
      );
      final closedOnly = insights
          .where((i) => i.type != InsightType.sessionFieldCapture)
          .toList();
      expect(closedOnly, isEmpty);
      if (insights.isNotEmpty) {
        expect(insights.first.type, InsightType.sessionFieldCapture);
      }
    });

    test('trial health appears with 3+ sessions and check treatment',
        () async {
      final seed = await seedTrial(
        treatmentCount: 4,
        repsPerTreatment: 4,
        sessionCount: 3,
        includeCheck: true,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final healthInsights =
          insights.where((i) => i.type == InsightType.trialHealth).toList();
      expect(healthInsights, isNotEmpty);

      final health = healthInsights.first;
      expect(health.title, 'Trial health');
      expect(health.detail, contains('Effect size'));
      expect(health.detail, contains('CV'));
      expect(health.basis.minimumDataMet, isTrue);
      expect(health.basis.sessionCount, 3);
      expect(health.basis.repCount, 4);
      expect(health.basis.method, contains('check mean'));
    });

    test('trial health absent without check treatment', () async {
      final seed = await seedTrial(
        treatmentCount: 4,
        repsPerTreatment: 4,
        sessionCount: 3,
        includeCheck: false,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final healthInsights =
          insights.where((i) => i.type == InsightType.trialHealth);
      expect(healthInsights, isEmpty);
    });

    test('treatment trends appear with 2+ sessions', () async {
      final seed = await seedTrial(
        treatmentCount: 3,
        repsPerTreatment: 3,
        sessionCount: 3,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final trends =
          insights.where((i) => i.type == InsightType.treatmentTrend).toList();
      expect(trends, isNotEmpty);
      expect(trends.first.detail, contains('→'));
      expect(trends.first.detail, contains('points'));
      expect(trends.first.basis.method, contains('mean per treatment'));
    });

    test('check trend appears with 2+ sessions and check treatment',
        () async {
      final seed = await seedTrial(
        treatmentCount: 3,
        repsPerTreatment: 3,
        sessionCount: 3,
        includeCheck: true,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final checkTrends =
          insights.where((i) => i.type == InsightType.checkTrend).toList();
      expect(checkTrends, isNotEmpty);
      expect(checkTrends.first.detail, contains('Untreated check'));
      expect(checkTrends.first.detail, contains('Direction'));
    });

    test('rep variability appears with 3+ reps', () async {
      final seed = await seedTrial(
        treatmentCount: 3,
        repsPerTreatment: 5,
        sessionCount: 2,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final repInsights =
          insights.where((i) => i.type == InsightType.repVariability).toList();
      expect(repInsights, isNotEmpty);
      expect(repInsights.first.detail, contains('Rep'));
      expect(repInsights.first.basis.method, contains('mean per rep'));
    });

    test('rep variability absent with <3 reps', () async {
      final seed = await seedTrial(
        treatmentCount: 3,
        repsPerTreatment: 2,
        sessionCount: 2,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      final repInsights =
          insights.where((i) => i.type == InsightType.repVariability);
      expect(repInsights, isEmpty);
    });

    test('every insight has basis with method', () async {
      final seed = await seedTrial(
        treatmentCount: 4,
        repsPerTreatment: 4,
        sessionCount: 4,
        includeCheck: true,
      );

      final insights = await service.computeInsights(
        trialId: seed.trialId,
        treatments: seed.treatments,
      );

      for (final insight in insights) {
        expect(insight.basis.method, isNotEmpty,
            reason: '${insight.title} missing method');
        expect(insight.basis.sessionCount, greaterThan(0),
            reason: '${insight.title} has zero sessions');
        expect(insight.basis.minimumDataMet, isTrue,
            reason: '${insight.title} below minimum but was returned');
      }
    });
  });
}
