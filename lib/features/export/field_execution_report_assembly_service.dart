import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../data/repositories/ctq_factor_definition_repository.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/trial_purpose_repository.dart';
import '../../domain/signals/signal_repository.dart';
import '../../domain/trial_cognition/trial_coherence_evaluator.dart';
import '../../domain/trial_cognition/trial_ctq_dto.dart';
import '../../domain/trial_cognition/trial_ctq_evaluator.dart';
import '../../domain/trial_cognition/trial_evidence_arc_evaluator.dart';
import '../../domain/trial_cognition/trial_interpretation_risk_evaluator.dart';
import '../../features/plots/plot_repository.dart';
import '../../features/ratings/rating_repository.dart';
import '../../features/sessions/domain/session_completeness_report.dart';
import '../../features/sessions/session_repository.dart';
import '../../features/sessions/session_timing_helper.dart';
import '../../features/sessions/usecases/compute_session_completeness_usecase.dart';
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
    required TrialPurposeRepository purposeRepository,
    required CtqFactorDefinitionRepository ctqFactorRepository,
    required AppDatabase db,
  })  : _plotRepo = plotRepository,
        _ratingRepo = ratingRepository,
        _sessionRepo = sessionRepository,
        _signalRepo = signalRepository,
        _seedingRepo = seedingRepository,
        _completenessUseCase = completenessUseCase,
        _purposeRepo = purposeRepository,
        _ctqFactorRepo = ctqFactorRepository,
        _db = db;

  final PlotRepository _plotRepo;
  final RatingRepository _ratingRepo;
  final SessionRepository _sessionRepo;
  final SignalRepository _signalRepo;
  final SeedingRepository _seedingRepo;
  final ComputeSessionCompletenessUseCase _completenessUseCase;
  final TrialPurposeRepository _purposeRepo;
  final CtqFactorDefinitionRepository _ctqFactorRepo;
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
    final applicationsFuture = (_db.select(_db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trial.id))
          ..orderBy([(a) => drift.OrderingTerm.asc(a.applicationDate)]))
        .get();

    // ARM session metadata — queried directly from core DB to respect the
    // ARM separation boundary (no import of ArmColumnMappingRepository).
    final armMetaFuture = (_db.select(_db.armSessionMetadata)
          ..where((m) => m.sessionId.equals(session.id))
          ..limit(1))
        .getSingleOrNull();

    // Check if any ARM metadata exists for the trial (determines ARM-trial flag).
    final armTrialCountFuture = _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM arm_session_metadata '
          'WHERE session_id IN '
          '  (SELECT id FROM sessions WHERE trial_id = ? AND is_deleted = 0)',
          variables: [drift.Variable.withInt(trial.id)],
          readsFrom: {_db.armSessionMetadata, _db.sessions},
        )
        .getSingle()
        .then((r) => r.read<int>('cnt'));

    // Evidence: photos and weather for this session.
    final photosFuture = (_db.select(_db.photos)
          ..where((p) =>
              p.sessionId.equals(session.id) & p.isDeleted.equals(false)))
        .get();
    final weatherFuture = (_db.select(_db.weatherSnapshots)
          ..where((w) => w.parentId.equals(session.id)))
        .get();

    // Flagged plots for this session.
    final flagsFuture = (_db.select(_db.plotFlags)
          ..where((f) => f.sessionId.equals(session.id)))
        .get();

    // Trial purpose — needed by both deviation detection (Section B) and
    // cognition section (Section H). Loaded once here, passed to both.
    final purposeFuture = _purposeRepo.getCurrentTrialPurpose(trial.id);

    // Raw session assessment rows — needed for trialAssessmentId lookup in
    // the standalone protocol deviation path.
    final sessionAssessmentRowsFuture = (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(session.id))
          ..orderBy([
            (sa) => drift.OrderingTerm.asc(sa.sortOrder),
            (sa) => drift.OrderingTerm.asc(sa.id),
          ]))
        .get();

    // ── Await all ────────────────────────────────────────────────────────────
    final plots = await plotsFuture;
    final ratings = await ratingsFuture;
    final correctionPks = await correctionsFuture;
    final assessments = await assessmentsFuture;
    final openSignals = await signalsFuture;
    final seedingEvent = await seedingFuture;
    final applications = await applicationsFuture;
    final armMeta = await armMetaFuture;
    final armTrialCount = await armTrialCountFuture;
    final sessionPhotos = await photosFuture;
    final sessionWeather = await weatherFuture;
    final sessionFlags = await flagsFuture;
    final purpose = await purposeFuture;
    final sessionAssessmentRows = await sessionAssessmentRowsFuture;

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
    final protocolContext = _buildProtocolContext(
      session,
      armMeta,
      armTrialCount,
      ratings,
      seedingEvent,
      applications,
      purpose,
      sessionAssessmentRows,
    );

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
    final assessmentTimingRows = _buildAssessmentTimingRows(
      session: session,
      assessments: assessments,
      seedingEvent: seedingEvent,
      applications: applications,
    );

    // ── Section D: Evidence record ─────────────────────────────────────────────
    // Source: operational tables only (db.photos, db.weatherSnapshots,
    // db.ratingRecords via getCurrentRatingsForSession). The evidence_anchors
    // audit table is NOT read here — that is the CRO-provenance store used by
    // the Evidence Appendix report, not this document.

    // GPS presence derived from current, non-deleted ratings only.
    // Superseded (isCurrent=false) or deleted (isDeleted=true) ratings are
    // excluded by getCurrentRatingsForSession and do not count.
    final hasGps = ratings
        .any((r) => r.capturedLatitude != null && r.capturedLongitude != null);
    final hasWeather = sessionWeather.isNotEmpty;
    final hasTimestamp = DateTime.tryParse(session.sessionDateLocal) != null;
    final sessionDurationMinutes =
        session.endedAt?.difference(session.startedAt).inMinutes;

    final evidenceRecord = FerEvidenceRecord(
      photoCount: sessionPhotos.length,
      photoIds: sessionPhotos.map((p) => p.id).toList(),
      hasGps: hasGps,
      hasWeather: hasWeather,
      hasTimestamp: hasTimestamp,
      sessionDurationMinutes: sessionDurationMinutes,
    );

    // ── Section E: Signals ────────────────────────────────────────────────────
    // getOpenSignalsForSession returns status in {open, deferred, investigating}.
    // Resolved, expired, and suppressed signals are excluded at the repository
    // level. Decision history is not fetched here; each signal.id is available
    // for a future caller to load it via SignalRepository.getDecisionHistory.
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

    final cognition = await _assembleCognitionSection(trial.id, purpose: purpose);

    return FieldExecutionReportData(
      identity: identity,
      protocolContext: protocolContext,
      sessionGrid: sessionGrid,
      assessmentTimingRows: assessmentTimingRows,
      evidenceRecord: evidenceRecord,
      signals: signals,
      completeness: completeness,
      executionStatement: executionStatement,
      cognition: cognition,
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
    List<TrialApplicationEvent> applications,
    TrialPurpose? purpose,
    List<SessionAssessment> sessionAssessmentRows,
  ) {
    final isArmTrial = armTrialCount > 0;
    final isArmLinked = armMeta != null;
    final divergences = <FerProtocolDivergenceRow>[];

    if (!isArmTrial) {
      // Short-circuit: null window means no protocol timing constraint declared.
      // No JSON parsing, no map lookups, no delta computation.
      final window = purpose?.protocolTimingWindow;
      if (window == null) {
        return const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        );
      }

      final rawJson = purpose?.plannedDatByAssessment;
      if (rawJson == null || rawJson.isEmpty) {
        return const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        );
      }

      Map<String, dynamic> plannedMap;
      try {
        plannedMap = jsonDecode(rawJson) as Map<String, dynamic>;
      } catch (_) {
        return const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        );
      }
      if (plannedMap.isEmpty) {
        return const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        );
      }

      // Compute actual DAA from session timing context (same logic as
      // _buildAssessmentTimingRows — one value for the whole session).
      final sessionDate = _tryParseDateOnly(session.sessionDateLocal);
      final priorApplications = sessionDate == null
          ? <TrialApplicationEvent>[]
          : applications
              .where((a) =>
                  a.status == 'applied' &&
                  !_dateOnly(a.applicationDate).isAfter(sessionDate))
              .toList();
      final timing = sessionDate == null
          ? null
          : buildSessionTimingContext(
              sessionStartedAt: sessionDate,
              cropStageBbch: session.cropStageBbch,
              seeding: seedingEvent,
              applications: priorApplications,
            );
      final actualDaa = timing?.daysAfterLastApp;

      for (final sa in sessionAssessmentRows) {
        final taId = sa.trialAssessmentId;
        if (taId == null) continue;
        final raw = plannedMap[taId.toString()];
        if (raw == null) continue; // Graceful: assessment not in plan, no row.
        final plannedDat = switch (raw) {
          int i => i,
          num n => n.toInt(),
          String s => int.tryParse(s),
          _ => null,
        };
        if (plannedDat == null || actualDaa == null) continue;
        final delta = actualDaa - plannedDat;
        if (delta.abs() > window) {
          divergences.add(FerProtocolDivergenceRow(
            type: FerDivergenceType.timing,
            deltaDays: delta,
            actualDat: actualDaa,
            plannedDat: plannedDat,
          ));
        }
      }

      return FerProtocolContext(
        isArmLinked: false,
        isArmTrial: false,
        divergences: divergences,
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

  List<FerAssessmentTimingRow> _buildAssessmentTimingRows({
    required Session session,
    required List<Assessment> assessments,
    required SeedingEvent? seedingEvent,
    required List<TrialApplicationEvent> applications,
  }) {
    final sessionDate = _tryParseDateOnly(session.sessionDateLocal);
    final priorApplications = sessionDate == null
        ? <TrialApplicationEvent>[]
        : applications
            .where((a) =>
                a.status == 'applied' &&
                !_dateOnly(a.applicationDate).isAfter(sessionDate))
            .toList();
    final timing = sessionDate == null
        ? null
        : buildSessionTimingContext(
            sessionStartedAt: sessionDate,
            cropStageBbch: session.cropStageBbch,
            seeding: seedingEvent,
            applications: priorApplications,
          );
    return assessments
        .map((a) => FerAssessmentTimingRow(
              assessmentId: a.id,
              assessmentName: a.name,
              actualDaa: timing?.daysAfterLastApp,
            ))
        .toList();
  }

  DateTime? _tryParseDateOnly(String raw) {
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _dateOnly(parsed);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

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
      parts.add(completeness.warningCount == 1
          ? '1 completeness warning recorded.'
          : '${completeness.warningCount} completeness warnings recorded.');
    }

    return parts.join(' ');
  }

  // ── Section H: Cognition ─────────────────────────────────────────────────────

  Future<FerCognitionSection> _assembleCognitionSection(
    int trialId, {
    required TrialPurpose? purpose,
  }) async {
    final arcDto = await computeTrialEvidenceArcDto(_db, trialId);

    final missingFields = _computeMissingFields(purpose);
    final purposeStatus = _computePurposeStatus(purpose, missingFields);

    final TrialCtqDto ctqDto;
    if (purpose == null) {
      ctqDto = TrialCtqDto(
        trialId: trialId,
        ctqItems: const [],
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        overallStatus: 'unknown',
      );
    } else {
      final factors =
          await _ctqFactorRepo.watchCtqFactorsForPurpose(purpose.id).first;
      ctqDto = factors.isEmpty
          ? TrialCtqDto(
              trialId: trialId,
              ctqItems: const [],
              blockerCount: 0,
              warningCount: 0,
              reviewCount: 0,
              satisfiedCount: 0,
              overallStatus: 'unknown',
            )
          : await computeTrialCtqDtoV1(_db, trialId, factors);
    }

    const actionable = {'blocked', 'review_needed', 'missing'};
    int rank(String s) => switch (s) {
          'blocked' => 0,
          'review_needed' => 1,
          'missing' => 2,
          _ => 3,
        };
    final topItems = (ctqDto.ctqItems
            .where((item) => actionable.contains(item.status))
            .toList()
          ..sort((a, b) => rank(a.status).compareTo(rank(b.status))))
        .take(5)
        .map((item) => FerCognitionAttentionItem(
              factorKey: item.factorKey,
              label: item.label,
              statusLabel: _ctqItemStatusLabel(item.status),
            ))
        .toList();

    // Interpretation risk — requires coherence as input.
    final coherenceDto = await computeTrialCoherenceDto(
      db: _db,
      trialId: trialId,
      signalRepo: _signalRepo,
    );
    final riskDto = await computeTrialInterpretationRiskDto(
      db: _db,
      trialId: trialId,
      coherenceDto: coherenceDto,
    );
    final riskFactors = riskDto.factors
        .where((f) => f.severity != 'none')
        .map((f) => FerRiskFactorItem(
              label: f.label,
              tier: _riskTierLabel(f.severity),
            ))
        .toList();

    return FerCognitionSection(
      purposeStatus: purposeStatus,
      purposeStatusLabel: _purposeStatusLabel(purposeStatus),
      claimBeingTested: purpose?.claimBeingTested,
      primaryEndpoint: purpose?.primaryEndpoint,
      missingIntentFields: List.unmodifiable(missingFields),
      missingIntentFieldLabels:
          List.unmodifiable(missingFields.map(_missingFieldLabel).toList()),
      evidenceState: arcDto.evidenceState,
      evidenceStateLabel: _evidenceStateLabel(arcDto.evidenceState),
      actualEvidenceSummary: arcDto.actualEvidenceSummary,
      missingEvidenceItems: arcDto.missingEvidenceItems,
      ctqOverallStatus: ctqDto.overallStatus,
      ctqOverallStatusLabel: _ctqOverallStatusLabel(ctqDto.overallStatus),
      blockerCount: ctqDto.blockerCount,
      warningCount: ctqDto.warningCount,
      reviewCount: ctqDto.reviewCount,
      satisfiedCount: ctqDto.satisfiedCount,
      topCtqAttentionItems: topItems,
      knownInterpretationFactors: purpose?.knownInterpretationFactors,
      interpretationRiskFactors: riskFactors,
    );
  }

  static String _riskTierLabel(String severity) => switch (severity) {
        'high' => 'HIGH',
        'moderate' => 'MEDIUM',
        _ => 'CANNOT EVALUATE',
      };

  // ── Label helpers (FER-specific; independent of Trial Story widget labels) ───

  static List<String> _computeMissingFields(TrialPurpose? p) {
    if (p == null) {
      return const [
        'claim_being_tested',
        'trial_purpose_context',
        'primary_endpoint',
        'treatment_roles',
      ];
    }
    return [
      if (p.claimBeingTested == null) 'claim_being_tested',
      if (p.trialPurpose == null) 'trial_purpose_context',
      if (p.primaryEndpoint == null) 'primary_endpoint',
      if (p.treatmentRoleSummary == null) 'treatment_roles',
    ];
  }

  static String _computePurposeStatus(
      TrialPurpose? p, List<String> missingFields) {
    if (p == null) return 'unknown';
    if (p.status == 'confirmed' && missingFields.isEmpty) return 'confirmed';
    if (missingFields.length < 4) return 'partial';
    return p.status;
  }

  static String _purposeStatusLabel(String status) => switch (status) {
        'confirmed' => 'Intent confirmed',
        'partial' => 'Intent in progress',
        'draft' => 'Intent in draft',
        _ => 'Intent not captured',
      };

  static String _evidenceStateLabel(String state) => switch (state) {
        'no_evidence' => 'No evidence yet',
        'started' => 'Evidence started',
        'partial' => 'Partial evidence',
        'sufficient_for_review' => 'Sufficient for review',
        'export_ready_candidate' => 'Ready for export review',
        _ => state,
      };

  static String _ctqOverallStatusLabel(String status) => switch (status) {
        'unknown' => 'Not yet evaluated',
        'incomplete' => 'Needs evidence',
        'review_needed' => 'Needs review',
        'ready_for_review' => 'Ready for review',
        _ => status,
      };

  static String _ctqItemStatusLabel(String status) => switch (status) {
        'blocked' => 'Blocked',
        'review_needed' => 'Needs review',
        'missing' => 'Missing',
        'satisfied' => 'Satisfied',
        'not_applicable' => 'Not applicable',
        _ => 'Not evaluated',
      };

  static String _missingFieldLabel(String key) => switch (key) {
        'claim_being_tested' => 'Claim being tested',
        'trial_purpose_context' => 'Trial purpose',
        'primary_endpoint' => 'Primary endpoint',
        'treatment_roles' => 'Treatment roles',
        'known_interpretation_factors' => 'Interpretation factors',
        _ => key,
      };
}
