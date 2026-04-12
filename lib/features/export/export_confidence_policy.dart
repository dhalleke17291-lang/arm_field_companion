import '../../core/diagnostics/diagnostic_finding.dart';

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
    'Export blocked — data needs review before rating sheet round-trip.';

const kWarnExportMessage =
    'Export may need review — check imported data before relying on rating sheet export.';

/// Full user-facing message when export is blocked, optionally appending
/// concrete reasons from [exportBlockReason] (no "Reason:" developer phrasing).
String composeBlockedExportMessage(String? exportBlockReason) {
  final detail = exportBlockReason?.trim();
  if (detail == null || detail.isEmpty) return kBlockedExportMessage;
  return '$kBlockedExportMessage\n\n$detail';
}

/// Thrown when [ExportGate.block] applies (trial not ready for ARM round-trip).
class ExportBlockedByConfidenceException implements Exception {
  ExportBlockedByConfidenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension ExportGateExtension on ExportGate {
  /// Converts a confidence gate decision to a [DiagnosticFinding].
  /// Only warn and block produce meaningful findings.
  /// allow returns null — no finding needed.
  DiagnosticFinding? toDiagnosticFinding({
    required int trialId,
    required String message,
  }) {
    return switch (this) {
      ExportGate.block => DiagnosticFinding(
          code: 'arm_confidence_block',
          severity: DiagnosticSeverity.blocker,
          message: message,
          trialId: trialId,
          source: DiagnosticSource.armConfidence,
          blocksExport: true,
        ),
      ExportGate.warn => DiagnosticFinding(
          code: 'arm_confidence_warn',
          severity: DiagnosticSeverity.warning,
          message: message,
          trialId: trialId,
          source: DiagnosticSource.armConfidence,
          blocksExport: false,
        ),
      ExportGate.allow => null,
    };
  }
}
