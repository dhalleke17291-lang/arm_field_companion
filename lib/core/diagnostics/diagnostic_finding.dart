/// Shared model for unified diagnostics across readiness, export validation,
/// and ARM confidence surfaces.
enum DiagnosticSeverity { info, warning, blocker }

enum DiagnosticSource { readiness, exportValidation, armConfidence }

class DiagnosticFinding {
  /// Stable identifier — never changes for UX.
  final String code;

  final DiagnosticSeverity severity;
  final String message;
  final String? detail;
  final int? trialId;
  final int? sessionId;
  final int? plotPk;
  final DiagnosticSource source;
  final bool blocksExport;

  /// True when this finding prevents a specific UI action such as
  /// closing a session or submitting a form.
  /// Currently unused — reserved for future enforcement points.
  /// Do NOT use for export gating (use [blocksExport] for that).
  final bool blocksAction;

  const DiagnosticFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.detail,
    this.trialId,
    this.sessionId,
    this.plotPk,
    required this.source,
    required this.blocksExport,
    this.blocksAction = false,
  });
}
