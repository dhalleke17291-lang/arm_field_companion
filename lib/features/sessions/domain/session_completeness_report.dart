import '../../../core/diagnostics/diagnostic_finding.dart';

/// Severity for [SessionCompletenessIssue]. Blockers prevent [SessionCompletenessReport.canClose].
enum SessionCompletenessIssueSeverity {
  blocker,
  warning,
}

/// Stable codes for completeness findings (export/diagnostics friendly).
enum SessionCompletenessIssueCode {
  /// Session row missing — computation cannot proceed meaningfully.
  sessionNotFound,

  /// Session has no linked assessments (data or configuration error).
  noSessionAssessments,

  /// Target plot has no current rating for a session assessment.
  missingCurrentRating,

  /// Current rating uses voided observation — not allowed for a “complete” plot.
  voidRating,

  /// Current rating exists and is not void, but status is not [ResultStatusDb.recorded].
  nonRecordedStatus,
}

/// One finding from [ComputeSessionCompletenessUseCase].
class SessionCompletenessIssue {
  const SessionCompletenessIssue({
    required this.severity,
    required this.code,
    this.plotPk,
    this.assessmentId,
  });

  final SessionCompletenessIssueSeverity severity;
  final SessionCompletenessIssueCode code;

  /// Null for session-level issues (e.g. session not found).
  final int? plotPk;

  /// Null for session-level issues.
  final int? assessmentId;
}

/// Authoritative session completeness for close eligibility (Phase 2 engine).
///
/// Target population: non-deleted trial plots with [Plot.isGuardRow] == false
/// ([PlotRepository.getPlotsForTrial] already excludes deleted rows).
///
/// A target plot counts toward [completedPlots] only when every session assessment
/// has a **current** rating and none of those ratings are void
/// ([ResultStatusDb.voided]). Other statuses are allowed but emit
/// [SessionCompletenessIssueCode.nonRecordedStatus] warnings.
class SessionCompletenessReport {
  const SessionCompletenessReport({
    required this.expectedPlots,
    required this.completedPlots,
    required this.incompletePlots,
    required this.issues,
    required this.canClose,
  });

  /// Count of target plots (non-guard) in the trial.
  final int expectedPlots;

  /// Target plots that satisfy completeness rules (no missing / void per assessment).
  final int completedPlots;

  /// `expectedPlots - completedPlots`.
  final int incompletePlots;

  /// All blockers and warnings (session- and plot-level).
  final List<SessionCompletenessIssue> issues;

  /// True when there are no blocker-severity issues.
  final bool canClose;
}

extension SessionCompletenessIssueExtension on SessionCompletenessIssue {
  /// Human-readable line aligned with trial detail close-dialog copy.
  DiagnosticFinding toDiagnosticFinding({
    required int trialId,
    required int sessionId,
  }) {
    final diagSeverity = severity == SessionCompletenessIssueSeverity.blocker
        ? DiagnosticSeverity.blocker
        : DiagnosticSeverity.warning;
    final message = switch (code) {
      SessionCompletenessIssueCode.sessionNotFound => 'Session not found.',
      SessionCompletenessIssueCode.noSessionAssessments =>
        'This session has no linked assessments.',
      SessionCompletenessIssueCode.missingCurrentRating =>
        'Missing rating for plot $plotPk (assessment $assessmentId).',
      SessionCompletenessIssueCode.voidRating =>
        'Void rating on plot $plotPk (assessment $assessmentId).',
      SessionCompletenessIssueCode.nonRecordedStatus =>
        'Non-recorded status on plot $plotPk (assessment $assessmentId).',
    };
    return DiagnosticFinding(
      code: code.name,
      severity: diagSeverity,
      message: message,
      trialId: trialId,
      sessionId: sessionId,
      plotPk: plotPk,
      source: DiagnosticSource.sessionCompleteness,
      blocksExport: diagSeverity == DiagnosticSeverity.blocker,
      blocksAction: false,
    );
  }
}
