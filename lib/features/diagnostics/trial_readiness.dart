enum TrialCheckSeverity { pass, warning, blocker }

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
  bool get canExport => blockerCount == 0;
  TrialReadinessStatus get status => blockerCount > 0
      ? TrialReadinessStatus.notReady
      : warningCount > 0
          ? TrialReadinessStatus.readyWithWarnings
          : TrialReadinessStatus.ready;
}
