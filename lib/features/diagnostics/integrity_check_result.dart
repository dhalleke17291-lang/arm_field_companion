/// Severity for integrity findings.
enum IntegritySeverity { error, warning, informational }

/// Single finding from an integrity check (read-only; no auto-fix).
class IntegrityIssue {
  final String code;
  final String summary;
  final int count;
  final String? detail;
  final IntegritySeverity severity;

  const IntegrityIssue({
    required this.code,
    required this.summary,
    required this.count,
    this.detail,
    this.severity = IntegritySeverity.warning,
  });
}
