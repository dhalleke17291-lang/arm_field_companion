import 'package:arm_field_companion/core/database/app_database.dart';
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

/// Sprint 4.3 — Scale stress test at 200 treatments × 10 reps (2000 plots).
///
/// Performance targets (in-memory SQLite):
///   Import:           < 30 s
///   Session creation: < 2 s
///   Bulk rating:      < 30 s (2000 ratings per session)
///   Query all plots:  < 1 s
///   Export CSV:       < 10 s
void main() {
  const treatmentCount = 200;
  const repCount = 10;
  const plotCount = treatmentCount * repCount; // 2000
  const assessmentCount = 3;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  String buildLargeCsv() {
    final headers = <String>[
      'Plot No.',
      'trt',
      'reps',
    ];
    for (var a = 1; a <= assessmentCount; a++) {
      headers.add('WEED$a 1-Jul-26 CONTRO %');
    }

    final rows = <String>[headers.join(',')];
    var plotNum = 101;
    for (var rep = 1; rep <= repCount; rep++) {
      for (var trt = 1; trt <= treatmentCount; trt++) {
        final cols = <String>[
          '$plotNum',
          '$trt',
          '$rep',
        ];
        for (var a = 0; a < assessmentCount; a++) {
          cols.add('${(trt * 3 + a * 7 + rep) % 100}');
        }
        rows.add(cols.join(','));
        plotNum++;
      }
    }
    return rows.join('\n');
  }

  group('Sprint 4.3 — 200×10 scale stress', () {
    late int trialId;
    late int importSessionId;

    test('import 2000 plots completes within target', () async {
      final csv = buildLargeCsv();

      final sw = Stopwatch()..start();
      final result = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_200x10.csv');
      sw.stop();

      expect(result.success, isTrue, reason: result.errorMessage ?? '');
      trialId = result.trialId!;
      importSessionId = result.importSessionId!;

      final plots = await (db.select(db.plots)
            ..where(
                (p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, plotCount);

      final treatments = await (db.select(db.treatments)
            ..where(
                (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false)))
          .get();
      expect(treatments.length, treatmentCount);

      final ratings = await (db.select(db.ratingRecords)
            ..where((r) =>
                r.trialId.equals(trialId) &
                r.sessionId.equals(importSessionId)))
          .get();
      expect(ratings.length, plotCount * assessmentCount);

      // ignore: avoid_print
      print('Import 2000 plots: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inSeconds, lessThan(30),
          reason: 'Import took ${sw.elapsed}');
    });

    test('query all plots within target', () async {
      final csv = buildLargeCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_query.csv');
      trialId = r.trialId!;

      final sw = Stopwatch()..start();
      final plots = await PlotRepository(db).getPlotsForTrial(trialId);
      sw.stop();

      expect(plots.length, plotCount);
      // ignore: avoid_print
      print('Query $plotCount plots: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inMilliseconds, lessThan(1000));
    });

    test('create session + rate 2000 plots within target', () async {
      final csv = buildLargeCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_rate.csv');
      trialId = r.trialId!;
      importSessionId = r.importSessionId!;

      await SessionRepository(db).closeSession(importSessionId);

      final importRatings = await (db.select(db.ratingRecords)
            ..where((rr) =>
                rr.trialId.equals(trialId) &
                rr.sessionId.equals(importSessionId)))
          .get();
      final assessmentIds =
          importRatings.map((rr) => rr.assessmentId).toSet().toList();
      expect(assessmentIds.length, assessmentCount);

      final sessionDateLocal =
          await sessionDateLocalValidForTrial(db, trialId);

      final swSession = Stopwatch()..start();
      final session = await SessionRepository(db).createSession(
        trialId: trialId,
        name: 'Field rating 2',
        sessionDateLocal: sessionDateLocal,
        assessmentIds: assessmentIds,
      );
      swSession.stop();
      // ignore: avoid_print
      print('Create session: ${swSession.elapsedMilliseconds} ms');
      expect(swSession.elapsed.inSeconds, lessThan(2));

      final plots = await PlotRepository(db).getPlotsForTrial(trialId);
      expect(plots.length, plotCount);

      final saveUseCase = SaveRatingUseCase(
        RatingRepository(db),
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db, AssignmentRepository(db)),
        ),
      );

      final swRate = Stopwatch()..start();
      for (final plot in plots) {
        for (final aid in assessmentIds) {
          final res = await saveUseCase.execute(
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
              reason: 'Plot ${plot.plotId}, assessment $aid: ${res.errorMessage}');
        }
      }
      swRate.stop();
      // ignore: avoid_print
      print(
          'Rate ${plotCount * assessmentCount} cells: ${swRate.elapsedMilliseconds} ms');
      expect(swRate.elapsed.inSeconds, lessThan(30),
          reason: 'Bulk rating took ${swRate.elapsed}');

      final s2Ratings = await (db.select(db.ratingRecords)
            ..where((rr) =>
                rr.trialId.equals(trialId) &
                rr.sessionId.equals(session.id) &
                rr.isCurrent.equals(true)))
          .get();
      expect(s2Ratings.length, plotCount * assessmentCount);
    });

    test('export CSV at 2000-plot scale within target', () async {
      final csv = buildLargeCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_export.csv');
      trialId = r.trialId!;

      final trial = await (db.select(db.trials)
            ..where((t) => t.id.equals(trialId)))
          .getSingle();

      final sw = Stopwatch()..start();
      final bundle = await exportStressTrialUseCase(db)
          .execute(trial: trial, format: ExportFormat.flatCsv);
      sw.stop();

      expect(bundle.observationsCsv.isNotEmpty, isTrue);
      final lineCount = bundle.observationsCsv.split('\n').length;
      expect(lineCount, greaterThan(plotCount));
      // ignore: avoid_print
      print(
          'Export CSV ($lineCount lines): ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inSeconds, lessThan(10),
          reason: 'Export took ${sw.elapsed}');
    });

    test('treatment stats query at scale', () async {
      final csv = buildLargeCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_stats.csv');
      trialId = r.trialId!;
      importSessionId = r.importSessionId!;

      final treatments = await TreatmentRepository(
              db, AssignmentRepository(db))
          .getTreatmentsForTrial(trialId);
      final assignments = await AssignmentRepository(db).getForTrial(trialId);
      final ratings = await RatingRepository(db)
          .getCurrentRatingsForSession(importSessionId);

      final sw = Stopwatch()..start();
      final plotToTreatment = <int, int>{};
      for (final a in assignments) {
        if (a.treatmentId != null) {
          plotToTreatment[a.plotId] = a.treatmentId!;
        }
      }
      final treatmentMeans = <int, List<double>>{};
      for (final r in ratings) {
        final tid = plotToTreatment[r.plotPk];
        if (tid != null && r.numericValue != null) {
          treatmentMeans.putIfAbsent(tid, () => []).add(r.numericValue!);
        }
      }
      final means = treatmentMeans.map((tid, vals) =>
          MapEntry(tid, vals.reduce((a, b) => a + b) / vals.length));
      sw.stop();

      expect(means.length, treatmentCount);
      expect(means.values.every((m) => m >= 0 && m < 100), isTrue);
      // ignore: avoid_print
      print(
          'Treatment stats (${treatments.length} treatments): ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsed.inMilliseconds, lessThan(500));
    });

    test('data integrity across 2 sessions', () async {
      final csv = buildLargeCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'scale_integrity.csv');
      trialId = r.trialId!;
      importSessionId = r.importSessionId!;

      await SessionRepository(db).closeSession(importSessionId);

      final s1Ratings = await RatingRepository(db)
          .getCurrentRatingsForSession(importSessionId);
      final assessmentIds =
          s1Ratings.map((rr) => rr.assessmentId).toSet().toList();

      final session2 = await SessionRepository(db).createSession(
        trialId: trialId,
        name: 'Session 2',
        sessionDateLocal:
            await sessionDateLocalValidForTrial(db, trialId),
        assessmentIds: assessmentIds,
      );

      final plots = await PlotRepository(db).getPlotsForTrial(trialId);
      final save = SaveRatingUseCase(
        RatingRepository(db),
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db, AssignmentRepository(db)),
        ),
      );

      for (final plot in plots.take(50)) {
        await save.execute(SaveRatingInput(
          trialId: trialId,
          plotPk: plot.id,
          assessmentId: assessmentIds.first,
          sessionId: session2.id,
          resultStatus: 'RECORDED',
          numericValue: 99.0,
          textValue: null,
          isSessionClosed: false,
        ));
      }

      final s1Current = await RatingRepository(db)
          .getCurrentRatingsForSession(importSessionId);
      expect(s1Current.length, plotCount * assessmentCount,
          reason: 'Session 1 ratings must be untouched');

      final s2Current = await RatingRepository(db)
          .getCurrentRatingsForSession(session2.id);
      expect(s2Current.length, 50);
      expect(s2Current.every((r) => r.numericValue == 99.0), isTrue);
    });
  });
}
