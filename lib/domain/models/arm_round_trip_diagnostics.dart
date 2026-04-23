/// Severity for ARM round-trip mapping diagnostics (export-time, non-blocking).
enum ArmRoundTripDiagnosticSeverity {
  info,
  warning,
}

/// Stable rule identifiers for ARM anchor integrity checks.
enum ArmRoundTripDiagnosticCode {
  missingArmPlotNumber,
  duplicateArmPlotNumber,
  missingArmImportColumnIndex,
  duplicateArmImportColumnIndex,
  armImportSessionIdMissing,
  armImportSessionIdInvalid,
  shellSessionResolvedByHeuristic,
  nonRecordedRatingsInShellSession,

  /// Guard row has [Plot.armPlotNumber] set (protocol misuse; shell ignores guards).
  guardHasArmPlotNumber,

  /// Shell column was chosen by position; `ArmAssessmentMetadata.armImportColumnIndex`
  /// and rating-type/unit identity did not resolve a unique column.
  fallbackAssessmentMatchUsed,
}

/// One finding from [ComputeArmRoundTripDiagnosticsUseCase].
class ArmRoundTripDiagnostic {
  final ArmRoundTripDiagnosticCode code;
  final ArmRoundTripDiagnosticSeverity severity;
  final String message;
  final String? detail;
  final int trialId;
  final int? sessionId;
  final int? plotPk;

  const ArmRoundTripDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.detail,
    required this.trialId,
    this.sessionId,
    this.plotPk,
  });
}

/// Aggregated round-trip report for a single trial.
class ArmRoundTripDiagnosticReport {
  final int trialId;

  /// Result of [SessionRepository.resolveSessionIdForRatingShell] for this trial.
  /// Used by Phase 2 strict export policy (e.g. block when no session resolves).
  final int? resolvedShellSessionId;

  final List<ArmRoundTripDiagnostic> diagnostics;

  const ArmRoundTripDiagnosticReport({
    required this.trialId,
    this.resolvedShellSessionId,
    required this.diagnostics,
  });
}
