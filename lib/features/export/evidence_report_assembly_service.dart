import 'dart:io';
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/plot_display.dart';
import '../../core/config/app_info.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../../domain/signals/signal_models.dart';
import '../../domain/signals/signal_repository.dart';
import '../photos/photo_repository.dart';
import '../plots/plot_repository.dart';
import '../ratings/rating_repository.dart';
import '../sessions/session_repository.dart';
import '../sessions/session_timing_helper.dart';
import 'evidence_report_data.dart';

/// Assembles [EvidenceReportData] from existing repositories.
/// No new data collection — uses only what the database already stores.
class EvidenceReportAssemblyService {
  EvidenceReportAssemblyService({
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required SessionRepository sessionRepository,
    required AssignmentRepository assignmentRepository,
    required RatingRepository ratingRepository,
    required WeatherSnapshotRepository weatherSnapshotRepository,
    required SeedingRepository seedingRepository,
    required PhotoRepository photoRepository,
    required SignalRepository signalRepository,
    required AppDatabase db,
  })  : _plotRepo = plotRepository,
        _treatmentRepo = treatmentRepository,
        _applicationRepo = applicationRepository,
        _sessionRepo = sessionRepository,
        _assignmentRepo = assignmentRepository,
        _ratingRepo = ratingRepository,
        _weatherRepo = weatherSnapshotRepository,
        _seedingRepo = seedingRepository,
        _photoRepo = photoRepository,
        _signalRepo = signalRepository,
        _db = db;

  final PlotRepository _plotRepo;
  final TreatmentRepository _treatmentRepo;
  final ApplicationRepository _applicationRepo;
  final SessionRepository _sessionRepo;
  final AssignmentRepository _assignmentRepo;
  final RatingRepository _ratingRepo;
  final WeatherSnapshotRepository _weatherRepo;
  final SeedingRepository _seedingRepo;
  final PhotoRepository _photoRepo;
  final SignalRepository _signalRepo;
  final AppDatabase _db;

  Future<EvidenceReportData> assembleForTrial(Trial trial) async {
    final trialId = trial.id;

    // Parallel fetches
    final plotsFuture = _plotRepo.getPlotsForTrial(trialId);
    final treatmentsFuture = _treatmentRepo.getTreatmentsForTrial(trialId);
    final sessionsFuture = _sessionRepo.getSessionsForTrial(trialId);
    final applicationsFuture =
        _applicationRepo.getApplicationsForTrial(trialId);
    final assignmentsFuture = _assignmentRepo.getForTrial(trialId);
    final weatherFuture = _weatherRepo.getWeatherSnapshotsForTrial(trialId);
    final seedingFuture = _seedingRepo.getSeedingEventForTrial(trialId);
    final signalsFuture = _signalRepo.getOpenSignalsForTrial(trialId);
    final assessmentsFuture = (_db.select(_db.assessments)
          ..where((a) => a.trialId.equals(trialId)))
        .get();

    final plots = await plotsFuture;
    final treatments = await treatmentsFuture;
    final sessions = await sessionsFuture;
    final applications = await applicationsFuture;
    final assignments = await assignmentsFuture;
    final weatherSnapshots = await weatherFuture;
    final seedingEvent = await seedingFuture;
    final raterDriftSignals = (await signalsFuture)
        .where((s) => s.signalType == SignalType.raterDrift.dbValue)
        .toList();
    final assessmentNames = {
      for (final assessment in await assessmentsFuture)
        assessment.id: assessment.name,
    };

    final dataPlots = plots.where(isAnalyzablePlot).toList();
    final dataPlotIds = dataPlots.map((p) => p.id).toSet();
    final plotMap = {for (final p in plots) p.id: p};
    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentByPlot = {for (final a in assignments) a.plotId: a};

    // Weather by session
    final weatherBySession = <int, WeatherSnapshot>{};
    for (final w in weatherSnapshots) {
      if (w.parentType == 'rating_session') {
        weatherBySession[w.parentId] = w;
      }
    }

    // ── 1. Trial Identity ──
    final reps = dataPlots.map((p) => p.rep).whereType<int>().toSet();
    final identity = EvidenceTrialIdentity(
      name: trial.name,
      protocolNumber: trial.protocolNumber,
      sponsor: trial.sponsor,
      investigatorName: trial.investigatorName,
      cooperatorName: trial.cooperatorName,
      crop: trial.crop,
      location: trial.location,
      season: trial.season,
      siteId: trial.siteId,
      fieldName: trial.fieldName,
      county: trial.county,
      stateProvince: trial.stateProvince,
      country: trial.country,
      latitude: trial.latitude,
      longitude: trial.longitude,
      soilSeries: trial.soilSeries,
      soilTexture: trial.soilTexture,
      experimentalDesign: trial.experimentalDesign,
      plotCount: dataPlots.length,
      treatmentCount: treatments.length,
      repCount: reps.isEmpty ? null : reps.length,
      createdAt: trial.createdAt,
      status: trial.status,
      workspaceType: trial.workspaceType,
    );

    // ── 2. Timeline ──
    final timeline = _buildTimeline(
      trial: trial,
      sessions: sessions,
      applications: applications,
      seedingEvent: seedingEvent,
    );

    // ── 3. Treatments ──
    final evidenceTreatments = <EvidenceTreatment>[];
    for (final t in treatments) {
      final components =
          await _treatmentRepo.getComponentsForTreatment(t.id);
      evidenceTreatments.add(EvidenceTreatment(
        code: t.code,
        name: t.name,
        treatmentType: t.treatmentType,
        components: components
            .map((c) => EvidenceTreatmentComponent(
                  productName: c.productName,
                  rate: c.rate?.toString(),
                  rateUnit: c.rateUnit,
                  formulationType: c.formulationType,
                  applicationTiming: c.applicationTiming,
                ))
            .toList(),
      ));
    }

    // ── 4. Seeding ──
    final seeding = seedingEvent != null
        ? EvidenceSeeding(
            seedingDate: seedingEvent.seedingDate,
            variety: seedingEvent.variety,
            seedLotNumber: seedingEvent.seedLotNumber,
            seedingRate: seedingEvent.seedingRate,
            seedingRateUnit: seedingEvent.seedingRateUnit,
            plantingMethod: seedingEvent.plantingMethod,
            operatorName: seedingEvent.operatorName,
            completedAt: seedingEvent.completedAt,
            emergenceDate: seedingEvent.emergenceDate,
            status: seedingEvent.status,
          )
        : null;

    // ── 5. Applications ──
    final evidenceApplications = applications.map((a) {
      final tCode = a.treatmentId != null
          ? treatmentMap[a.treatmentId]?.code
          : null;
      return EvidenceApplication(
        applicationDate: a.applicationDate,
        productName: a.productName,
        treatmentCode: tCode,
        rate: a.rate?.toString(),
        rateUnit: a.rateUnit,
        applicationMethod: a.applicationMethod,
        equipmentUsed: a.equipmentUsed,
        operatorName: a.operatorName,
        applicationTime: a.applicationTime,
        temperature: a.temperature,
        humidity: a.humidity,
        windSpeed: a.windSpeed,
        windDirection: a.windDirection,
        waterVolume: a.waterVolume,
        waterVolumeUnit: a.waterVolumeUnit,
        status: a.status,
        appliedAt: a.appliedAt,
        growthStageCode: a.growthStageCode,
      );
    }).toList();

    // ── 6 & 7. Sessions + Data Integrity ──
    // Collect all ratings across sessions for integrity analysis
    final allRatings = <RatingRecord>[];
    final allCorrections = <RatingCorrection>[];
    final evidenceSessions = <EvidenceSession>[];
    final sessionTimestamps = <SessionTimestampDistribution>[];
    final allRawDataRows = <EvidenceRawDataRow>[];

    for (final s in sessions) {
      final ratings = await _ratingRepo.getCurrentRatingsForSession(s.id);
      allRatings.addAll(ratings);
      final sessionDat = _sessionDat(
        session: s,
        seedingEvent: seedingEvent,
        applications: applications,
      );

      for (final r in ratings) {
        if (!dataPlotIds.contains(r.plotPk)) continue;
        final plot = plotMap[r.plotPk];
        if (plot == null) continue;
        final treatmentId = assignmentByPlot[plot.id]?.treatmentId ??
            plot.treatmentId ??
            -1;
        final treatmentCode = treatmentMap[treatmentId]?.code ?? '-';
        allRawDataRows.add(EvidenceRawDataRow(
          plotCode: plot.plotId,
          rep: plot.rep ?? 0,
          treatmentCode: treatmentCode,
          assessmentName:
              assessmentNames[r.assessmentId] ?? 'Assessment ${r.assessmentId}',
          sessionName: s.name,
          ratingValue: r.numericValue,
          dat: sessionDat,
          raterName: r.raterName,
        ));
      }

      final ratedPks = ratings.map((r) => r.plotPk).toSet();
      final editedPks = ratings
          .where((r) => r.amended || r.previousId != null)
          .map((r) => r.plotPk)
          .toSet();

      // Flagged plots
      final flaggedPks = await _db
          .select(_db.plotFlags)
          .map((f) => f.plotPk)
          .get();
      final sessionFlaggedCount =
          ratedPks.where((pk) => flaggedPks.contains(pk)).length;

      // Assessment count
      final assessmentIds = ratings.map((r) => r.assessmentId).toSet();

      // Weather
      final weather = weatherBySession[s.id];
      final evidenceWeather = weather != null
          ? EvidenceWeather(
              temperature: weather.temperature,
              temperatureUnit: weather.temperatureUnit,
              humidity: weather.humidity,
              windSpeed: weather.windSpeed,
              windSpeedUnit: weather.windSpeedUnit,
              windDirection: weather.windDirection,
              cloudCover: weather.cloudCover,
              precipitation: weather.precipitation,
              soilCondition: weather.soilCondition,
              source: weather.source,
            )
          : null;

      evidenceSessions.add(EvidenceSession(
        id: s.id,
        name: s.name,
        sessionDateLocal: s.sessionDateLocal,
        raterName: s.raterName,
        startedAt: s.startedAt,
        endedAt: s.endedAt,
        cropStageBbch: s.cropStageBbch,
        plotsRated: ratedPks.length,
        plotsFlagged: sessionFlaggedCount,
        plotsEdited: editedPks.length,
        assessmentCount: assessmentIds.length,
        totalRatings: ratings.length,
        weather: evidenceWeather,
        status: s.endedAt != null ? 'closed' : 'open',
      ));

      // Timestamp distribution for this session
      final ratingTimes = ratings
          .where((r) => r.createdAt != s.startedAt)
          .map((r) => r.createdAt)
          .toList()
        ..sort();

      if (ratingTimes.isNotEmpty) {
        final first = ratingTimes.first;
        final last = ratingTimes.last;
        final minutesFromStart = ratingTimes
            .map((t) => t.difference(first).inMinutes)
            .toList();
        sessionTimestamps.add(SessionTimestampDistribution(
          sessionName: s.name,
          sessionDate: s.sessionDateLocal,
          firstRatingTime:
              '${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')}',
          lastRatingTime:
              '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
          ratingCount: ratingTimes.length,
          durationMinutes: last.difference(first).inMinutes,
          ratingTimesMinutesFromStart: minutesFromStart,
        ));
      }

      // Corrections for this session
      final correctionPks =
          await _ratingRepo.getPlotPksWithCorrectionsForSession(s.id);
      if (correctionPks.isNotEmpty) {
        final sessionRatingIds = ratings.map((r) => r.id).toList();
        final corrections =
            await _ratingRepo.getCorrectionsForRatingIds(sessionRatingIds);
        allCorrections.addAll(corrections);
      }
    }

    // ── Data Integrity aggregation ──
    final amendments = <EvidenceAmendment>[];
    final corrections = <EvidenceCorrection>[];

    // Amendments (from rating records with amended=true)
    for (final r in allRatings) {
      if (!r.amended && r.previousId == null) continue;
      final session = sessions.firstWhere((s) => s.id == r.sessionId,
          orElse: () => sessions.first);
      final plot = plots.where((p) => p.id == r.plotPk).firstOrNull;
      final plotLabel = plot != null ? getDisplayPlotLabel(plot, plots) : '?';
      final assessName =
          assessmentNames[r.assessmentId] ?? 'Assessment ${r.assessmentId}';

      amendments.add(EvidenceAmendment(
        plotLabel: plotLabel,
        assessmentName: assessName,
        sessionName: session.name,
        originalValue: r.originalValue,
        newValue: r.numericValue?.toString() ?? r.textValue,
        reason: r.amendmentReason,
        amendedBy: r.amendedBy,
        amendedAt: r.amendedAt,
      ));
    }

    // Corrections
    for (final c in allCorrections) {
      final session = sessions
          .where((s) => s.id == c.sessionId)
          .firstOrNull;
      final plot = plots.where((p) => p.id == c.plotPk).firstOrNull;
      corrections.add(EvidenceCorrection(
        plotLabel: plot != null ? getDisplayPlotLabel(plot, plots) : '?',
        sessionName: session?.name ?? '?',
        oldValue: c.oldNumericValue?.toString() ?? c.oldTextValue,
        newValue: c.newNumericValue?.toString() ?? c.newTextValue,
        oldStatus: c.oldResultStatus,
        newStatus: c.newResultStatus,
        reason: c.reason,
        correctedBy: null, // correctedByUserId is int, not name
        correctedAt: c.correctedAt,
      ));
    }

    // Status counts
    final statusCounts = <String, int>{};
    for (final r in allRatings) {
      statusCounts[r.resultStatus] =
          (statusCounts[r.resultStatus] ?? 0) + 1;
    }

    // GPS, confidence, timestamp counts
    final ratingsWithGps = allRatings
        .where(
            (r) => r.capturedLatitude != null && r.capturedLongitude != null)
        .length;
    final ratingsWithConfidence =
        allRatings.where((r) => r.confidence != null).length;
    final ratingsWithTimestamp =
        allRatings.where((r) => r.ratingTime != null).length;

    // Device summaries
    final deviceMap = <String, ({int count, Set<String> sessions})>{};
    for (final r in allRatings) {
      final device = r.createdDeviceInfo ?? 'Unknown device';
      final version = r.createdAppVersion ?? '?';
      final key = '$device | v$version';
      final session = sessions
          .where((s) => s.id == r.sessionId)
          .firstOrNull
          ?.name ?? '?';
      final entry = deviceMap[key] ??
          (count: 0, sessions: <String>{});
      deviceMap[key] = (
        count: entry.count + 1,
        sessions: entry.sessions..add(session),
      );
    }
    final deviceSummaries = deviceMap.entries
        .map((e) => EvidenceDevice(
              deviceInfo: e.key,
              appVersion: '',
              ratingCount: e.value.count,
              sessionNames: e.value.sessions.toList(),
            ))
        .toList();

    // Rater summaries
    final raterMap =
        <String, ({int count, Set<String> sessions, Set<int> sessionIds})>{};
    for (final r in allRatings) {
      final rater = r.raterName ?? 'Unknown rater';
      final session = sessions
          .where((s) => s.id == r.sessionId)
          .firstOrNull
          ?.name ?? '?';
      final entry = raterMap[rater] ??
          (count: 0, sessions: <String>{}, sessionIds: <int>{});
      raterMap[rater] = (
        count: entry.count + 1,
        sessions: entry.sessions..add(session),
        sessionIds: entry.sessionIds..add(r.sessionId),
      );
    }
    final raterSummaries = raterMap.entries
        .map((e) {
          final driftSignal = raterDriftSignals
              .where((s) => s.sessionId != null)
              .where((s) => e.value.sessionIds.contains(s.sessionId))
              .firstOrNull;
          return EvidenceRater(
            name: e.key,
            ratingCount: e.value.count,
            sessionNames: e.value.sessions.toList(),
            raterDriftDetected: driftSignal != null,
            driftSeverity: driftSignal?.severity,
            driftConsequence: driftSignal?.consequenceText,
          );
        })
        .toList();

    final integrity = EvidenceDataIntegrity(
      totalRatings: allRatings.length,
      ratingsWithGps: ratingsWithGps,
      ratingsWithConfidence: ratingsWithConfidence,
      ratingsWithTimestamp: ratingsWithTimestamp,
      amendments: amendments,
      corrections: corrections,
      statusCounts: statusCounts,
      deviceSummaries: deviceSummaries,
      raterSummaries: raterSummaries,
      sessionTimestampDistributions: sessionTimestamps,
    );

    // ── 8. Outliers ──
    final outliers = _computeOutliers(
      dataPlots: dataPlots,
      allPlots: plots,
      allRatings: allRatings,
      sessions: sessions,
      treatments: treatments,
      assignmentByPlot: assignmentByPlot,
      treatmentMap: treatmentMap,
      assessmentNames: assessmentNames,
    );

    // ── 9. Weather records ──
    final weatherRecords = weatherSnapshots
        .map((w) => EvidenceWeather(
              temperature: w.temperature,
              temperatureUnit: w.temperatureUnit,
              humidity: w.humidity,
              windSpeed: w.windSpeed,
              windSpeedUnit: w.windSpeedUnit,
              windDirection: w.windDirection,
              cloudCover: w.cloudCover,
              precipitation: w.precipitation,
              soilCondition: w.soilCondition,
              source: w.source,
            ))
        .toList();

    // ── 10. Photos ──
    final trialPhotos = await _photoRepo.getPhotosForTrial(trialId);
    final sessionMap = {for (final s in sessions) s.id: s};
    final evidencePhotos = <EvidencePhoto>[];

    // Limit to 50 photos max to keep PDF size reasonable
    final photosToEmbed = trialPhotos.take(50).toList();
    for (final photo in photosToEmbed) {
      final session = sessionMap[photo.sessionId];
      final plot = plotMap[photo.plotPk];
      final plotLabel =
          plot != null ? getDisplayPlotLabel(plot, plots) : 'Plot ${photo.plotPk}';

      // Read file bytes for thumbnail
      List<int>? imageBytes;
      try {
        final absolutePath =
            await PhotoRepository.resolvePhotoPath(photo.filePath);
        final file = File(absolutePath);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      } catch (e) {
        debugPrint('Could not read photo file: ${photo.filePath} — $e');
      }

      evidencePhotos.add(EvidencePhoto(
        plotLabel: plotLabel,
        sessionName: session?.name ?? '?',
        sessionDate: session?.sessionDateLocal ?? '?',
        createdAt: photo.createdAt,
        caption: photo.caption,
        filePath: photo.filePath,
        imageBytes: imageBytes,
      ));
    }

    // ── 11. Evidence Completeness Score ──
    final completenessScore = _computeCompletenessScore(
      trial: trial,
      sessions: evidenceSessions,
      allRatings: allRatings,
      ratingsWithGps: ratingsWithGps,
      ratingsWithConfidence: ratingsWithConfidence,
      weatherSnapshots: weatherSnapshots,
      amendments: amendments,
      treatments: evidenceTreatments,
      applications: evidenceApplications,
      seeding: seeding,
    );

    allRawDataRows.sort((a, b) {
      final sessionCompare = a.sessionName.compareTo(b.sessionName);
      if (sessionCompare != 0) return sessionCompare;
      final plotCompare = a.plotCode.compareTo(b.plotCode);
      if (plotCompare != 0) return plotCompare;
      return a.assessmentName.compareTo(b.assessmentName);
    });
    const rawDataCap = 2000;
    final rawDataTotalCount = allRawDataRows.length;
    final rawDataTruncated = rawDataTotalCount > rawDataCap;
    final rawDataRows = rawDataTruncated
        ? allRawDataRows.take(rawDataCap).toList()
        : allRawDataRows;

    return EvidenceReportData(
      identity: identity,
      timeline: timeline,
      treatments: evidenceTreatments,
      seeding: seeding,
      applications: evidenceApplications,
      sessions: evidenceSessions,
      integrity: integrity,
      outliers: outliers,
      photos: evidencePhotos,
      weatherRecords: weatherRecords,
      rawDataRows: rawDataRows,
      rawDataTruncated: rawDataTruncated,
      rawDataTotalCount: rawDataTotalCount,
      completenessScore: completenessScore,
      generatedAt: DateTime.now(),
      appVersion: AppInfo.appVersion,
    );
  }

  List<TimelineEvent> _buildTimeline({
    required Trial trial,
    required List<Session> sessions,
    required List<TrialApplicationEvent> applications,
    required SeedingEvent? seedingEvent,
  }) {
    final events = <TimelineEvent>[];

    events.add(TimelineEvent(
        label: 'Trial created', date: trial.createdAt));

    if (seedingEvent != null) {
      events.add(TimelineEvent(
        label: 'Seeding',
        date: seedingEvent.seedingDate,
        detail: seedingEvent.status,
      ));
      if (seedingEvent.emergenceDate != null) {
        events.add(TimelineEvent(
            label: 'Emergence', date: seedingEvent.emergenceDate!));
      }
    }

    for (final a in applications) {
      events.add(TimelineEvent(
        label: 'Application: ${a.productName ?? ""}',
        date: a.applicationDate,
        detail: a.status,
      ));
    }

    for (final s in sessions) {
      events.add(TimelineEvent(
        label: 'Session opened: ${s.name}',
        date: s.startedAt,
        detail: s.raterName,
      ));
      if (s.endedAt != null) {
        events.add(TimelineEvent(
          label: 'Session closed: ${s.name}',
          date: s.endedAt!,
        ));
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  int? _sessionDat({
    required Session session,
    required SeedingEvent? seedingEvent,
    required List<TrialApplicationEvent> applications,
  }) {
    final sessionDate = _tryParseDateOnly(session.sessionDateLocal);
    if (sessionDate == null) return null;
    final priorApplications = applications
        .where((a) =>
            a.status == 'applied' &&
            !_dateOnly(a.applicationDate).isAfter(sessionDate))
        .toList();
    final timing = buildSessionTimingContext(
      sessionStartedAt: sessionDate,
      cropStageBbch: session.cropStageBbch,
      seeding: seedingEvent,
      applications: priorApplications,
    );
    return timing.daysAfterLastApp;
  }

  DateTime? _tryParseDateOnly(String raw) {
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _dateOnly(parsed);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<EvidenceOutlier> _computeOutliers({
    required List<Plot> dataPlots,
    required List<Plot> allPlots,
    required List<RatingRecord> allRatings,
    required List<Session> sessions,
    required List<Treatment> treatments,
    required Map<int, Assignment> assignmentByPlot,
    required Map<int, Treatment> treatmentMap,
    required Map<int, String> assessmentNames,
  }) {
    // Build plot → treatment map
    final plotTreatment = <int, int>{};
    for (final p in dataPlots) {
      final assignment = assignmentByPlot[p.id];
      plotTreatment[p.id] =
          assignment?.treatmentId ?? p.treatmentId ?? -1;
    }

    // Build rating lookup: current, recorded, numeric
    final ratingMap = <(int, int), RatingRecord>{};
    for (final r in allRatings) {
      if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
        ratingMap[(r.plotPk, r.assessmentId)] = r;
      }
    }

    // Get unique assessment IDs
    final assessmentIds = allRatings.map((r) => r.assessmentId).toSet();

    final outliers = <EvidenceOutlier>[];

    for (final assessId in assessmentIds) {
      // Group values by treatment
      final byTreatment = <int, List<(Plot, double)>>{};
      for (final p in dataPlots) {
        final r = ratingMap[(p.id, assessId)];
        if (r == null) continue;
        final tid = plotTreatment[p.id] ?? -1;
        byTreatment.putIfAbsent(tid, () => []).add((p, r.numericValue!));
      }

      for (final entry in byTreatment.entries) {
        final values = entry.value.map((e) => e.$2).toList();
        if (values.length < 3) continue;
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance =
            values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                values.length;
        final sd = sqrt(variance);
        if (sd == 0) continue;

        for (final (plot, value) in entry.value) {
          final deviations = (value - mean).abs() / sd;
          if (deviations <= 2) continue;

          final r = ratingMap[(plot.id, assessId)]!;
          final trt = treatmentMap[entry.key];
          final assessName = assessmentNames[assessId] ?? 'Assessment $assessId';

          outliers.add(EvidenceOutlier(
            plotLabel: getDisplayPlotLabel(plot, allPlots),
            treatmentCode: trt?.code ?? '?',
            rep: plot.rep,
            assessmentName: assessName,
            value: value,
            treatmentMean: mean,
            sdFromMean: deviations,
            raterName: r.raterName,
            confidence: r.confidence,
            wasAmended: r.amended || r.previousId != null,
          ));
        }
      }
    }

    return outliers;
  }

  EvidenceCompletenessScore _computeCompletenessScore({
    required Trial trial,
    required List<EvidenceSession> sessions,
    required List<RatingRecord> allRatings,
    required int ratingsWithGps,
    required int ratingsWithConfidence,
    required List<WeatherSnapshot> weatherSnapshots,
    required List<EvidenceAmendment> amendments,
    required List<EvidenceTreatment> treatments,
    required List<EvidenceApplication> applications,
    required EvidenceSeeding? seeding,
  }) {
    final components = <EvidenceScoreComponent>[];
    var total = 0;
    var maxTotal = 0;

    // 1. Trial identity (15 pts)
    const identityMax = 15;
    var identityScore = 0;
    if (trial.protocolNumber != null) identityScore += 3;
    if (trial.sponsor != null) identityScore += 2;
    if (trial.investigatorName != null) identityScore += 3;
    if (trial.latitude != null && trial.longitude != null) identityScore += 5;
    if (trial.crop != null) identityScore += 2;
    components.add(EvidenceScoreComponent(
      name: 'Trial identity',
      score: identityScore,
      maxScore: identityMax,
      detail: identityScore == identityMax
          ? 'Complete'
          : 'Missing: ${[
              if (trial.protocolNumber == null) 'protocol number',
              if (trial.sponsor == null) 'sponsor',
              if (trial.investigatorName == null) 'investigator',
              if (trial.latitude == null) 'GPS coordinates',
              if (trial.crop == null) 'crop',
            ].join(', ')}',
    ));
    total += identityScore;
    maxTotal += identityMax;

    // 2. GPS on ratings (15 pts)
    const gpsMax = 15;
    final gpsPct =
        allRatings.isNotEmpty ? ratingsWithGps / allRatings.length : 0.0;
    final gpsScore = (gpsPct * gpsMax).round();
    components.add(EvidenceScoreComponent(
      name: 'GPS coordinates',
      score: gpsScore,
      maxScore: gpsMax,
      detail: '${(gpsPct * 100).round()}% of ratings have GPS',
    ));
    total += gpsScore;
    maxTotal += gpsMax;

    // 3. Confidence levels (10 pts)
    const confMax = 10;
    final confPct = allRatings.isNotEmpty
        ? ratingsWithConfidence / allRatings.length
        : 0.0;
    final confScore = (confPct * confMax).round();
    components.add(EvidenceScoreComponent(
      name: 'Confidence levels',
      score: confScore,
      maxScore: confMax,
      detail: '${(confPct * 100).round()}% of ratings have confidence recorded',
    ));
    total += confScore;
    maxTotal += confMax;

    // 4. Weather records (10 pts)
    const weatherMax = 10;
    final sessionsWithWeather =
        sessions.where((s) => s.weather?.hasData == true).length;
    final weatherPct =
        sessions.isNotEmpty ? sessionsWithWeather / sessions.length : 0.0;
    final weatherScore = (weatherPct * weatherMax).round();
    components.add(EvidenceScoreComponent(
      name: 'Weather conditions',
      score: weatherScore,
      maxScore: weatherMax,
      detail: '$sessionsWithWeather of ${sessions.length} sessions have weather',
    ));
    total += weatherScore;
    maxTotal += weatherMax;

    // 5. Treatment components (10 pts)
    const trtMax = 10;
    final trtsWithComponents =
        treatments.where((t) => t.components.isNotEmpty).length;
    final trtPct =
        treatments.isNotEmpty ? trtsWithComponents / treatments.length : 0.0;
    final trtScore = (trtPct * trtMax).round();
    components.add(EvidenceScoreComponent(
      name: 'Treatment details',
      score: trtScore,
      maxScore: trtMax,
      detail: '$trtsWithComponents of ${treatments.length} treatments have '
          'product details',
    ));
    total += trtScore;
    maxTotal += trtMax;

    // 6. Session completeness (15 pts)
    const sessionMax = 15;
    final closedSessions =
        sessions.where((s) => s.status == 'closed').length;
    final sessionPct =
        sessions.isNotEmpty ? closedSessions / sessions.length : 0.0;
    final sessionScore = (sessionPct * sessionMax).round();
    components.add(EvidenceScoreComponent(
      name: 'Session completion',
      score: sessionScore,
      maxScore: sessionMax,
      detail: '$closedSessions of ${sessions.length} sessions closed',
    ));
    total += sessionScore;
    maxTotal += sessionMax;

    // 7. BBCH growth stage (10 pts)
    const bbchMax = 10;
    final sessionsWithBbch =
        sessions.where((s) => s.cropStageBbch != null).length;
    final bbchPct =
        sessions.isNotEmpty ? sessionsWithBbch / sessions.length : 0.0;
    final bbchScore = (bbchPct * bbchMax).round();
    components.add(EvidenceScoreComponent(
      name: 'Growth stage (BBCH)',
      score: bbchScore,
      maxScore: bbchMax,
      detail: '$sessionsWithBbch of ${sessions.length} sessions have BBCH',
    ));
    total += bbchScore;
    maxTotal += bbchMax;

    // 8. Seeding record (5 pts)
    const seedMax = 5;
    final seedScore = seeding != null ? seedMax : 0;
    components.add(EvidenceScoreComponent(
      name: 'Seeding record',
      score: seedScore,
      maxScore: seedMax,
      detail: seeding != null ? 'Recorded' : 'Not recorded',
    ));
    total += seedScore;
    maxTotal += seedMax;

    // 9. Application records (10 pts)
    const appMax = 10;
    final appScore = applications.isNotEmpty ? appMax : 0;
    components.add(EvidenceScoreComponent(
      name: 'Application records',
      score: appScore,
      maxScore: appMax,
      detail: applications.isNotEmpty
          ? '${applications.length} application(s) recorded'
          : 'No applications recorded',
    ));
    total += appScore;
    maxTotal += appMax;

    return EvidenceCompletenessScore(
      totalScore: total,
      maxScore: maxTotal,
      components: components,
    );
  }
}
