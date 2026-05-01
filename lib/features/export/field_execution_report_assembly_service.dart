import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../features/plots/plot_repository.dart';
import '../../features/ratings/rating_repository.dart';
import '../../features/sessions/domain/session_completeness_report.dart';
import '../../features/sessions/session_repository.dart';
import '../../features/sessions/usecases/compute_session_completeness_usecase.dart';
import '../../domain/signals/signal_repository.dart';
import 'field_execution_report_data.dart';

/// Assembles [FieldExecutionReportData] for a single session from existing
/// repositories. No PDF rendering, no new diagnostics, no schema changes.
///
/// All seven sections are deterministic and auditable. Sections that cannot
/// be populated (e.g. ARM divergence on a non-ARM trial) are returned empty
/// rather than omitted.
class FieldExecutionReportAssemblyService {
  FieldExecutionReportAssemblyService({
    required PlotRepository plotRepository,
    required RatingRepository ratingRepository,
    required SessionRepository sessionRepository,
    required SignalRepository signalRepository,
    required SeedingRepository seedingRepository,
    required ComputeSessionCompletenessUseCase completenessUseCase,
    required AppDatabase db,
  })  : _plotRepo = plotRepository,
        _ratingRepo = ratingRepository,
        _sessionRepo = sessionRepository,
        _signalRepo = signalRepository,
        _seedingRepo = seedingRepository,
        _completenessUseCase = completenessUseCase,
        _db = db;

  final PlotRepository _plotRepo;
  final RatingRepository _ratingRepo;
  final SessionRepository _sessionRepo;
  final SignalRepository _signalRepo;
  final SeedingRepository _seedingRepo;
  final ComputeSessionCompletenessUseCase _completenessUseCase;
  final AppDatabase _db;

  /// Assembles the full report for [session] within [trial].
  ///
  /// [trial] must already exist. [session] must belong to [trial].
  Future<FieldExecutionReportData> assembleForSession({
    required Trial trial,
    required Session session,
  }) async {
    // ── Start all independent futures before awaiting any ────────────────────
    final plotsFuture = _plotRepo.getPlotsForTrial(trial.id);
    final ratingsFuture = _ratingRepo.getCurrentRatingsForSession(session.id);
    final correctionsFuture =
        _ratingRepo.getPlotPksWithCorrectionsForSession(session.id);
    final assessmentsFuture = _sessionRepo.getSessionAssessments(session.id);
    final signalsFuture = _signalRepo.getOpenSignalsForSession(session.id);
    final seedingFuture = _seedingRepo.getSeedingEventForTrial(trial.id);

    // ARM session metadata — queried directly from core DB to respect the
    // ARM separation boundary (no import of ArmColumnMappingRepository).
    final armMetaFuture = (_db.select(_db.armSessionMetadata)
          ..where((m) => m.sessionId.equals(session.id))
          ..limit(1))
        .getSingleOrNull();

    // Check if any ARM metadata exists for the trial (determines ARM-trial flag).
    final armTrialCountFuture = _db.customSelect(
      'SELECT COUNT(*) AS cnt FROM arm_session_metadata '
      'WHERE session_id IN '
      '  (SELECT id FROM sessions WHERE trial_id = ? AND is_deleted = 0)',
      variables: [drift.Variable.withInt(trial.id)],
      readsFrom: {_db.armSessionMetadata, _db.sessions},
    ).getSingle().then((r) => r.read<int>('cnt'));

    // Evidence: photos and weather for this session.
    final photosFuture = (_db.select(_db.photos)
          ..where(
              (p) => p.sessionId.equals(session.id) & p.isDeleted.equals(false)))
        .get();
    final weatherFuture = (_db.select(_db.weatherSnapshots)
          ..where((w) => w.parentId.equals(session.id)))
        .get();

    // Flagged plots for this session.
    final flagsFuture = (_db.select(_db.plotFlags)
          ..where((f) => f.sessionId.equals(session.id)))
        .get();

    // ── Await all ────────────────────────────────────────────────────────────
    final plots = await plotsFuture;
    final ratings = await ratingsFuture;
    final correctionPks = await correctionsFuture;
    final assessments = await assessmentsFuture;
    final openSignals = await signalsFuture;
    final seedingEvent = await seedingFuture;
    final armMeta = await armMetaFuture;
    final armTrialCount = await armTrialCountFuture;
    final sessionPhotos = await photosFuture;
    final sessionWeather = await weatherFuture;
    final sessionFlags = await flagsFuture;

    // ── Section A: Identity ───────────────────────────────────────────────────
    final identity = FerIdentity(
      trialId: trial.id,
      trialName: trial.name,
      protocolNumber: trial.protocolNumber,
      crop: trial.crop,
      location: trial.location,
      season: trial.season,
      sessionId: session.id,
      sessionName: session.name,
      sessionDateLocal: session.sessionDateLocal,
      sessionStatus: session.status,
      raterName: session.raterName,
    );

    // ── Section B: Protocol context ───────────────────────────────────────────
    final protocolContext =
        _buildProtocolContext(session, armMeta, armTrialCount, ratings, seedingEvent);

    // ── Section C: Session grid (hub semantics — data plots only) ─────────────
    final dataPlots = plots.where(isAnalyzablePlot).toList();

    final ratedPks = ratings.map((r) => r.plotPk).toSet();
    final flaggedPks = sessionFlags.map((f) => f.plotPk).toSet();

    final ratingsByPlot = <int, List<RatingRecord>>{};
    for (final r in ratings) {
      ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
    }

    var rated = 0;
    var flagged = 0;
    var withIssues = 0;
    var edited = 0;

    for (final plot in dataPlots) {
      final plotRatings = ratingsByPlot[plot.id] ?? [];
      if (ratedPks.contains(plot.id)) rated++;
      if (flaggedPks.contains(plot.id)) flagged++;
      if (plotRatings.any((r) => r.resultStatus != 'RECORDED')) withIssues++;
      if (correctionPks.contains(plot.id) ||
          plotRatings.any((r) => r.amended || r.previousId != null)) {
        edited++;
      }
    }

    final sessionGrid = FerSessionGrid(
      dataPlotCount: dataPlots.length,
      assessmentCount: assessments.length,
      rated: rated,
      unrated: dataPlots.length - rated,
      withIssues: withIssues,
      edited: edited,
      flagged: flagged,
    );

    // ── Section D: Evidence record ─────────────────────────────────────────────
    final hasGps = ratings.any(
        (r) => r.capturedLatitude != null && r.capturedLongitude != null);
    final hasWeather = sessionWeather.isNotEmpty;
    final hasTimestamp = DateTime.tryParse(session.sessionDateLocal) != null;

    final evidenceRecord = FerEvidenceRecord(
      photoCount: sessionPhotos.length,
      photoIds: sessionPhotos.map((p) => p.id).toList(),
      hasGps: hasGps,
      hasWeather: hasWeather,
      hasTimestamp: hasTimestamp,
    );

    // ── Section E: Signals ────────────────────────────────────────────────────
    final signalRows = openSignals
        .map((s) => FerSignalRow(
              id: s.id,
              signalType: s.signalType,
              severity: s.severity,
              status: s.status,
              consequenceText: s.consequenceText,
              raisedAt: s.raisedAt,
            ))
        .toList();

    final signals = FerSignalsSection(openSignals: signalRows);

    // ── Section F: Completeness ───────────────────────────────────────────────
    final completenessReport =
        await _completenessUseCase.execute(sessionId: session.id);
    final completeness = _mapCompleteness(completenessReport);

    // ── Section G: Execution statement ────────────────────────────────────────
    final executionStatement = _buildExecutionStatement(
      identity: identity,
      grid: sessionGrid,
      protocol: protocolContext,
      evidence: evidenceRecord,
      signals: signals,
      completeness: completeness,
    );

    return FieldExecutionReportData(
      identity: identity,
      protocolContext: protocolContext,
      sessionGrid: sessionGrid,
      evidenceRecord: evidenceRecord,
      signals: signals,
      completeness: completeness,
      executionStatement: executionStatement,
      generatedAt: DateTime.now(),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  FerProtocolContext _buildProtocolContext(
    Session session,
    ArmSessionMetadataData? armMeta,
    int armTrialCount,
    List<RatingRecord> ratings,
    SeedingEvent? seedingEvent,
  ) {
    final isArmTrial = armTrialCount > 0;
    final isArmLinked = armMeta != null;
    final divergences = <FerProtocolDivergenceRow>[];

    if (!isArmTrial) {
      return const FerProtocolContext(
        isArmLinked: false,
        isArmTrial: false,
        divergences: [],
      );
    }

    final seedingDate = seedingEvent?.seedingDate;

    DateTime? tryParseDate(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        return null;
      }
    }

    if (isArmLinked) {
      final actualDate = tryParseDate(session.sessionDateLocal);
      final plannedDate = tryParseDate(armMeta.armRatingDate);
      final comparable = actualDate != null && plannedDate != null;
      final deltaDays =
          comparable ? actualDate.difference(plannedDate).inDays : null;
      final actualDat = (seedingDate != null && actualDate != null)
          ? actualDate.difference(seedingDate).inDays
          : null;
      final plannedDat = (seedingDate != null && plannedDate != null)
          ? plannedDate.difference(seedingDate).inDays
          : null;

      if (comparable && deltaDays != 0) {
        divergences.add(FerProtocolDivergenceRow(
          type: FerDivergenceType.timing,
          deltaDays: deltaDays,
          plannedDat: plannedDat,
          actualDat: actualDat,
        ));
      }
      if (ratings.isEmpty) {
        divergences.add(FerProtocolDivergenceRow(
          type: FerDivergenceType.missing,
          plannedDat: plannedDat,
          actualDat: actualDat,
        ));
      }
    } else {
      // Manual session in an ARM trial — unexpected divergence.
      final actualDate = tryParseDate(session.sessionDateLocal);
      final actualDat = (seedingDate != null && actualDate != null)
          ? actualDate.difference(seedingDate).inDays
          : null;
      divergences.add(FerProtocolDivergenceRow(
        type: FerDivergenceType.unexpected,
        actualDat: actualDat,
      ));
    }

    return FerProtocolContext(
      isArmLinked: isArmLinked,
      isArmTrial: isArmTrial,
      divergences: divergences,
    );
  }

  FerCompletenessSection _mapCompleteness(SessionCompletenessReport report) {
    final blockerCount = report.issues
        .where((i) => i.severity == SessionCompletenessIssueSeverity.blocker)
        .length;
    final warningCount = report.issues
        .where((i) => i.severity == SessionCompletenessIssueSeverity.warning)
        .length;
    return FerCompletenessSection(
      expectedPlots: report.expectedPlots,
      completedPlots: report.completedPlots,
      incompletePlots: report.incompletePlots,
      canClose: report.canClose,
      blockerCount: blockerCount,
      warningCount: warningCount,
    );
  }

  String _buildExecutionStatement({
    required FerIdentity identity,
    required FerSessionGrid grid,
    required FerProtocolContext protocol,
    required FerEvidenceRecord evidence,
    required FerSignalsSection signals,
    required FerCompletenessSection completeness,
  }) {
    final parts = <String>[
      "Session '${identity.sessionName}' (${identity.sessionDateLocal},"
          " ${identity.sessionStatus}) for trial '${identity.trialName}'.",
      "${grid.rated} of ${grid.dataPlotCount} data plots rated"
          " across ${grid.assessmentCount} assessment(s).",
    ];

    if (protocol.totalCount > 0) {
      parts.add("${protocol.totalCount} protocol divergence(s) recorded.");
    }

    if (evidence.photoCount > 0) {
      parts.add("${evidence.photoCount} photo(s) attached.");
    }

    if (evidence.hasGps) parts.add("GPS coordinates present on ratings.");
    if (evidence.hasWeather) parts.add("Weather snapshot recorded.");

    if (signals.openSignals.isNotEmpty) {
      parts.add("${signals.openSignals.length} open signal(s) recorded.");
    }

    if (completeness.blockerCount > 0) {
      parts.add(
          "${completeness.blockerCount} completeness blocker(s) unresolved.");
    } else if (completeness.warningCount > 0) {
      parts.add(
          "${completeness.warningCount} completeness warning(s) recorded.");
    }

    return parts.join(' ');
  }
}
