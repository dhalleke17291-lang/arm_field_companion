import '../../../core/diagnostics/diagnostic_finding.dart';

enum TrialCheckSeverity { pass, info, warning, blocker }

class TrialReadinessCheck {
  const TrialReadinessCheck({
    required this.code,
    required this.label,
    this.detail,
    required this.severity,
  });

  final String code;
  final String label;
  final String? detail;
  final TrialCheckSeverity severity;
}

enum TrialReadinessStatus { ready, readyWithWarnings, notReady }

class TrialReadinessReport {
  const TrialReadinessReport({required this.checks});

  final List<TrialReadinessCheck> checks;

  int get blockerCount =>
      checks.where((c) => c.severity == TrialCheckSeverity.blocker).length;
  int get warningCount =>
      checks.where((c) => c.severity == TrialCheckSeverity.warning).length;
  int get passCount =>
      checks.where((c) => c.severity == TrialCheckSeverity.pass).length;
  int get infoCount =>
      checks.where((c) => c.severity == TrialCheckSeverity.info).length;
  bool get canExport => blockerCount == 0;
  TrialReadinessStatus get status => blockerCount > 0
      ? TrialReadinessStatus.notReady
      : warningCount > 0
          ? TrialReadinessStatus.readyWithWarnings
          : TrialReadinessStatus.ready;
}

extension TrialReadinessCheckExtension on TrialReadinessCheck {
  /// Maps this check to a shared [DiagnosticFinding].
  /// Uses [code] as the stable identifier (stable across builds).
  DiagnosticFinding toDiagnosticFinding(int trialId) {
    return DiagnosticFinding(
      code: code,
      severity: switch (severity) {
        TrialCheckSeverity.blocker => DiagnosticSeverity.blocker,
        TrialCheckSeverity.warning => DiagnosticSeverity.warning,
        TrialCheckSeverity.info => DiagnosticSeverity.info,
        TrialCheckSeverity.pass => DiagnosticSeverity.info,
      },
      message: label,
      detail: detail,
      trialId: trialId,
      source: DiagnosticSource.readiness,
      blocksExport: severity == TrialCheckSeverity.blocker,
      blocksAction: false,
    );
  }
}
