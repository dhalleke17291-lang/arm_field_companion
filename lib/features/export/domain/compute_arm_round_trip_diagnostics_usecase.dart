import '../../../core/database/app_database.dart';
import '../../../core/diagnostics/diagnostic_finding.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../domain/models/arm_round_trip_diagnostics.dart';
import '../../../domain/ratings/result_status.dart';
import 'arm_shell_data_plots.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../../sessions/session_repository.dart';

/// Deterministic ARM mapping-integrity checks for ARM-linked trials.
///
/// Non-blocking: findings map to [DiagnosticFinding] with [blocksExport] false.
class ComputeArmRoundTripDiagnosticsUseCase {
  ComputeArmRoundTripDiagnosticsUseCase({
    required PlotRepository plotRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
  })  : _plotRepository = plotRepository,
        _trialAssessmentRepository = trialAssessmentRepository,
        _sessionRepository = sessionRepository,
        _ratingRepository = ratingRepository;

  final PlotRepository _plotRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final SessionRepository _sessionRepository;
  final RatingRepository _ratingRepository;

  /// When [plots] / [assessments] are omitted, they are loaded from repositories.
  Future<ArmRoundTripDiagnosticReport> execute({
    required Trial trial,
    List<Plot>? plots,
    List<TrialAssessment>? assessments,
  }) async {
    if (!trial.isArmLinked) {
      return ArmRoundTripDiagnosticReport(
        trialId: trial.id,
        resolvedShellSessionId: null,
        diagnostics: const [],
      );
    }

    final plotList = plots ?? await _plotRepository.getPlotsForTrial(trial.id);
    final assessmentList =
        assessments ?? await _trialAssessmentRepository.getForTrial(trial.id);

    final resolved =
        await _sessionRepository.resolveSessionIdForRatingShell(trial);

    final out = <ArmRoundTripDiagnostic>[];

    _applyPlotRules(plotList, trial.id, out);
    _applyAssessmentColumnRules(assessmentList, trial.id, out);
    await _applySessionAndRatingRules(trial, resolved, plotList, out);

    return ArmRoundTripDiagnosticReport(
      trialId: trial.id,
      resolvedShellSessionId: resolved,
      diagnostics: out,
    );
  }

  void _applyPlotRules(List<Plot> plots, int trialId, List<ArmRoundTripDiagnostic> out) {
    final dataPlots = armShellDataPlots(plots);

    final guardsWithArm =
        plots.where((p) => p.isGuardRow && p.armPlotNumber != null).toList();
    if (guardsWithArm.isNotEmpty) {
      final pks = guardsWithArm.map((p) => p.id).toList()..sort();
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.guardHasArmPlotNumber,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              '${guardsWithArm.length} guard row(s) have an ARM plot number set; '
              'shell export uses data plots only.',
          detail: 'Plot ids: ${pks.join(", ")}',
          trialId: trialId,
        ),
      );
    }

    final missingArm = dataPlots.where((p) => p.armPlotNumber == null).toList();
    if (missingArm.isNotEmpty) {
      final pks = missingArm.map((p) => p.id).toList()..sort();
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.missingArmPlotNumber,
          severity: ArmRoundTripDiagnosticSeverity.info,
          message:
              '${missingArm.length} data plot(s) have no ARM plot number (armPlotNumber).',
          detail: 'Plot ids: ${pks.join(", ")}',
          trialId: trialId,
        ),
      );
    }

    final byArm = <int, List<Plot>>{};
    for (final p in dataPlots) {
      final n = p.armPlotNumber;
      if (n == null) continue;
      byArm.putIfAbsent(n, () => []).add(p);
    }
    for (final entry in byArm.entries) {
      if (entry.value.length <= 1) continue;
      final sorted = [...entry.value]..sort((a, b) => a.id.compareTo(b.id));
      final pks = sorted.map((p) => p.id).join(', ');
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.duplicateArmPlotNumber,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              'Duplicate armPlotNumber ${entry.key} on ${entry.value.length} data plots.',
          detail: 'Plot ids (lowest id used first in shell export): $pks',
          trialId: trialId,
          plotPk: sorted.first.id,
        ),
      );
    }
  }

  void _applyAssessmentColumnRules(
    List<TrialAssessment> assessments,
    int trialId,
    List<ArmRoundTripDiagnostic> out,
  ) {
    final missingIdx =
        assessments.where((a) => a.armImportColumnIndex == null).toList();
    if (missingIdx.isNotEmpty) {
      final ids = missingIdx.map((a) => a.id).toList()..sort();
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.missingArmImportColumnIndex,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              '${missingIdx.length} trial assessment(s) have no armImportColumnIndex.',
          detail: 'TrialAssessment ids: ${ids.join(", ")}',
          trialId: trialId,
        ),
      );
    }

    final byCol = <int, List<TrialAssessment>>{};
    for (final a in assessments) {
      final c = a.armImportColumnIndex;
      if (c == null) continue;
      byCol.putIfAbsent(c, () => []).add(a);
    }
    for (final entry in byCol.entries) {
      if (entry.value.length <= 1) continue;
      final ids = entry.value.map((a) => a.id).toList()..sort();
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.duplicateArmImportColumnIndex,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              'Duplicate armImportColumnIndex ${entry.key} on ${entry.value.length} trial assessments.',
          detail: 'TrialAssessment ids: ${ids.join(", ")}',
          trialId: trialId,
        ),
      );
    }
  }

  Future<void> _applySessionAndRatingRules(
    Trial trial,
    int? resolved,
    List<Plot> plots,
    List<ArmRoundTripDiagnostic> out,
  ) async {
    final dataPlotPks = armShellDataPlots(plots).map((p) => p.id).toSet();
    final pinned = trial.armImportSessionId;

    if (pinned == null) {
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.armImportSessionIdMissing,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              'trials.armImportSessionId is not set; shell export session is inferred.',
          detail: resolved != null ? 'Resolved session id: $resolved' : null,
          trialId: trial.id,
          sessionId: resolved,
        ),
      );
    }

    if (pinned != null && resolved != pinned) {
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.armImportSessionIdInvalid,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              'trials.armImportSessionId ($pinned) does not match a non-deleted session used for export.',
          detail: resolved != null
              ? 'Resolved session id: $resolved'
              : 'No session could be resolved for this trial.',
          trialId: trial.id,
          sessionId: resolved,
        ),
      );
    }

    if (resolved != null && (pinned == null || resolved != pinned)) {
      out.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.shellSessionResolvedByHeuristic,
          severity: ArmRoundTripDiagnosticSeverity.info,
          message:
              'Rating shell export session was resolved by heuristic (not a pinned armImportSessionId).',
          detail: pinned == null
              ? 'Session id: $resolved'
              : 'Pinned id $pinned was unusable; using session id: $resolved',
          trialId: trial.id,
          sessionId: resolved,
        ),
      );
    }

    if (resolved != null) {
      final ratings =
          await _ratingRepository.getCurrentRatingsForSession(resolved);
      final nonRecorded = ratings
          .where(
            (r) =>
                dataPlotPks.contains(r.plotPk) &&
                r.resultStatus != ResultStatusDb.recorded,
          )
          .toList();
      if (nonRecorded.isNotEmpty) {
        out.add(
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.nonRecordedRatingsInShellSession,
            severity: ArmRoundTripDiagnosticSeverity.info,
            message:
                '${nonRecorded.length} current rating(s) in the shell session are not RECORDED.',
            detail:
                'Statuses: ${nonRecorded.map((r) => r.resultStatus).toSet().join(", ")}',
            trialId: trial.id,
            sessionId: resolved,
          ),
        );
      }
    }
  }
}

/// Maps round-trip diagnostics to the shared [DiagnosticFinding] pipeline.
extension ArmRoundTripDiagnosticReportX on ArmRoundTripDiagnosticReport {
  List<DiagnosticFinding> toDiagnosticFindings() {
    return diagnostics.map((d) => d.toDiagnosticFinding()).toList();
  }
}

extension ArmRoundTripDiagnosticX on ArmRoundTripDiagnostic {
  DiagnosticFinding toDiagnosticFinding() {
    return DiagnosticFinding(
      code: _findingCode,
      severity: switch (severity) {
        ArmRoundTripDiagnosticSeverity.info => DiagnosticSeverity.info,
        ArmRoundTripDiagnosticSeverity.warning => DiagnosticSeverity.warning,
      },
      message: message,
      detail: detail,
      trialId: trialId,
      sessionId: sessionId,
      plotPk: plotPk,
      source: DiagnosticSource.armConfidence,
      blocksExport: false,
    );
  }

  String get _findingCode => switch (code) {
        ArmRoundTripDiagnosticCode.missingArmPlotNumber =>
          'arm_round_trip_missing_arm_plot_number',
        ArmRoundTripDiagnosticCode.duplicateArmPlotNumber =>
          'arm_round_trip_duplicate_arm_plot_number',
        ArmRoundTripDiagnosticCode.missingArmImportColumnIndex =>
          'arm_round_trip_missing_arm_import_column_index',
        ArmRoundTripDiagnosticCode.duplicateArmImportColumnIndex =>
          'arm_round_trip_duplicate_arm_import_column_index',
        ArmRoundTripDiagnosticCode.armImportSessionIdMissing =>
          'arm_round_trip_arm_import_session_id_missing',
        ArmRoundTripDiagnosticCode.armImportSessionIdInvalid =>
          'arm_round_trip_arm_import_session_id_invalid',
        ArmRoundTripDiagnosticCode.shellSessionResolvedByHeuristic =>
          'arm_round_trip_shell_session_resolved_by_heuristic',
        ArmRoundTripDiagnosticCode.nonRecordedRatingsInShellSession =>
          'arm_round_trip_non_recorded_ratings_in_shell_session',
        ArmRoundTripDiagnosticCode.guardHasArmPlotNumber =>
          'arm_round_trip_guard_has_arm_plot_number',
        ArmRoundTripDiagnosticCode.fallbackAssessmentMatchUsed =>
          'arm_round_trip_fallback_assessment_match_used',
      };
}
