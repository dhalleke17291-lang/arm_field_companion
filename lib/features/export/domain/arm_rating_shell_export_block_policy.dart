import '../../../domain/models/arm_round_trip_diagnostics.dart';

/// Phase 2 — strict gate for **ARM Rating Shell** export only.
///
/// Evaluates [ArmRoundTripDiagnosticReport] for **high-confidence structural**
/// anchor failures (plot numbers, assessment column indexes, resolvable export
/// session). This is **not** full ARM semantic correctness: it does **not**
/// block on heuristic session choice, missing [Trial.armImportSessionId] when
/// a session still resolves, non-recorded rating statuses, or snapshot/count
/// semantics — those remain advisory via the same report’s diagnostics.
///
/// [armImportSessionIdInvalid] is **not** a direct blocker here: when a fallback
/// session resolves, export continues. When **no** session resolves
/// ([ArmRoundTripDiagnosticReport.resolvedShellSessionId] is null), export
/// blocks — which covers invalid pin with no usable session as well as an
/// empty session list.
class ArmRatingShellStrictBlockResult {
  final bool blocksExport;
  final String userMessage;

  const ArmRatingShellStrictBlockResult._({
    required this.blocksExport,
    required this.userMessage,
  });

  static const ArmRatingShellStrictBlockResult pass =
      ArmRatingShellStrictBlockResult._(
    blocksExport: false,
    userMessage: '',
  );

  factory ArmRatingShellStrictBlockResult.block(String userMessage) {
    return ArmRatingShellStrictBlockResult._(
      blocksExport: true,
      userMessage: userMessage,
    );
  }
}

/// Returns [ArmRatingShellStrictBlockResult.pass] when export may proceed past
/// protocol checks; otherwise a block result with a short user-facing message.
ArmRatingShellStrictBlockResult evaluateArmRatingShellStrictBlock(
  ArmRoundTripDiagnosticReport report,
) {
  final codes = {for (final d in report.diagnostics) d.code};

  if (codes.contains(ArmRoundTripDiagnosticCode.duplicateArmPlotNumber)) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: duplicate armPlotNumber on plots. '
      'Resolve duplicate ARM plot numbers before exporting.',
    );
  }
  if (codes.contains(ArmRoundTripDiagnosticCode.duplicateArmImportColumnIndex)) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: duplicate armImportColumnIndex on '
      'trial assessments. Fix column indexes before exporting.',
    );
  }
  if (codes.contains(ArmRoundTripDiagnosticCode.missingArmPlotNumber)) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: one or more data plots are missing '
      'armPlotNumber. Assign ARM plot numbers before exporting.',
    );
  }
  if (codes.contains(ArmRoundTripDiagnosticCode.missingArmImportColumnIndex)) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: one or more trial assessments are '
      'missing armImportColumnIndex. Set column indexes before exporting.',
    );
  }

  if (report.resolvedShellSessionId == null) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: no session is available for rating '
      'export. Add or restore a session for this trial before exporting.',
    );
  }

  return ArmRatingShellStrictBlockResult.pass;
}
