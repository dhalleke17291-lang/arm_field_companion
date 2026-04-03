import '../../features/diagnostics/integrity_check_result.dart';
import '../../features/diagnostics/trial_readiness.dart';
import '../../features/export/export_validation_service.dart';
import 'diagnostic_finding.dart';

/// Shared severity tier for diagnostics and export validation surfaces.
/// Does not replace feature-specific enums; use the `map*` functions below.
enum UnifiedSeverity {
  blocker,
  warning,
  info,
  pass,
}

/// [TrialCheckSeverity] from `trial_readiness.dart`.
UnifiedSeverity mapTrialCheckSeverity(TrialCheckSeverity severity) {
  return switch (severity) {
    TrialCheckSeverity.pass => UnifiedSeverity.pass,
    TrialCheckSeverity.warning => UnifiedSeverity.warning,
    TrialCheckSeverity.blocker => UnifiedSeverity.blocker,
  };
}

/// [DiagnosticSeverity] from `diagnostic_finding.dart` (info / warning / blocker).
UnifiedSeverity mapFindingDiagnosticSeverity(DiagnosticSeverity severity) {
  return switch (severity) {
    DiagnosticSeverity.info => UnifiedSeverity.info,
    DiagnosticSeverity.warning => UnifiedSeverity.warning,
    DiagnosticSeverity.blocker => UnifiedSeverity.blocker,
  };
}

/// [IntegritySeverity] from `integrity_check_result.dart`.
UnifiedSeverity mapIntegritySeverity(IntegritySeverity severity) {
  return switch (severity) {
    IntegritySeverity.error => UnifiedSeverity.blocker,
    IntegritySeverity.warning => UnifiedSeverity.warning,
    IntegritySeverity.informational => UnifiedSeverity.info,
  };
}

/// [IssueSeverity] from `export_validation_service.dart`.
UnifiedSeverity mapIssueSeverity(IssueSeverity severity) {
  return switch (severity) {
    IssueSeverity.error => UnifiedSeverity.blocker,
    IssueSeverity.warning => UnifiedSeverity.warning,
    IssueSeverity.info => UnifiedSeverity.info,
  };
}
