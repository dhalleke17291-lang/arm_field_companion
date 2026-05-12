/// Integration tests for [EvidenceReportAssemblyService].
///
/// Pins the six logical sections of the Evidence Report:
///   1. Identity — trial fields + derived counts
///   2. Timeline — sorted event log
///   3. Sessions — per-session aggregates
///   4. Data integrity — totals, rater summaries, provenance coverage
///   5. Outlier detection — 2-SD threshold, minimum-sample guard
///   6. Completeness score — each scoring dimension
///
/// Uses an in-memory database; all setup goes through raw Drift companions
/// to bypass protocol guards that are exercised by their own tests elsewhere.
library;

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/features/export/evidence_report_assembly_service.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EvidenceReportAssemblyService svc;
  late int trialId;
  late Trial trial;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = EvidenceReportAssemblyService(
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db),
      applicationRepository: ApplicationRepository(db),
      sessionRepository: SessionRepository(db),
      assignmentRepository: AssignmentRepository(db),
      ratingRepository: RatingRepository(db),
      weatherSnapshotRepository: WeatherSnapshotRepository(db),
      seedingRepository: SeedingRepository(db),
      photoRepository: PhotoRepository(db),
      signalRepository: SignalRepository.attach(db),
      db: db,
    );
    trialId = await TrialRepository(db)
        .createTrial(name: 'Herbicide T', workspaceType: 'efficacy');
    trial = (await TrialRepository(db).getTrialById(trialId))!;
  });

  tearDown(() => db.close());

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<int> plot(String plotId, {int? rep, int? treatmentId}) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            rep: Value(rep),
            treatmentId: Value(treatmentId),
          ));

  Future<int> treatment(String code) =>
      db.into(db.treatments).insert(TreatmentsCompanion.insert(
            trialId: trialId,
            code: code,
            name: code,
          ));

  Future<int> assessment(String name) =>
      db.into(db.assessments).insert(AssessmentsCompanion.insert(
            trialId: trialId,
            name: name,
          ));

  Future<int> session(
    String name, {
    DateTime? endedAt,
    int? bbch,
    String sessionDateLocal = '2026-03-01',
  }) =>
      db.into(db.sessions).insert(SessionsCompanion.insert(
            trialId: trialId,
            name: name,
            sessionDateLocal: sessionDateLocal,
            endedAt: Value(endedAt),
            cropStageBbch: Value(bbch),
          ));

  Future<int> application(DateTime applicationDate) =>
      db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion.insert(
              trialId: trialId,
              applicationDate: applicationDate,
              status: const Value('applied'),
            ),
          );

  Future<void> rating(
    int plotPk,
    int assessId,
    int sessionId, {
    double? value,
    String? rater,
    double? lat,
    double? lng,
    String? confidence,
    String? ratingTime,
    bool amended = false,
  }) =>
      db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessId,
            sessionId: sessionId,
            numericValue: Value(value),
            raterName: Value(rater),
            capturedLatitude: Value(lat),
            capturedLongitude: Value(lng),
            confidence: Value(confidence),
            ratingTime: Value(ratingTime),
            amended: Value(amended),
          ));

  // ── 1. Identity section ────────────────────────────────────────────────────

  group('identity', () {
    test('maps trial name and workspace type', () async {
      final data = await svc.assembleForTrial(trial);
      expect(data.identity.name, 'Herbicide T');
      expect(data.identity.workspaceType, 'efficacy');
    });

    test('counts plots, treatments, and unique reps', () async {
      final t1 = await treatment('CHK');
      final t2 = await treatment('T2');
      await plot('101', rep: 1, treatmentId: t1);
      await plot('102', rep: 1, treatmentId: t2);
      await plot('201', rep: 2, treatmentId: t1);
      await plot('202', rep: 2, treatmentId: t2);

      final data = await svc.assembleForTrial(trial);
      expect(data.identity.plotCount, 4);
      expect(data.identity.treatmentCount, 2);
      expect(data.identity.repCount, 2);
    });

    test('repCount is null when no plots have rep set', () async {
      await plot('101'); // rep is null
      final data = await svc.assembleForTrial(trial);
      expect(data.identity.repCount, isNull);
    });

    test('empty trial returns zero counts', () async {
      final data = await svc.assembleForTrial(trial);
      expect(data.identity.plotCount, 0);
      expect(data.identity.treatmentCount, 0);
      expect(data.sessions, isEmpty);
      expect(data.integrity.totalRatings, 0);
    });
  });

  // ── 2. Timeline ────────────────────────────────────────────────────────────

  group('timeline', () {
    test('always includes trial-created event', () async {
      final data = await svc.assembleForTrial(trial);
      expect(data.timeline.map((e) => e.label), contains('Trial created'));
    });

    test('includes session-opened and session-closed events', () async {
      await session('S1');
      await session('S2', endedAt: DateTime(2026, 3, 10, 17));

      final data = await svc.assembleForTrial(trial);
      final labels = data.timeline.map((e) => e.label).toList();
      expect(labels, containsAll(['Session opened: S1', 'Session opened: S2']));
      expect(labels, contains('Session closed: S2'));
      expect(labels, isNot(contains('Session closed: S1')));
    });

    test('timeline is sorted ascending by date', () async {
      await session('S1');
      await session('S2');

      final data = await svc.assembleForTrial(trial);
      for (var i = 0; i < data.timeline.length - 1; i++) {
        expect(
          data.timeline[i].date.isBefore(data.timeline[i + 1].date) ||
              data.timeline[i]
                  .date
                  .isAtSameMomentAs(data.timeline[i + 1].date),
          isTrue,
          reason: 'Timeline not sorted at index $i',
        );
      }
    });
  });

  // ── 3. Sessions section ────────────────────────────────────────────────────

  group('sessions', () {
    test('counts distinct plots rated per session', () async {
      final p1 = await plot('101', rep: 1);
      final p2 = await plot('102', rep: 1);
      final a = await assessment('Weed Control');
      final s = await session('S1');
      await rating(p1, a, s, value: 85);
      await rating(p2, a, s, value: 70);

      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.plotsRated, 2);
    });

    test('counts unique assessments rated in session', () async {
      final p = await plot('101', rep: 1);
      final a1 = await assessment('Weed Control');
      final a2 = await assessment('Phytotoxicity');
      final s = await session('S1');
      await rating(p, a1, s, value: 80);
      await rating(p, a2, s, value: 5);

      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.assessmentCount, 2);
      expect(data.sessions.single.totalRatings, 2);
    });

    test('counts edited plots (amended ratings)', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 80, amended: true);

      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.plotsEdited, 1);
    });

    test('status is closed when endedAt is set', () async {
      await session('S1', endedAt: DateTime(2026, 3, 1, 17));
      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.status, 'closed');
    });

    test('status is open when endedAt is null', () async {
      await session('S1');
      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.status, 'open');
    });

    test('cropStageBbch propagated from session row', () async {
      await session('S1', bbch: 65);
      final data = await svc.assembleForTrial(trial);
      expect(data.sessions.single.cropStageBbch, 65);
    });
  });

  // ── 4. Data Integrity ──────────────────────────────────────────────────────

  group('integrity', () {
    test('counts total ratings across all sessions', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s1 = await session('S1');
      final s2 = await session('S2');
      await rating(p, a, s1, value: 80);
      await rating(p, a, s2, value: 82);

      final data = await svc.assembleForTrial(trial);
      expect(data.integrity.totalRatings, 2);
    });

    test('counts GPS, confidence, and timestamp coverage', () async {
      final p1 = await plot('101', rep: 1);
      final p2 = await plot('102', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      // First rating: full provenance
      await rating(p1, a, s,
          value: 80,
          lat: 51.0,
          lng: -1.0,
          confidence: 'certain',
          ratingTime: '09:30');
      // Second rating: no provenance (different plot → different unique key)
      await rating(p2, a, s, value: 75);

      final data = await svc.assembleForTrial(trial);
      expect(data.integrity.ratingsWithGps, 1);
      expect(data.integrity.ratingsWithConfidence, 1);
      expect(data.integrity.ratingsWithTimestamp, 1);
    });

    test('builds rater summaries with correct rating counts', () async {
      final p1 = await plot('101', rep: 1);
      final p2 = await plot('102', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p1, a, s, value: 80, rater: 'Alice');
      await rating(p2, a, s, value: 70, rater: 'Alice');

      final data = await svc.assembleForTrial(trial);
      expect(data.integrity.raterSummaries, hasLength(1));
      expect(data.integrity.raterSummaries.single.name, 'Alice');
      expect(data.integrity.raterSummaries.single.ratingCount, 2);
    });

    test('multiple raters produce separate summaries', () async {
      final p1 = await plot('101', rep: 1);
      final p2 = await plot('102', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p1, a, s, value: 80, rater: 'Alice');
      await rating(p2, a, s, value: 70, rater: 'Bob');

      final data = await svc.assembleForTrial(trial);
      final names = data.integrity.raterSummaries.map((r) => r.name).toSet();
      expect(names, containsAll(['Alice', 'Bob']));
    });

    test('marks rater drift when signal exists for a participated session',
        () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      const consequence =
          'Variability noted during session close review for this rater.';
      await rating(p, a, s, value: 80, rater: 'Alice');
      await SignalRepository.attach(db).raiseSignal(
        trialId: trialId,
        sessionId: s,
        signalType: SignalType.raterDrift,
        moment: SignalMoment.three,
        severity: SignalSeverity.review,
        referenceContext: const SignalReferenceContext(),
        consequenceText: consequence,
      );

      final data = await svc.assembleForTrial(trial);
      final rater =
          data.integrity.raterSummaries.firstWhere((r) => r.name == 'Alice');
      expect(rater.raterDriftDetected, isTrue);
      expect(rater.driftSeverity, SignalSeverity.review.dbValue);
      expect(rater.driftConsequence, consequence);
    });

    test('does not mark rater drift when no rater signals exist', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 80, rater: 'Alice');

      final data = await svc.assembleForTrial(trial);
      final rater =
          data.integrity.raterSummaries.firstWhere((r) => r.name == 'Alice');
      expect(rater.raterDriftDetected, isFalse);
      expect(rater.driftSeverity, isNull);
      expect(rater.driftConsequence, isNull);
    });

    test('records amendments in integrity section', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 85, amended: true);

      final data = await svc.assembleForTrial(trial);
      expect(data.integrity.amendments, hasLength(1));
    });

    test('zero totals when trial has no ratings', () async {
      final data = await svc.assembleForTrial(trial);
      expect(data.integrity.totalRatings, 0);
      expect(data.integrity.ratingsWithGps, 0);
      expect(data.integrity.raterSummaries, isEmpty);
      expect(data.integrity.amendments, isEmpty);
    });
  });

  group('raw data appendix', () {
    test('populates rawDataRows with mapped rating fields', () async {
      final t = await treatment('T1');
      final p = await plot('101', rep: 2, treatmentId: t);
      final a = await assessment('Weed control');
      final s = await session('S1', sessionDateLocal: '2026-03-05');
      await application(DateTime(2026, 3, 1));
      await rating(p, a, s, value: 87.5, rater: 'Alice');

      final data = await svc.assembleForTrial(trial);
      expect(data.rawDataTruncated, isFalse);
      expect(data.rawDataTotalCount, 1);
      final row = data.rawDataRows.single;
      expect(row.sessionName, 'S1');
      expect(row.plotCode, '101');
      expect(row.rep, 2);
      expect(row.treatmentCode, 'T1');
      expect(row.assessmentName, 'Weed control');
      expect(row.ratingValue, 87.5);
      expect(row.dat, 4);
      expect(row.raterName, 'Alice');
    });

    test('sorts rows by session, plot, then assessment', () async {
      final t = await treatment('T1');
      final p2 = await plot('102', rep: 1, treatmentId: t);
      final p1 = await plot('101', rep: 1, treatmentId: t);
      final b = await assessment('B rating');
      final a = await assessment('A rating');
      final s2 = await session('B session');
      final s1 = await session('A session');
      await rating(p2, b, s2, value: 1);
      await rating(p2, a, s1, value: 2);
      await rating(p1, b, s1, value: 3);

      final data = await svc.assembleForTrial(trial);
      expect(
        data.rawDataRows
            .map((r) => '${r.sessionName}|${r.plotCode}|${r.assessmentName}')
            .toList(),
        [
          'A session|101|B rating',
          'A session|102|A rating',
          'B session|102|B rating',
        ],
      );
    });

    test('sets rawDataTruncated false within cap', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 80);

      final data = await svc.assembleForTrial(trial);
      expect(data.rawDataTruncated, isFalse);
      expect(data.rawDataTotalCount, 1);
      expect(data.rawDataRows, hasLength(1));
    });

    test('sets rawDataTruncated true when rows exceed 2000', () async {
      final a = await assessment('A');
      final s = await session('S1');
      for (var i = 0; i < 2001; i++) {
        final p = await plot('${1000 + i}', rep: 1);
        await rating(p, a, s, value: i.toDouble());
      }

      final data = await svc.assembleForTrial(trial);
      expect(data.rawDataTruncated, isTrue);
      expect(data.rawDataTotalCount, 2001);
      expect(data.rawDataRows, hasLength(2000));
    });

    test('assessment names resolve from map and DAT can be null', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('Crop vigor');
      final s = await session('S1');
      await rating(p, a, s, value: 12, rater: null);

      final data = await svc.assembleForTrial(trial);
      final row = data.rawDataRows.single;
      expect(row.assessmentName, 'Crop vigor');
      expect(row.assessmentName, isNot('Assessment $a'));
      expect(row.dat, isNull);
      expect(row.raterName, isNull);
    });
  });

  // ── 5. Outlier detection ───────────────────────────────────────────────────

  group('outliers', () {
    test('flags value more than 2 SD from treatment mean', () async {
      final t = await treatment('T1');
      final p1 = await plot('101', rep: 1, treatmentId: t);
      final p2 = await plot('102', rep: 2, treatmentId: t);
      final p3 = await plot('103', rep: 3, treatmentId: t);
      final p4 = await plot('104', rep: 4, treatmentId: t);
      final p5 = await plot('105', rep: 5, treatmentId: t);
      final p6 = await plot('106', rep: 6, treatmentId: t);
      final a = await assessment('A');
      final s = await session('S1');
      // 5 clustered + 1 far outlier: mean≈67.5, sd≈30.2 → 0 is ~2.24 SD below
      await rating(p1, a, s, value: 80);
      await rating(p2, a, s, value: 82);
      await rating(p3, a, s, value: 81);
      await rating(p4, a, s, value: 80);
      await rating(p5, a, s, value: 82);
      await rating(p6, a, s, value: 0);

      final data = await svc.assembleForTrial(trial);
      expect(data.outliers.any((o) => o.value == 0.0), isTrue);
      expect(data.outliers.any((o) => o.value == 0.0 && o.treatmentCode == 'T1'),
          isTrue);
    });

    test('does not flag values within 2 SD', () async {
      final t = await treatment('T1');
      final p1 = await plot('101', rep: 1, treatmentId: t);
      final p2 = await plot('102', rep: 2, treatmentId: t);
      final p3 = await plot('103', rep: 3, treatmentId: t);
      final p4 = await plot('104', rep: 4, treatmentId: t);
      final a = await assessment('A');
      final s = await session('S1');
      // Tight cluster — no outliers
      await rating(p1, a, s, value: 80);
      await rating(p2, a, s, value: 82);
      await rating(p3, a, s, value: 81);
      await rating(p4, a, s, value: 79);

      final data = await svc.assembleForTrial(trial);
      expect(data.outliers, isEmpty);
    });

    test('skips treatment with fewer than 3 plots', () async {
      final t = await treatment('T1');
      final p1 = await plot('101', rep: 1, treatmentId: t);
      final p2 = await plot('102', rep: 2, treatmentId: t); // only 2
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p1, a, s, value: 80);
      await rating(p2, a, s, value: 5); // extreme but < 3 samples

      final data = await svc.assembleForTrial(trial);
      expect(data.outliers, isEmpty);
    });

    test('guard rows excluded from outlier analysis', () async {
      final t = await treatment('T1');
      // Insert one guard row
      final guardPk = await db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: 'G1',
            rep: const Value(1),
            treatmentId: Value(t),
            isGuardRow: const Value(true),
          ));
      final p1 = await plot('101', rep: 1, treatmentId: t);
      final p2 = await plot('102', rep: 2, treatmentId: t);
      final p3 = await plot('103', rep: 3, treatmentId: t);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(guardPk, a, s, value: 5); // extreme guard value
      await rating(p1, a, s, value: 80);
      await rating(p2, a, s, value: 82);
      await rating(p3, a, s, value: 81);

      final data = await svc.assembleForTrial(trial);
      // Guard row excluded → only 3 data plots, no outlier flagged
      expect(data.outliers, isEmpty);
    });
  });

  // ── 6. Completeness score ──────────────────────────────────────────────────

  group('completeness score', () {
    test('GPS component scores full when all ratings have coordinates', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 80, lat: 51.0, lng: -1.0);

      final data = await svc.assembleForTrial(trial);
      final gps = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('gps'));
      expect(gps.score, gps.maxScore);
    });

    test('GPS component scores zero when no ratings have coordinates', () async {
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      final s = await session('S1');
      await rating(p, a, s, value: 80); // no GPS

      final data = await svc.assembleForTrial(trial);
      final gps = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('gps'));
      expect(gps.score, 0);
    });

    test('BBCH component scores full when all sessions have BBCH', () async {
      await session('S1', bbch: 65);
      await session('S2', bbch: 71);

      final data = await svc.assembleForTrial(trial);
      final bbch = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('bbch'));
      expect(bbch.score, bbch.maxScore);
    });

    test('BBCH component scores zero when no sessions have BBCH', () async {
      await session('S1'); // no bbch
      final data = await svc.assembleForTrial(trial);
      final bbch = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('bbch'));
      expect(bbch.score, 0);
    });

    test('seeding component scores full when seeding record exists', () async {
      await db.into(db.seedingEvents).insert(SeedingEventsCompanion.insert(
            trialId: trialId,
            seedingDate: DateTime(2026, 3, 1),
          ));

      final data = await svc.assembleForTrial(trial);
      final seed = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('seeding'));
      expect(seed.score, seed.maxScore);
    });

    test('seeding component scores zero when no seeding record', () async {
      final data = await svc.assembleForTrial(trial);
      final seed = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('seeding'));
      expect(seed.score, 0);
    });

    test('session-close component partial when only some sessions closed',
        () async {
      await session('S1', endedAt: DateTime(2026, 3, 1, 17)); // closed
      await session('S2'); // open

      final data = await svc.assembleForTrial(trial);
      final closeComp = data.completenessScore.components
          .firstWhere((c) => c.name.toLowerCase().contains('session'));
      expect(closeComp.score, greaterThan(0));
      expect(closeComp.score, lessThan(closeComp.maxScore));
    });

    test('totalScore is bounded by maxScore', () async {
      await session('S1', bbch: 65, endedAt: DateTime(2026, 3, 1, 17));
      final p = await plot('101', rep: 1);
      final a = await assessment('A');
      await rating(p, a, 1, value: 80, lat: 51.0, lng: -1.0,
          confidence: 'certain', ratingTime: '09:00');

      final data = await svc.assembleForTrial(trial);
      expect(data.completenessScore.totalScore,
          lessThanOrEqualTo(data.completenessScore.maxScore));
      expect(data.completenessScore.totalScore, greaterThanOrEqualTo(0));
    });

    test('percentage stays in 0–100 range', () async {
      final data = await svc.assembleForTrial(trial);
      expect(data.completenessScore.percentage, inInclusiveRange(0.0, 100.0));
    });
  });
}
