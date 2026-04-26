import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/domain/intelligence/trial_intelligence_service.dart';
import 'package:arm_field_companion/domain/models/trial_insight.dart';
import 'package:arm_field_companion/features/export/export_trial_json_usecase.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/session_summary_share.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_date_test_utils.dart';
import '../../stress/stress_import_helpers.dart';

TrialIntelligenceService _buildService(AppDatabase db) {
  final assignmentRepo = AssignmentRepository(db);
  return TrialIntelligenceService(
    sessionRepository: SessionRepository(db),
    ratingRepository: RatingRepository(db),
    plotRepository: PlotRepository(db),
    assignmentRepository: assignmentRepo,
    treatmentRepository: TreatmentRepository(db, assignmentRepo),
    weatherSnapshotRepository: WeatherSnapshotRepository(db),
  );
}

ExportTrialJsonUseCase _buildJsonExport(AppDatabase db) {
  final assignmentRepo = AssignmentRepository(db);
  final treatmentRepo = TreatmentRepository(db, assignmentRepo);
  return ExportTrialJsonUseCase(
    plotRepository: PlotRepository(db),
    treatmentRepository: treatmentRepo,
    applicationRepository: ApplicationRepository(db),
    applicationProductRepository: ApplicationProductRepository(db),
    sessionRepository: SessionRepository(db),
    assignmentRepository: assignmentRepo,
    ratingRepository: RatingRepository(db),
    notesRepository: NotesRepository(db),
    photoRepository: PhotoRepository(db),
    weatherSnapshotRepository: WeatherSnapshotRepository(db),
    intelligenceService: _buildService(db),
  );
}

Future<({int trialId, List<Treatment> treatments})> _seedTrial(
  AppDatabase db, {
  int treatmentCount = 4,
  int reps = 4,
  int sessionCount = 3,
  bool markCheck = true,
}) async {
  final headers = ['Plot No.', 'trt', 'reps', 'WEED1 1-Jul-26 CONTRO %'];
  final rows = <String>[headers.join(',')];
  var plotNum = 101;
  for (var rep = 1; rep <= reps; rep++) {
    for (var trt = 1; trt <= treatmentCount; trt++) {
      rows.add('$plotNum,$trt,$rep,${trt * 10 + rep}');
      plotNum++;
    }
  }
  final r = await stressArmImportUseCase(db)
      .execute(rows.join('\n'), sourceFileName: 'polish_test.csv');
  expect(r.success, isTrue);
  final trialId = r.trialId!;
  final importSessionId = r.importSessionId!;

  if (markCheck) {
    var treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);
    treatments.sort((a, b) => a.code.compareTo(b.code));
    await (db.update(db.treatments)
          ..where((t) => t.id.equals(treatments.first.id)))
        .write(const TreatmentsCompanion(code: Value('CHK')));
  }

  await SessionRepository(db).closeSession(importSessionId);

  final importRatings = await RatingRepository(db)
      .getCurrentRatingsForSession(importSessionId);
  final assessmentIds =
      importRatings.map((rr) => rr.assessmentId).toSet().toList();
  final plots = await PlotRepository(db).getPlotsForTrial(trialId);
  final save = SaveRatingUseCase(
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
      sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
      assessmentIds: assessmentIds,
    );
    for (final plot in plots) {
      for (final aid in assessmentIds) {
        await save.execute(SaveRatingInput(
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

  final treatments =
      await TreatmentRepository(db, AssignmentRepository(db))
          .getTreatmentsForTrial(trialId);
  return (trialId: trialId, treatments: treatments);
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

  // ===== Edge Cases =====

  group('edge cases', () {
    test('trial with 0 sessions produces 0 insights', () async {
      const csv = 'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,50\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'edge0.csv');
      final trialId = r.trialId!;
      final treatments =
          await TreatmentRepository(db, AssignmentRepository(db))
              .getTreatmentsForTrial(trialId);
      final insights = await _buildService(db)
          .computeInsights(trialId: trialId, treatments: treatments);
      final closedAnalytics = insights
          .where((i) => i.type != InsightType.sessionFieldCapture)
          .toList();
      expect(closedAnalytics, isEmpty);
    });

    test('trial with 1 closed session: trends not generated', () async {
      final seed = await _seedTrial(db, sessionCount: 1);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      expect(
        insights.where((i) => i.type == InsightType.treatmentTrend),
        isEmpty,
        reason: 'Treatment trends need 2+ sessions',
      );
      expect(
        insights.where((i) => i.type == InsightType.trialHealth),
        isEmpty,
        reason: 'Trial health needs 3+ sessions',
      );
      expect(
        insights.where((i) => i.type == InsightType.plotAnomaly),
        isEmpty,
        reason: 'Plot anomaly needs 2+ sessions',
      );
    });

    test('trial with no check treatment: check-dependent insights skipped',
        () async {
      final seed =
          await _seedTrial(db, sessionCount: 3, markCheck: false);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      expect(
        insights.where((i) => i.type == InsightType.trialHealth),
        isEmpty,
      );
      expect(
        insights.where((i) => i.type == InsightType.checkTrend),
        isEmpty,
      );
    });

    test('trial with no applications: DAT not computed, no crash', () async {
      final seed = await _seedTrial(db, sessionCount: 2);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();
      // Session summary should work without applications
      final sessions =
          await SessionRepository(db).getSessionsForTrial(seed.trialId);
      final assessments = sessions.isNotEmpty
          ? await SessionRepository(db)
              .getSessionAssessments(sessions.first.id)
          : <Assessment>[];
      final ratings = sessions.isNotEmpty
          ? await RatingRepository(db)
              .getCurrentRatingsForSession(sessions.first.id)
          : <RatingRecord>[];
      final treatments =
          await TreatmentRepository(db, AssignmentRepository(db))
              .getTreatmentsForTrial(seed.trialId);
      final assignments =
          await AssignmentRepository(db).getForTrial(seed.trialId);
      final plots = await PlotRepository(db).getPlotsForTrial(seed.trialId);

      final text = composeSessionSummary(
        trial: trial,
        session: sessions.first,
        plots: plots,
        assessments: assessments,
        ratings: ratings,
        treatments: treatments,
        assignments: assignments,
      );
      expect(text, contains(trial.name));
      expect(text, isNot(contains('DAT')));
    });

    test('session with all identical values: CV=0, no drift, no division error',
        () async {
      const csv =
          'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n'
          '101,1,1,50\n102,1,2,50\n103,1,3,50\n104,1,4,50\n'
          '105,2,1,50\n106,2,2,50\n107,2,3,50\n108,2,4,50\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'edge_identical.csv');
      expect(r.success, isTrue);
      await SessionRepository(db).closeSession(r.importSessionId!);

      final treatments =
          await TreatmentRepository(db, AssignmentRepository(db))
              .getTreatmentsForTrial(r.trialId!);
      final insights = await _buildService(db)
          .computeInsights(trialId: r.trialId!, treatments: treatments);
      // Should not crash with division by zero
      for (final i in insights) {
        expect(i.detail, isNot(contains('NaN')));
        expect(i.detail, isNot(contains('Infinity')));
      }
    });

    test('trial with 2 reps: rep variability not generated', () async {
      final seed = await _seedTrial(db, reps: 2, sessionCount: 2);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      expect(
        insights.where((i) => i.type == InsightType.repVariability),
        isEmpty,
        reason: 'Rep variability needs 3+ reps',
      );
    });
  });

  // ===== Transparency Compliance =====

  group('transparency compliance (full sweep)', () {
    test('no insight detail contains causal language', () async {
      final seed = await _seedTrial(db, sessionCount: 5, reps: 6);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      expect(insights, isNotEmpty, reason: 'Need insights to test');

      const forbidden = [
        'caused', 'resulted in', 'due to', 'because of', 'led to',
        'confirmed', 'is working', 'healthy', 'concerning',
      ];
      for (final i in insights) {
        for (final word in forbidden) {
          expect(
            i.detail.toLowerCase().contains(word),
            isFalse,
            reason: '${i.title} contains forbidden "$word": "${i.detail}"',
          );
          expect(
            i.title.toLowerCase().contains(word),
            isFalse,
            reason: 'Title "${i.title}" contains forbidden "$word"',
          );
        }
      }
    });

    test('every insight detail contains at least one number', () async {
      final seed = await _seedTrial(db, sessionCount: 4, reps: 5);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      for (final i in insights) {
        expect(
          RegExp(r'\d').hasMatch(i.detail),
          isTrue,
          reason: '${i.title}: detail has no numbers — "${i.detail}"',
        );
      }
    });

    test('every insight has complete InsightBasis', () async {
      final seed = await _seedTrial(db, sessionCount: 4, reps: 5);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      for (final i in insights) {
        expect(i.basis.method, isNotEmpty,
            reason: '${i.title}: empty method');
        expect(i.basis.minimumDataMet, isTrue,
            reason: '${i.title}: returned below minimum');
      }
    });

    test('no insight uses percentages of percentages', () async {
      final seed = await _seedTrial(db, sessionCount: 4, reps: 5);
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      for (final i in insights) {
        expect(
          i.detail.contains('% improvement'),
          isFalse,
          reason: '${i.title}: uses "% improvement" — use absolute points',
        );
        expect(
          i.detail.contains('% increase'),
          isFalse,
          reason: '${i.title}: uses "% increase" — use absolute points',
        );
      }
    });
  });

  // ===== Performance =====

  group('performance at scale', () {
    test('intelligence computation <2s at 200x10', () async {
      final seed = await _seedTrial(db,
          treatmentCount: 10, reps: 10, sessionCount: 3);

      final sw = Stopwatch()..start();
      final insights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      sw.stop();

      expect(insights, isNotEmpty);
      // ignore: avoid_print
      print('Intelligence computation (10×10×3): ${sw.elapsedMilliseconds} ms, '
          '${insights.length} insights');
      expect(sw.elapsed.inSeconds, lessThan(2),
          reason: 'Intelligence took ${sw.elapsed}');
    });

    test('JSON export <5s at 200x10 scale', () async {
      final seed = await _seedTrial(db,
          treatmentCount: 10, reps: 10, sessionCount: 3);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();

      final sw = Stopwatch()..start();
      final jsonStr = await _buildJsonExport(db).buildJson(trial: trial);
      sw.stop();

      expect(jsonStr, isNotEmpty);
      final parsed = json.decode(jsonStr);
      expect(parsed, isA<Map>());
      // ignore: avoid_print
      print('JSON export (10×10×3): ${sw.elapsedMilliseconds} ms, '
          '${jsonStr.length} chars');
      expect(sw.elapsed.inSeconds, lessThan(5),
          reason: 'JSON export took ${sw.elapsed}');
    });

    test('session summary compose <100ms', () async {
      final seed = await _seedTrial(db, treatmentCount: 10, reps: 10);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();
      final sessions =
          await SessionRepository(db).getSessionsForTrial(seed.trialId);
      final plots = await PlotRepository(db).getPlotsForTrial(seed.trialId);
      final assessments =
          await SessionRepository(db).getSessionAssessments(sessions.first.id);
      final ratings = await RatingRepository(db)
          .getCurrentRatingsForSession(sessions.first.id);
      final treatments = seed.treatments;
      final assignments =
          await AssignmentRepository(db).getForTrial(seed.trialId);

      final sw = Stopwatch()..start();
      final text = composeSessionSummary(
        trial: trial,
        session: sessions.first,
        plots: plots,
        assessments: assessments,
        ratings: ratings,
        treatments: treatments,
        assignments: assignments,
      );
      sw.stop();

      expect(text, isNotEmpty);
      // ignore: avoid_print
      print('Session summary compose: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inMilliseconds, lessThan(100));
    });
  });

  // ===== JSON Export Validation =====

  group('JSON export completeness', () {
    test('all sections present, empty arrays not missing keys', () async {
      final seed = await _seedTrial(db, sessionCount: 2);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();
      final jsonStr = await _buildJsonExport(db).buildJson(trial: trial);
      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      final trialData = parsed['trial'] as Map<String, dynamic>;

      final requiredKeys = [
        'name', 'site', 'design', 'treatments', 'applications',
        'sessions', 'fieldNotes', 'photosManifest', 'completeness',
        'insights',
      ];
      for (final key in requiredKeys) {
        expect(trialData.containsKey(key), isTrue,
            reason: 'Missing key: $key');
      }
    });

    test('insights in JSON match computed insights', () async {
      final seed = await _seedTrial(db, sessionCount: 3, reps: 5);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();

      final directInsights = await _buildService(db)
          .computeInsights(trialId: seed.trialId, treatments: seed.treatments);
      final jsonStr = await _buildJsonExport(db).buildJson(trial: trial);
      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      final jsonInsights =
          (parsed['trial'] as Map)['insights'] as List;

      expect(jsonInsights.length, directInsights.length,
          reason: 'JSON insight count should match direct computation');
    });

    test('JSON is valid parseable JSON', () async {
      final seed = await _seedTrial(db, sessionCount: 2);
      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(seed.trialId)))
          .getSingle();
      final jsonStr = await _buildJsonExport(db).buildJson(trial: trial);

      // Must not throw
      final parsed = json.decode(jsonStr);
      expect(parsed, isA<Map>());

      // Round-trip: re-encode and re-parse
      final reEncoded = json.encode(parsed);
      final reParsed = json.decode(reEncoded);
      expect(reParsed, isA<Map>());
    });
  });
}
