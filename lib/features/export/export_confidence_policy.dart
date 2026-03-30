/// Import confidence gating for trial-level exports (CSV / ARM / PDF).
enum ExportGate {
  allow,
  warn,
  block,
}

ExportGate gateFromConfidence(String? confidence) {
  switch (confidence) {
    case 'blocked':
      return ExportGate.block;
    case 'low':
      return ExportGate.warn;
    case 'medium':
    case 'high':
    default:
      return ExportGate.allow;
  }
}

const kBlockedExportMessage =
    'Export blocked: import confidence is too low. Review data issues before exporting.';

const kWarnExportMessage =
    'Exporting with warnings: import confidence is low. Review data before use.';

/// Thrown when [ExportGate.block] applies (e.g. compatibility profile confidence is blocked).
class ExportBlockedByConfidenceException implements Exception {
  ExportBlockedByConfidenceException(this.message);

  final String message;

  @override
  String toString() => message;
}
