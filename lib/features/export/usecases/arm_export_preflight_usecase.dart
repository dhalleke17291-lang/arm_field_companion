import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/diagnostics/diagnostic_finding.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../diagnostics/trial_readiness.dart';
import '../../diagnostics/trial_readiness_service.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../../sessions/session_repository.dart';
import '../../trials/trial_repository.dart';
import '../data/export_repository.dart';
import '../domain/arm_rating_shell_export_block_policy.dart';
import '../domain/compute_arm_round_trip_diagnostics_usecase.dart';
import '../export_confidence_policy.dart';
import '../export_validation_service.dart' as export_validation;
import '../../arm_import/data/arm_import_persistence_repository.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../photos/photo_repository.dart';

/// Summary counts for ARM Rating Shell pre-export trust UI.
class ArmExportPreflightSummary {
  const ArmExportPreflightSummary({
    required this.totalPlots,
    required this.ratedPlots,
    required this.unratedPlots,
    required this.totalAssessments,
    required this.totalRatings,
    required this.correctedRatings,
    required this.voidedRatings,
    required this.sessionName,
    this.sessionDate,
  });

  final int totalPlots;
  final int ratedPlots;
  final int unratedPlots;
  final int totalAssessments;
  final int totalRatings;
  final int correctedRatings;
  final int voidedRatings;
  final String sessionName;
  final String? sessionDate;
}

/// Read-only bundle for ARM shell export preflight (no export performed).
class ArmExportPreflight {
  const ArmExportPreflight({
    required this.summary,
    required this.allFindings,
    required this.blockers,
    required this.warnings,
    required this.infos,
    required this.canExport,
  });

  final ArmExportPreflightSummary summary;
  final List<DiagnosticFinding> allFindings;
  final List<DiagnosticFinding> blockers;
  final List<DiagnosticFinding> warnings;
  final List<DiagnosticFinding> infos;
  final bool canExport;

  int get blockerCount => blockers.length;
  int get warningCount => warnings.length;
}

/// Gathers trial/session summary and merged quality findings before ARM shell export.
class ArmExportPreflightUseCase {
  ArmExportPreflightUseCase({
    required TrialRepository trialRepository,
    required PlotRepository plotRepository,
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required AssignmentRepository assignmentRepository,
    required PhotoRepository photoRepository,
    required ArmImportPersistenceRepository armImportPersistence,
    required ExportRepository exportRepository,
    required ComputeArmRoundTripDiagnosticsUseCase computeArmRoundTripDiagnostics,
  })  : _trialRepository = trialRepository,
        _plotRepository = plotRepository,
        _sessionRepository = sessionRepository,
        _ratingRepository = ratingRepository,
        _trialAssessmentRepository = trialAssessmentRepository,
        _assignmentRepository = assignmentRepository,
        _photoRepository = photoRepository,
        _armImportPersistence = armImportPersistence,
        _exportRepository = exportRepository,
        _computeArmRoundTripDiagnostics = computeArmRoundTripDiagnostics;

  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final SessionRepository _sessionRepository;
  final RatingRepository _ratingRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final AssignmentRepository _assignmentRepository;
  final PhotoRepository _photoRepository;
  final ArmImportPersistenceRepository _armImportPersistence;
  final ExportRepository _exportRepository;
  final ComputeArmRoundTripDiagnosticsUseCase _computeArmRoundTripDiagnostics;

  /// [exportRepository] is injected for parity with export pipeline (session row builder available).
  ExportRepository get exportRepository => _exportRepository;

  Future<ArmExportPreflight> execute({
    required Ref ref,
    required int trialId,
  }) async {
    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) {
      return _failurePreflight(
        trialId: trialId,
        message: 'Trial not found.',
      );
    }
    if (!trial.isArmLinked) {
      return _failurePreflight(
        trialId: trialId,
        message: 'ARM Rating Shell export is only for ARM-linked trials.',
      );
    }

    final plotsAll = await _plotRepository.getPlotsForTrial(trialId);
    final dataPlots =
        plotsAll.where((p) => !p.isDeleted && !p.isGuardRow).toList();
    final totalPlots = dataPlots.length;

    final trialAssessments =
        await _trialAssessmentRepository.getForTrial(trialId);
    final totalAssessments = trialAssessments.length;

    final profile =
        await _armImportPersistence.getLatestCompatibilityProfileForTrial(
      trialId,
    );
    final gate = gateFromConfidence(profile?.exportConfidence);

    final mergedByCode = <String, DiagnosticFinding>{};
    void addFinding(DiagnosticFinding f) {
      if (mergedByCode.containsKey(f.code)) return;
      mergedByCode[f.code] = f;
    }

    if (gate == ExportGate.block) {
      var msg = kBlockedExportMessage;
      final reason = profile?.exportBlockReason;
      if (reason != null && reason.trim().isNotEmpty) {
        msg = '$msg Reason: $reason';
      }
      final finding = gate.toDiagnosticFinding(trialId: trialId, message: msg);
      if (finding != null) addFinding(finding);
    } else if (gate == ExportGate.warn) {
      final finding = gate.toDiagnosticFinding(
        trialId: trialId,
        message: kWarnExportMessage,
      );
      if (finding != null) addFinding(finding);
    }

    final readinessReport =
        await TrialReadinessService().runChecks(trialId.toString(), ref);
    for (final c in readinessReport.checks) {
      if (c.severity == TrialCheckSeverity.pass) continue;
      addFinding(c.toDiagnosticFinding(trialId));
    }

    final roundTripReport = await _computeArmRoundTripDiagnostics.execute(
      trial: trial,
      plots: plotsAll,
      assessments: trialAssessments,
    );
    for (final f in roundTripReport.toDiagnosticFindings()) {
      addFinding(f);
    }

    final strict = evaluateArmRatingShellStrictBlock(roundTripReport);
    if (strict.blocksExport) {
      addFinding(
        DiagnosticFinding(
          code: 'arm_shell_export_strict_gate',
          severity: DiagnosticSeverity.blocker,
          message: strict.userMessage,
          trialId: trialId,
          source: DiagnosticSource.exportValidation,
          blocksExport: true,
        ),
      );
    }

    final sessions = await _sessionRepository.getSessionsForTrial(trialId);
    final assessmentDefs = <int, export_validation.AssessmentDefinition>{};
    for (final s in sessions) {
      final sas = await _sessionRepository.getSessionAssessments(s.id);
      for (final a in sas) {
        assessmentDefs[a.id] =
            export_validation.AssessmentDefinition(id: a.id, name: a.name);
      }
    }
    final records = <RatingRecord>[];
    for (final s in sessions) {
      final rs = await _ratingRepository.getCurrentRatingsForSession(s.id);
      records.addAll(rs);
    }
    final photos = await _photoRepository.getPhotosForTrial(trialId);
    final assignments = await _assignmentRepository.getForTrial(trialId);

    final validation = export_validation.ExportValidationService().validate(
      plots: plotsAll,
      assignments: assignments,
      assessments: assessmentDefs.values.toList(),
      records: records,
      sessions: sessions,
      photos: photos,
    );
    for (final issue in validation.issues) {
      addFinding(issue.toDiagnosticFinding(trialId));
    }

    final merged = mergedByCode.values.toList();

    final blockers =
        merged.where((f) => f.severity == DiagnosticSeverity.blocker).toList();
    final warnings =
        merged.where((f) => f.severity == DiagnosticSeverity.warning).toList();
    final infos =
        merged.where((f) => f.severity == DiagnosticSeverity.info).toList();

    final sessionId = roundTripReport.resolvedShellSessionId;
    String sessionName = '—';
    String? sessionDate;
    var totalRatings = 0;
    var correctedRatings = 0;
    var voidedRatings = 0;
    var ratedPlots = 0;
    var unratedPlots = totalPlots;

    if (sessionId != null) {
      final session = await _sessionRepository.getSessionById(sessionId);
      if (session != null) {
        sessionName = session.name;
        sessionDate = session.sessionDateLocal;
      }
      final sessionRatings =
          await _ratingRepository.getCurrentRatingsForSession(sessionId);
      totalRatings = sessionRatings.length;
      voidedRatings =
          sessionRatings.where((r) => r.resultStatus == 'VOID').length;
      final ids = sessionRatings.map((r) => r.id).toList();
      if (ids.isNotEmpty) {
        final corrRows =
            await _ratingRepository.getCorrectionsForRatingIds(ids);
        correctedRatings =
            corrRows.map((c) => c.ratingId).toSet().length;
      }
      final dataPlotIds = dataPlots.map((p) => p.id).toSet();
      final recordedPks = sessionRatings
          .where((r) =>
              dataPlotIds.contains(r.plotPk) && r.resultStatus == 'RECORDED')
          .map((r) => r.plotPk)
          .toSet();
      ratedPlots = recordedPks.length;
      unratedPlots = totalPlots - ratedPlots;
      if (unratedPlots < 0) unratedPlots = 0;

      // Align totalRatings with export row count when possible (defensive).
      try {
        final rows = await _exportRepository.buildSessionExportRows(
          sessionId: sessionId,
        );
        if (rows.length != totalRatings) {
          totalRatings = rows.length;
        }
      } catch (_) {}
    }

    final canExport = blockers.isEmpty;

    return ArmExportPreflight(
      summary: ArmExportPreflightSummary(
        totalPlots: totalPlots,
        ratedPlots: ratedPlots,
        unratedPlots: unratedPlots,
        totalAssessments: totalAssessments,
        totalRatings: totalRatings,
        correctedRatings: correctedRatings,
        voidedRatings: voidedRatings,
        sessionName: sessionName,
        sessionDate: sessionDate,
      ),
      allFindings: merged,
      blockers: blockers,
      warnings: warnings,
      infos: infos,
      canExport: canExport,
    );
  }

  ArmExportPreflight _failurePreflight({
    required int trialId,
    required String message,
  }) {
    final f = DiagnosticFinding(
      code: 'arm_preflight_fatal',
      severity: DiagnosticSeverity.blocker,
      message: message,
      trialId: trialId,
      source: DiagnosticSource.exportValidation,
      blocksExport: true,
    );
    return ArmExportPreflight(
      summary: const ArmExportPreflightSummary(
        totalPlots: 0,
        ratedPlots: 0,
        unratedPlots: 0,
        totalAssessments: 0,
        totalRatings: 0,
        correctedRatings: 0,
        voidedRatings: 0,
        sessionName: '—',
        sessionDate: null,
      ),
      allFindings: [f],
      blockers: [f],
      warnings: const [],
      infos: const [],
      canExport: false,
    );
  }
}
