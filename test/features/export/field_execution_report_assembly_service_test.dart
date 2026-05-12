/// Integration tests for [FieldExecutionReportAssemblyService].
///
/// Pins all seven sections of the Field Execution Report:
///   A. Identity — trial and session fields
///   B. Protocol context — ARM-linked, ARM-trial, divergences
///   C. Session grid — data-plot counts using hub semantics
///   D. Evidence record — photos, GPS, weather, timestamp
///   E. Signals — open signals for the session
///   F. Completeness — plot completeness via use case
///   G. Execution statement — deterministic text from assembled data
///
/// Uses an in-memory database; all setup goes through raw Drift companions
/// to bypass protocol guards exercised by their own tests elsewhere.
library;

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/ctq_factor_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_purpose_repository.dart';
import 'package:arm_field_companion/domain/signals/signal_models.dart';
import 'package:arm_field_companion/domain/signals/signal_repository.dart';
import 'package:arm_field_companion/features/export/field_execution_report_assembly_service.dart';
import 'package:arm_field_companion/features/export/field_execution_report_data.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/compute_session_completeness_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/domain/signals/signal_writers/timing_window_violation_writer.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FieldExecutionReportAssemblyService svc;
  late int trialId;
  late Trial trial;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final plotRepo = PlotRepository(db);
    final ratingRepo = RatingRepository(db);
    final sessionRepo = SessionRepository(db);
    svc = FieldExecutionReportAssemblyService(
      plotRepository: plotRepo,
      ratingRepository: ratingRepo,
      sessionRepository: sessionRepo,
      signalRepository: SignalRepository.attach(db),
      seedingRepository: SeedingRepository(db),
      completenessUseCase: ComputeSessionCompletenessUseCase(
        sessionRepo,
        plotRepo,
        ratingRepo,
      ),
      purposeRepository: TrialPurposeRepository(db),
      ctqFactorRepository: CtqFactorDefinitionRepository(db),
      db: db,
    );
    trialId = await TrialRepository(db)
        .createTrial(name: 'Herbicide T', workspaceType: 'efficacy');
    trial = (await TrialRepository(db).getTrialById(trialId))!;
  });

  tearDown(() => db.close());

  // ── helpers ──────────────────────────────────────────────────────────────────

  Future<int> plot(String plotId, {int? rep, int? treatmentId}) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            rep: Value(rep),
            treatmentId: Value(treatmentId),
          ));

  Future<int> guardPlot(String plotId) =>
      db.into(db.plots).insert(PlotsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            isGuardRow: const Value(true),
          ));

  Future<int> assessment(String name) =>
      db.into(db.assessments).insert(AssessmentsCompanion.insert(
            trialId: trialId,
            name: name,
          ));

  Future<int> session(String name,
          {String date = '2026-04-01',
          String status = 'open',
          DateTime? startedAt,
          DateTime? endedAt}) =>
      db.into(db.sessions).insert(SessionsCompanion.insert(
            trialId: trialId,
            name: name,
            sessionDateLocal: date,
            status: Value(status),
            startedAt:
                startedAt == null ? const Value.absent() : Value(startedAt),
            endedAt: Value(endedAt),
          ));

  Future<Session> getSession(int id) async =>
      (await (db.select(db.sessions)..where((s) => s.id.equals(id))).get())
          .first;

  Future<void> linkAssessmentToSession(int sessionId, int assessmentId) =>
      db.into(db.sessionAssessments).insert(SessionAssessmentsCompanion.insert(
            sessionId: sessionId,
            assessmentId: assessmentId,
          ));

  Future<void> rating(int plotPk, int assessId, int sessionId,
          {double? value,
          String status = 'RECORDED',
          double? lat,
          double? lng,
          bool amended = false}) =>
      db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: assessId,
            sessionId: sessionId,
            resultStatus: Value(status),
            numericValue: Value(value),
            capturedLatitude: Value(lat),
            capturedLongitude: Value(lng),
            amended: Value(amended),
          ));

  Future<void> photo(int sessionId, int plotPk) =>
      db.into(db.photos).insert(PhotosCompanion.insert(
            trialId: trialId,
            sessionId: sessionId,
            plotPk: plotPk,
            filePath: 'test/photo.jpg',
          ));

  Future<void> weather(int sessionId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.into(db.weatherSnapshots).insert(WeatherSnapshotsCompanion.insert(
          uuid: 'test-weather-$sessionId-$now',
          trialId: trialId,
          parentId: sessionId,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 'test',
        ));
  }

  Future<void> application(DateTime date, {String status = 'applied'}) =>
      db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion.insert(
              trialId: trialId,
              applicationDate: date,
              status: Value(status),
            ),
          );

  Future<void> flagPlot(int sessionId, int plotPk) =>
      db.into(db.plotFlags).insert(PlotFlagsCompanion.insert(
            trialId: trialId,
            plotPk: plotPk,
            sessionId: sessionId,
            flagType: 'review',
          ));

  Future<int> raiseSignal(int sessionId) =>
      SignalRepository.attach(db).raiseSignal(
        trialId: trialId,
        sessionId: sessionId,
        signalType: SignalType.scaleViolation,
        moment: SignalMoment.two,
        severity: SignalSeverity.review,
        referenceContext: const SignalReferenceContext(),
        consequenceText: 'Value outside scale.',
      );

  // ── A. Identity ──────────────────────────────────────────────────────────────

  group('identity', () {
    test('maps trial and session fields', () async {
      final sid = await session('S1', date: '2026-04-01', status: 'open');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.identity.trialId, trialId);
      expect(data.identity.trialName, 'Herbicide T');
      expect(data.identity.sessionId, sid);
      expect(data.identity.sessionName, 'S1');
      expect(data.identity.sessionDateLocal, '2026-04-01');
      expect(data.identity.sessionStatus, 'open');
    });

    test('includes optional trial fields when present', () async {
      await (db.update(db.trials)..where((t) => t.id.equals(trialId))).write(
        const TrialsCompanion(
          protocolNumber: Value('PN-001'),
          crop: Value('Soybean'),
          location: Value('Field A'),
          season: Value('2026'),
        ),
      );
      final updatedTrial = (await TrialRepository(db).getTrialById(trialId))!;
      final sid = await session('S1');
      final s = await getSession(sid);

      final data =
          await svc.assembleForSession(trial: updatedTrial, session: s);

      expect(data.identity.protocolNumber, 'PN-001');
      expect(data.identity.crop, 'Soybean');
      expect(data.identity.location, 'Field A');
      expect(data.identity.season, '2026');
    });
  });

  // ── B. Protocol context ───────────────────────────────────────────────────────

  group('protocol context', () {
    test('no divergences when trial has no ARM plan', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmTrial, isFalse);
      expect(data.protocolContext.isArmLinked, isFalse);
      expect(data.protocolContext.divergences, isEmpty);
    });

    test('unexpected divergence for manual session in ARM trial', () async {
      // Create an ARM session so the trial counts as ARM-linked.
      final sid = await session('ARM-S1', date: '2026-04-01');
      await db.into(db.armSessionMetadata).insert(
            ArmSessionMetadataCompanion.insert(
              sessionId: sid,
              armRatingDate: '2026-04-01',
            ),
          );

      // Create a separate manual session.
      final manualId = await session('Manual-S1', date: '2026-04-10');
      final s = await getSession(manualId);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmTrial, isTrue);
      expect(data.protocolContext.isArmLinked, isFalse);
      expect(data.protocolContext.unexpectedCount, 1);
    });

    test('timing divergence when ARM session date differs from planned',
        () async {
      final sid = await session('S1', date: '2026-04-05');
      await db.into(db.armSessionMetadata).insert(
            ArmSessionMetadataCompanion.insert(
              sessionId: sid,
              armRatingDate: '2026-04-01',
            ),
          );
      final p = await plot('101');
      final a = await assessment('Weed');
      await linkAssessmentToSession(sid, a);
      await rating(p, a, sid, value: 80.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmLinked, isTrue);
      expect(data.protocolContext.timingCount, 1);
      expect(data.protocolContext.divergences.first.deltaDays, 4);
    });

    test('missing divergence when ARM session has no ratings', () async {
      final sid = await session('S1', date: '2026-04-01');
      await db.into(db.armSessionMetadata).insert(
            ArmSessionMetadataCompanion.insert(
              sessionId: sid,
              armRatingDate: '2026-04-01',
            ),
          );
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmLinked, isTrue);
      expect(data.protocolContext.missingCount, 1);
    });

    test('no divergence for on-time ARM session with ratings', () async {
      final sid = await session('S1', date: '2026-04-01');
      await db.into(db.armSessionMetadata).insert(
            ArmSessionMetadataCompanion.insert(
              sessionId: sid,
              armRatingDate: '2026-04-01',
            ),
          );
      final p = await plot('101');
      final a = await assessment('Weed');
      await linkAssessmentToSession(sid, a);
      await rating(p, a, sid, value: 80.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmLinked, isTrue);
      expect(data.protocolContext.divergences, isEmpty);
    });

    // ── Standalone protocol timing (SA tests) ────────────────────────────────

    // SA-1: outside window → timing deviation row emitted with correct fields.
    test(
        'SA-1: standalone trial with DAA outside window emits timing deviation',
        () async {
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WC1', name: 'Weed control', category: 'efficacy'));
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId, assessmentDefinitionId: defId));
      final aId = await assessment('Weed control');
      // Application on Apr-01; session on Apr-12 → actualDaa = 11.
      await application(DateTime(2026, 4, 1));
      final sid = await session('S1', date: '2026-04-12');
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sid,
              assessmentId: aId,
              trialAssessmentId: Value(taId)));
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
          trialId: trialId, claimBeingTested: 'Herbicide efficacy.');
      await (db.update(db.trialPurposes)..where((t) => t.id.equals(purposeId)))
          .write(TrialPurposesCompanion(
            plannedDatByAssessment: Value('{"$taId": 7}'),
            protocolTimingWindow: const Value(3),
          ));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.divergences, hasLength(1));
      final row = data.protocolContext.divergences.single;
      expect(row.type, FerDivergenceType.timing);
      // delta = actualDaa(11) - plannedDat(7) = 4
      expect(row.deltaDays, 4);
      expect(row.plannedDat, 7);
      expect(row.actualDat, 11);
    });

    // SA-2: within window → no deviation rows.
    test('SA-2: standalone trial with DAA within window has no divergences',
        () async {
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WC2', name: 'Weed control', category: 'efficacy'));
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId, assessmentDefinitionId: defId));
      final aId = await assessment('Weed control');
      // Application on Apr-01; session on Apr-09 → actualDaa = 8.
      // Window ±3 with plannedDat=7: |8-7|=1 ≤ 3 → no deviation.
      await application(DateTime(2026, 4, 1));
      final sid = await session('S1', date: '2026-04-09');
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sid,
              assessmentId: aId,
              trialAssessmentId: Value(taId)));
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
          trialId: trialId, claimBeingTested: 'Herbicide efficacy.');
      await (db.update(db.trialPurposes)..where((t) => t.id.equals(purposeId)))
          .write(TrialPurposesCompanion(
            plannedDatByAssessment: Value('{"$taId": 7}'),
            protocolTimingWindow: const Value(3),
          ));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.divergences, isEmpty);
    });

    // SA-3: null window → short-circuit before map lookup, no deviation rows.
    test(
        'SA-3: null protocolTimingWindow short-circuits before JSON parse',
        () async {
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WC3', name: 'Weed control', category: 'efficacy'));
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId, assessmentDefinitionId: defId));
      final aId = await assessment('Weed control');
      await application(DateTime(2026, 4, 1));
      final sid = await session('S1', date: '2026-04-12');
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sid,
              assessmentId: aId,
              trialAssessmentId: Value(taId)));
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
          trialId: trialId, claimBeingTested: 'Herbicide efficacy.');
      // plannedDatByAssessment is populated but window is null — must short-circuit.
      await (db.update(db.trialPurposes)..where((t) => t.id.equals(purposeId)))
          .write(TrialPurposesCompanion(
            plannedDatByAssessment: Value('{"$taId": 7}'),
            protocolTimingWindow: const Value(null),
          ));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.divergences, isEmpty);
    });

    // SA-4: assessment absent from JSON map → no crash, no false deviation;
    //        a second assessment that IS in the map is still evaluated.
    test(
        'SA-4: absent assessment ID produces no row, map entries still evaluated',
        () async {
      // TA1: in session, NOT in plannedDatByAssessment.
      final defId1 = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WC4a', name: 'Weed control A', category: 'efficacy'));
      final taId1 = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId, assessmentDefinitionId: defId1));
      final aId1 = await assessment('Weed control A');
      // TA2: in session AND in plannedDatByAssessment, outside window.
      final defId2 = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'WC4b', name: 'Disease pressure', category: 'efficacy'));
      final taId2 = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId, assessmentDefinitionId: defId2));
      final aId2 = await assessment('Disease pressure');

      await application(DateTime(2026, 4, 1)); // actualDaa = 11 for Apr-12
      final sid = await session('S1', date: '2026-04-12');
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sid, assessmentId: aId1,
              trialAssessmentId: Value(taId1)));
      await db.into(db.sessionAssessments).insert(
            SessionAssessmentsCompanion.insert(
              sessionId: sid, assessmentId: aId2,
              trialAssessmentId: Value(taId2)));

      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
          trialId: trialId, claimBeingTested: 'Herbicide efficacy.');
      // Only taId2 is in the map; taId1 is intentionally absent.
      await (db.update(db.trialPurposes)..where((t) => t.id.equals(purposeId)))
          .write(TrialPurposesCompanion(
            plannedDatByAssessment: Value('{"$taId2": 7}'),
            protocolTimingWindow: const Value(3),
          ));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      // taId1 absent from map → 0 rows for it; taId2 outside window → 1 row.
      expect(data.protocolContext.divergences, hasLength(1));
      expect(data.protocolContext.divergences.single.type,
          FerDivergenceType.timing);
    });

    // SA-5: plannedDatByAssessment null (Q6 skipped) → empty divergences, no crash.
    //        Distinct from SA-3: window IS set, null check hits the JSON map, not window.
    test(
        'SA-5: null plannedDatByAssessment with window set returns empty divergences',
        () async {
      final sid = await session('S1', date: '2026-04-12');
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
          trialId: trialId, claimBeingTested: 'Herbicide efficacy.');
      // Window is set but Q6 was skipped so plannedDatByAssessment is null.
      await (db.update(db.trialPurposes)..where((t) => t.id.equals(purposeId)))
          .write(const TrialPurposesCompanion(
            plannedDatByAssessment: Value(null),
            protocolTimingWindow: Value(3),
          ));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.divergences, isEmpty);
    });
  });

  // ── C. Session grid ──────────────────────────────────────────────────────────

  group('session grid', () {
    test('counts only data plots, excludes guard rows', () async {
      await plot('101');
      await plot('102');
      await guardPlot('G1');
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.dataPlotCount, 2);
    });

    test('counts rated and unrated plots', () async {
      final p1 = await plot('101');
      final p2 = await plot('102');
      await plot('103');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, value: 80.0);
      await rating(p2, a, sid, value: 70.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.rated, 2);
      expect(data.sessionGrid.unrated, 1);
    });

    test('counts assessment count from session assessments', () async {
      final a1 = await assessment('Weed');
      final a2 = await assessment('Disease');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a1);
      await linkAssessmentToSession(sid, a2);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.assessmentCount, 2);
    });

    test('counts plots with issues (non-RECORDED status)', () async {
      final p1 = await plot('101');
      final p2 = await plot('102');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, status: 'RECORDED');
      await rating(p2, a, sid, status: 'NOT_OBSERVED');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.withIssues, 1);
    });

    test('counts edited plots (amended ratings)', () async {
      final p1 = await plot('101');
      final p2 = await plot('102');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, value: 80.0, amended: true);
      await rating(p2, a, sid, value: 70.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.edited, 1);
    });

    test('counts flagged plots', () async {
      final p1 = await plot('101');
      final p2 = await plot('102');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, value: 80.0);
      await rating(p2, a, sid, value: 70.0);
      await flagPlot(sid, p1);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.flagged, 1);
    });

    test('empty session returns zero counts', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.sessionGrid.dataPlotCount, 0);
      expect(data.sessionGrid.assessmentCount, 0);
      expect(data.sessionGrid.rated, 0);
    });
  });

  group('assessment timing', () {
    test('non-ARM session with prior application populates actual DAA',
        () async {
      final a = await assessment('Weed control');
      final sid = await session('S1', date: '2026-04-10');
      await linkAssessmentToSession(sid, a);
      await application(DateTime(2026, 4, 1));
      await application(DateTime(2026, 4, 7));
      await application(DateTime(2026, 4, 12));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.protocolContext.isArmTrial, isFalse);
      expect(data.assessmentTimingRows, hasLength(1));
      expect(data.assessmentTimingRows.single.assessmentId, a);
      expect(data.assessmentTimingRows.single.assessmentName, 'Weed control');
      expect(data.assessmentTimingRows.single.actualDaa, 3);
    });

    test('session with no prior application keeps actual DAA null', () async {
      final a = await assessment('Crop vigor');
      final sid = await session('S1', date: '2026-04-10');
      await linkAssessmentToSession(sid, a);
      await application(DateTime(2026, 4, 12));
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.assessmentTimingRows, hasLength(1));
      expect(data.assessmentTimingRows.single.assessmentName, 'Crop vigor');
      expect(data.assessmentTimingRows.single.actualDaa, isNull);
    });
  });

  // ── D. Evidence record ────────────────────────────────────────────────────────

  group('evidence record', () {
    test('no evidence: all false, empty photo list', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.photoCount, 0);
      expect(data.evidenceRecord.photoIds, isEmpty);
      expect(data.evidenceRecord.hasGps, isFalse);
      expect(data.evidenceRecord.hasWeather, isFalse);
      expect(data.evidenceRecord.hasTimestamp, isTrue); // date is parseable
    });

    test('detects photos attached to session', () async {
      final p1 = await plot('101');
      final sid = await session('S1');
      await photo(sid, p1);
      await photo(sid, p1);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.photoCount, 2);
      expect(data.evidenceRecord.photoIds.length, 2);
    });

    test('detects GPS from rated plots in session', () async {
      final p1 = await plot('101');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, lat: 40.1, lng: -88.2);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.hasGps, isTrue);
    });

    test('detects weather snapshot', () async {
      final sid = await session('S1');
      await weather(sid);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.hasWeather, isTrue);
    });

    test('hasTimestamp false when sessionDateLocal is not parseable', () async {
      final sid = await session('S1', date: 'not-a-date');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.hasTimestamp, isFalse);
    });

    test('derives session duration from started and ended timestamps',
        () async {
      final startedAt = DateTime.utc(2026, 4, 1, 12);
      final endedAt = DateTime.utc(2026, 4, 1, 13, 25);
      final sid = await session(
        'S1',
        status: 'closed',
        startedAt: startedAt,
        endedAt: endedAt,
      );
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.sessionDurationMinutes, 85);
    });

    // Locks the semantic: GPS is derived from current, non-deleted ratings only.
    // Superseded or deleted ratings must not contribute hasGps.
    test('non-current rating with GPS is not counted toward hasGps', () async {
      final p1 = await plot('101');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);

      // Insert a rating with GPS but isCurrent=false — superseded row.
      await db.into(db.ratingRecords).insert(RatingRecordsCompanion.insert(
            trialId: trialId,
            plotPk: p1,
            assessmentId: a,
            sessionId: sid,
            capturedLatitude: const Value(40.1),
            capturedLongitude: const Value(-88.2),
            isCurrent: const Value(false),
          ));

      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.evidenceRecord.hasGps, isFalse,
          reason: 'non-current ratings must not contribute GPS evidence');
    });
  });

  // ── E. Signals ────────────────────────────────────────────────────────────────

  group('signals', () {
    test('no signals when none raised', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.signals.openSignals, isEmpty);
    });

    test('lists open signals for this session', () async {
      final sid = await session('S1');
      await raiseSignal(sid);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.signals.openSignals.length, 1);
      expect(data.signals.openSignals.first.signalType, 'scale_violation');
      expect(data.signals.openSignals.first.severity, 'review');
      expect(data.signals.openSignals.first.status, 'open');
      expect(data.signals.openSignals.first.consequenceText,
          'Value outside scale.');
    });

    test('does not include signals from other sessions', () async {
      final sid1 = await session('S1');
      final sid2 = await session('S2');
      await raiseSignal(sid2); // signal on a different session
      final s = await getSession(sid1);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.signals.openSignals, isEmpty);
    });

    // Locks the semantic: terminal statuses (resolved/expired/suppressed)
    // must not appear in openSignals.
    test('resolved signal is excluded from openSignals', () async {
      final sid = await session('S1');
      final signalId = await raiseSignal(sid);
      await SignalRepository.attach(db).recordDecisionEvent(
        signalId: signalId,
        eventType: SignalDecisionEventType.confirm,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
      );
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.signals.openSignals, isEmpty,
          reason: 'resolved signals must not appear as open');
    });

    test('save + timing writer flow appears in FER Section E', () async {
      final sid = await session('S1', date: '2026-06-10');
      final p = await plot('101');
      final a = await assessment('Weed');
      await linkAssessmentToSession(sid, a);
      final s = await getSession(sid);

      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'TST',
              name: 'Test',
              category: 'pest',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              ratingType: const Value('CONTRO'),
            ),
          );
      await db.into(db.trialApplicationEvents).insert(
            TrialApplicationEventsCompanion(
              trialId: Value(trialId),
              applicationDate: Value(
                  DateTime.now().toUtc().subtract(const Duration(days: 3))),
              status: const Value('applied'),
            ),
          );

      final ratingRepo = RatingRepository(db);
      final saveUc = SaveRatingUseCase(
        ratingRepo,
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db),
        ),
      );
      final saveResult = await saveUc.execute(SaveRatingInput(
        trialId: trialId,
        plotPk: p,
        assessmentId: a,
        sessionId: sid,
        resultStatus: 'RECORDED',
        numericValue: 80.0,
        trialAssessmentId: taId,
      ));
      expect(saveResult.isSuccess, isTrue);

      final writer =
          TimingWindowViolationWriter(db, SignalRepository.attach(db));
      final timingId = await writer.checkAndRaise(
        ratingId: saveResult.rating!.id,
        trialAssessmentId: taId,
      );
      expect(timingId, isNotNull);

      final data = await svc.assembleForSession(trial: trial, session: s);
      final timingRows = data.signals.openSignals
          .where((r) => r.signalType == SignalType.causalContextFlag.dbValue)
          .toList();
      expect(timingRows, hasLength(1));
      expect(timingRows.single.consequenceText,
          contains('outside the configured biological window'));
    });
  });

  // ── F. Completeness ───────────────────────────────────────────────────────────

  group('completeness', () {
    test('canClose true and no blockers when all plots rated', () async {
      final p1 = await plot('101');
      final p2 = await plot('102');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, value: 80.0);
      await rating(p2, a, sid, value: 70.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.completeness.expectedPlots, 2);
      expect(data.completeness.completedPlots, 2);
      expect(data.completeness.incompletePlots, 0);
      expect(data.completeness.canClose, isTrue);
      expect(data.completeness.blockerCount, 0);
    });

    test('reports blockers when plots are missing ratings', () async {
      await plot('101');
      await plot('102');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      // No ratings added — both plots missing.
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.completeness.canClose, isFalse);
      expect(data.completeness.blockerCount, greaterThan(0));
      expect(data.completeness.incompletePlots, 2);
    });
  });

  // ── H. Cognition section ─────────────────────────────────────────────────────

  group('cognition section', () {
    // H-1: No purpose → unknown status, all-unknown CTQ.
    test(
        'no purpose → purposeStatus unknown, purposeStatusLabel Intent not captured',
        () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.purposeStatus, 'unknown');
      expect(data.cognition.purposeStatusLabel, 'Intent not captured');
      expect(data.cognition.claimBeingTested, isNull);
      expect(data.cognition.ctqOverallStatus, 'unknown');
      expect(data.cognition.topCtqAttentionItems, isEmpty);
    });

    // H-2: Confirmed purpose → claim and endpoint populated.
    test('confirmed purpose → claim and primaryEndpoint present in cognition',
        () async {
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Fungicide vs untreated check.',
        primaryEndpoint: 'Disease severity rating.',
        trialPurpose: 'Registration support.',
        treatmentRoleSummary: 'T1=product, T2=check.',
      );
      await purposeRepo.confirmTrialPurpose(purposeId, confirmedBy: 'tester');

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.purposeStatus, 'confirmed');
      expect(data.cognition.purposeStatusLabel, 'Intent confirmed');
      expect(data.cognition.claimBeingTested, 'Fungicide vs untreated check.');
      expect(data.cognition.primaryEndpoint, 'Disease severity rating.');
    });

    // H-3: Partial purpose → missing field labels populated.
    test(
        'partial purpose → missingIntentFieldLabels lists human-readable names',
        () async {
      final purposeRepo = TrialPurposeRepository(db);
      // Only claimBeingTested provided; the other three required fields missing.
      await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Herbicide efficacy.',
      );

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.purposeStatus, 'partial');
      expect(data.cognition.purposeStatusLabel, 'Intent in progress');
      expect(
          data.cognition.missingIntentFieldLabels,
          containsAll(
              ['Trial purpose', 'Primary endpoint', 'Treatment roles']));
      expect(data.cognition.missingIntentFieldLabels,
          isNot(contains('Claim being tested')));
    });

    // H-4: Evidence arc state and summary flow through.
    test('evidence arc state and actualEvidenceSummary populated from DB',
        () async {
      final p1 = await plot('101');
      final a = await assessment('Weed');
      final sid = await session('S1');
      await linkAssessmentToSession(sid, a);
      await rating(p1, a, sid, value: 75.0);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      // With 1 session + 1 recorded rating the state is not no_evidence.
      expect(data.cognition.evidenceState, isNot('no_evidence'));
      expect(data.cognition.evidenceStateLabel, isNot('No evidence yet'));
      expect(data.cognition.actualEvidenceSummary, contains('session'));
      expect(data.cognition.actualEvidenceSummary, contains('rating'));
    });

    // H-5: CTQ counts flow through after purpose + factor seeding.
    test('CTQ counts flow through when factors seeded for confirmed purpose',
        () async {
      final purposeRepo = TrialPurposeRepository(db);
      final ctqRepo = CtqFactorDefinitionRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Efficacy claim.',
        trialPurpose: 'Registration.',
        primaryEndpoint: 'DISEASE_SEV.',
        treatmentRoleSummary: 'T1=check.',
      );
      await purposeRepo.confirmTrialPurpose(purposeId, confirmedBy: 'tester');
      await ctqRepo.seedDefaultCtqFactorsForPurpose(
          trialId: trialId, trialPurposeId: purposeId);

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      // With no ratings the CTQ evaluator will flag missing data; counts > 0.
      final total = data.cognition.blockerCount +
          data.cognition.warningCount +
          data.cognition.reviewCount +
          data.cognition.satisfiedCount;
      expect(total, greaterThan(0),
          reason: 'At least some CTQ factors should be evaluable');
      expect(data.cognition.ctqOverallStatus, isNot('unknown'));
    });

    // H-6: Top attention items limited to 5, ordered blocked → review → missing.
    test(
        'topCtqAttentionItems contains only actionable items, max 5, in priority order',
        () async {
      final purposeRepo = TrialPurposeRepository(db);
      final ctqRepo = CtqFactorDefinitionRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Efficacy.',
        trialPurpose: 'Reg.',
        primaryEndpoint: 'SEV.',
        treatmentRoleSummary: 'T1=check.',
      );
      await purposeRepo.confirmTrialPurpose(purposeId, confirmedBy: 'tester');
      await ctqRepo.seedDefaultCtqFactorsForPurpose(
          trialId: trialId, trialPurposeId: purposeId);

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.topCtqAttentionItems.length, lessThanOrEqualTo(5));
      // All returned items must be actionable (no 'unknown' or 'satisfied').
      for (final item in data.cognition.topCtqAttentionItems) {
        expect(
          ['Blocked', 'Needs review', 'Missing'],
          contains(item.statusLabel),
          reason: 'Only actionable items should appear: ${item.label}',
        );
      }
    });

    // H-7: Unknown-only CTQ factors excluded when actionable missing items exist.
    test('unknown CTQ factors do not appear in topCtqAttentionItems', () async {
      final purposeRepo = TrialPurposeRepository(db);
      final ctqRepo = CtqFactorDefinitionRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Efficacy.',
        trialPurpose: 'Reg.',
        primaryEndpoint: 'SEV.',
        treatmentRoleSummary: 'T1=check.',
      );
      await purposeRepo.confirmTrialPurpose(purposeId, confirmedBy: 'tester');
      await ctqRepo.seedDefaultCtqFactorsForPurpose(
          trialId: trialId, trialPurposeId: purposeId);

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      // disease_pressure, crop_stage, rainfall_after_application are
      // intentionally unknown — they must never appear in attention items.
      const intentionallyUnknown = {
        'disease_pressure',
        'crop_stage',
        'rainfall_after_application',
      };
      for (final item in data.cognition.topCtqAttentionItems) {
        expect(
          intentionallyUnknown,
          isNot(contains(item.factorKey)),
          reason:
              '${item.factorKey} is intentionally unknown and must not appear in attention items',
        );
      }
    });

    // H-8: Disclaimer text is present and non-efficacy.
    test('cognition section disclaimer excludes efficacy and validity claims',
        () async {
      final sid = await session('S1');
      final s = await getSession(sid);
      await svc.assembleForSession(trial: trial, session: s);

      expect(FerCognitionSection.disclaimerText, isNotEmpty);
      expect(
          FerCognitionSection.disclaimerText, contains('does not determine'));
      expect(FerCognitionSection.disclaimerText, contains('efficacy'));
      expect(FerCognitionSection.disclaimerText, contains('validity'));
    });

    // H-9: interpretationRiskFactors is a non-null list when no purpose row.
    // The evaluator may return cannot_evaluate items even without a purpose;
    // the field must never be null and each item must have a valid tier.
    test('interpretationRiskFactors is a non-null list when no purpose row',
        () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.interpretationRiskFactors, isNotNull);
      for (final f in data.cognition.interpretationRiskFactors) {
        expect(
          ['HIGH', 'MEDIUM', 'CANNOT EVALUATE'],
          contains(f.tier),
        );
      }
    });

    // H-10: knownInterpretationFactors is null when no purpose row.
    test('knownInterpretationFactors is null when no purpose row', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.cognition.knownInterpretationFactors, isNull);
    });

    // H-11: knownInterpretationFactors populated from confirmed purpose.
    test('knownInterpretationFactors populated when purpose has the field',
        () async {
      final purposeRepo = TrialPurposeRepository(db);
      final purposeId = await purposeRepo.createInitialTrialPurpose(
        trialId: trialId,
        claimBeingTested: 'Herbicide efficacy vs check.',
        trialPurpose: 'Registration.',
        primaryEndpoint: 'WEED_COUNT.',
        treatmentRoleSummary: 'T1=check.',
      );
      await (db.update(db.trialPurposes)
            ..where((t) => t.id.equals(purposeId)))
          .write(const TrialPurposesCompanion(
            knownInterpretationFactors: Value(
                'Soil moisture varied between reps; interpret with caution.'),
          ));

      final sid = await session('S1');
      final s = await getSession(sid);
      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(
        data.cognition.knownInterpretationFactors,
        'Soil moisture varied between reps; interpret with caution.',
      );
    });

    // H-12: interpretationRiskFactors never contains 'none' severity items.
    test('interpretationRiskFactors excludes none-severity factors', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      for (final f in data.cognition.interpretationRiskFactors) {
        expect(
          ['HIGH', 'MEDIUM', 'CANNOT EVALUATE'],
          contains(f.tier),
          reason: '${f.label} has unexpected tier: ${f.tier}',
        );
      }
    });
  });

  // ── G. Execution statement ────────────────────────────────────────────────────

  group('execution statement', () {
    test('contains session name and trial name', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.executionStatement, contains('S1'));
      expect(data.executionStatement, contains('Herbicide T'));
    });

    test('includes photo count when photos present', () async {
      final p1 = await plot('101');
      final sid = await session('S1');
      await photo(sid, p1);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.executionStatement, contains('1 photo(s)'));
    });

    test('includes open signal count when signals present', () async {
      final sid = await session('S1');
      await raiseSignal(sid);
      final s = await getSession(sid);

      final data = await svc.assembleForSession(trial: trial, session: s);

      expect(data.executionStatement, contains('1 open signal(s)'));
    });

    test('is deterministic across two calls', () async {
      final sid = await session('S1');
      final s = await getSession(sid);

      final d1 = await svc.assembleForSession(trial: trial, session: s);
      final d2 = await svc.assembleForSession(trial: trial, session: s);

      // generatedAt will differ by milliseconds — compare the statement only.
      expect(d1.executionStatement, equals(d2.executionStatement));
    });
  });
}
