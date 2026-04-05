import '../../../core/database/app_database.dart';
import '../../../domain/models/arm_round_trip_diagnostics.dart';

/// True when shell export is expected to resolve assessment columns from ARM
/// anchors, not positional guesswork: every [TrialAssessment] has
/// [TrialAssessment.armImportColumnIndex] and the latest compatibility profile
/// records high import confidence (`exportConfidence == 'high'` on the profile).
///
/// Used for Phase 3 strict blocking when [ExportArmRatingShellUseCase] still
/// relies on positional column matching for one or more assessments.
bool deterministicAssessmentAnchorsExpectedForShellExport({
  required List<TrialAssessment> assessments,
  required String? latestProfileExportConfidence,
}) {
  if (assessments.isEmpty) return false;
  final allAnchored =
      assessments.every((a) => a.armImportColumnIndex != null);
  final highConfidence = latestProfileExportConfidence == 'high';
  return allAnchored && highConfidence;
}

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
///
/// **Phase 3:** When [positionalAssessmentFallbackUsed] is true, or the report
/// already contains [ArmRoundTripDiagnosticCode.fallbackAssessmentMatchUsed],
/// and [deterministicAssessmentAnchorsExpected] is true, export is blocked —
/// positional matching is unsafe under high-confidence, fully anchored trials.
/// Legacy or lower-confidence imports keep fallback as a warning only.
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
///
/// [positionalAssessmentFallbackUsed] and [deterministicAssessmentAnchorsExpected]
/// are normally omitted on the first (pre-shell) call. After shell parsing,
/// [ExportArmRatingShellUseCase] calls again with
/// `positionalAssessmentFallbackUsed: true` when fallback occurred, plus the
/// computed [deterministicAssessmentAnchorsExpected] flag.
ArmRatingShellStrictBlockResult evaluateArmRatingShellStrictBlock(
  ArmRoundTripDiagnosticReport report, {
  bool positionalAssessmentFallbackUsed = false,
  bool deterministicAssessmentAnchorsExpected = false,
}) {
  final codes = {for (final d in report.diagnostics) d.code};
  final fallbackFromReport =
      codes.contains(ArmRoundTripDiagnosticCode.fallbackAssessmentMatchUsed);
  final positionalFallbackTriggersPhase3 =
      positionalAssessmentFallbackUsed || fallbackFromReport;

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

  if (positionalFallbackTriggersPhase3 &&
      deterministicAssessmentAnchorsExpected) {
    return ArmRatingShellStrictBlockResult.block(
      'ARM Rating Shell export blocked: assessment columns were matched by '
      'shell position instead of ARM column anchors. With high import '
      'confidence and full armImportColumnIndex data, fix column identity '
      '(pest code, unit, or shell layout) before exporting.',
    );
  }

  return ArmRatingShellStrictBlockResult.pass;
}
