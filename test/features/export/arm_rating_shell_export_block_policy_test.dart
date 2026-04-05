import 'package:arm_field_companion/domain/models/arm_round_trip_diagnostics.dart';
import 'package:arm_field_companion/features/export/domain/arm_rating_shell_export_block_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateArmRatingShellStrictBlock', () {
    test('passes when anchors are clean and session resolves', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [],
      );
      final x = evaluateArmRatingShellStrictBlock(r);
      expect(x.blocksExport, false);
    });

    test('blocks on duplicateArmPlotNumber even with session', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.duplicateArmPlotNumber,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, true);
    });

    test('blocks on duplicateArmImportColumnIndex', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.duplicateArmImportColumnIndex,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, true);
    });

    test('blocks on missingArmPlotNumber', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.missingArmPlotNumber,
            severity: ArmRoundTripDiagnosticSeverity.info,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, true);
    });

    test('blocks on missingArmImportColumnIndex', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.missingArmImportColumnIndex,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, true);
    });

    test('blocks when resolvedShellSessionId is null', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: null,
        diagnostics: [],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, true);
    });

    test('armImportSessionIdInvalid alone does not block when session resolves',
        () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 5,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.armImportSessionIdInvalid,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, false);
    });

    test('non-blocking advisory codes do not block when session resolves', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 5,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.armImportSessionIdMissing,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.shellSessionResolvedByHeuristic,
            severity: ArmRoundTripDiagnosticSeverity.info,
            message: 'm',
            trialId: 1,
          ),
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.nonRecordedRatingsInShellSession,
            severity: ArmRoundTripDiagnosticSeverity.info,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, false);
    });

    test('fallbackAssessmentMatchUsed does not trigger strict export block', () {
      const r = ArmRoundTripDiagnosticReport(
        trialId: 1,
        resolvedShellSessionId: 9,
        diagnostics: [
          ArmRoundTripDiagnostic(
            code: ArmRoundTripDiagnosticCode.fallbackAssessmentMatchUsed,
            severity: ArmRoundTripDiagnosticSeverity.warning,
            message: 'm',
            trialId: 1,
          ),
        ],
      );
      expect(evaluateArmRatingShellStrictBlock(r).blocksExport, false);
    });
  });
}
