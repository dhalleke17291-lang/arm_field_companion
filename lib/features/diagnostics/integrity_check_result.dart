import '../../core/diagnostics/diagnostic_finding.dart';

/// Severity for integrity findings.
enum IntegritySeverity { error, warning, informational }

/// Single finding from an integrity check (read-only; no auto-fix).
class IntegrityIssue {
  final String code;
  final String summary;
  final int count;
  final String? detail;
  final IntegritySeverity severity;
  final bool isRepairable;

  const IntegrityIssue({
    required this.code,
    required this.summary,
    required this.count,
    this.detail,
    this.severity = IntegritySeverity.warning,
    this.isRepairable = false,
  });
}

extension IntegrityIssueExtension on IntegrityIssue {
  DiagnosticFinding toDiagnosticFinding({int? trialId}) {
    final diagSeverity = switch (severity) {
      IntegritySeverity.error => DiagnosticSeverity.blocker,
      IntegritySeverity.warning => DiagnosticSeverity.warning,
      IntegritySeverity.informational => DiagnosticSeverity.info,
    };
    return DiagnosticFinding(
      code: code,
      severity: diagSeverity,
      message: summary,
      detail: detail,
      trialId: trialId,
      source: DiagnosticSource.readiness,
      blocksExport: diagSeverity == DiagnosticSeverity.blocker,
      blocksAction: false,
    );
  }
}
