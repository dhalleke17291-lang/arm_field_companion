import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
import 'package:arm_field_companion/features/export/usecases/arm_export_preflight_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

ArmExportPreflight _preflight({List<DiagnosticFinding> warnings = const []}) {
  return ArmExportPreflight(
    summary: const ArmExportPreflightSummary(
      totalPlots: 0,
      ratedPlots: 0,
      unratedPlots: 0,
      totalAssessments: 0,
      totalRatings: 0,
      correctedRatings: 0,
      voidedRatings: 0,
      sessionName: '—',
      sessionDate: null,
    ),
    allFindings: warnings,
    blockers: const [],
    warnings: warnings,
    infos: const [],
    canExport: true,
  );
}

DiagnosticFinding _warn(String code) => DiagnosticFinding(
      code: code,
      severity: DiagnosticSeverity.warning,
      message: 'x',
      source: DiagnosticSource.armConfidence,
      blocksExport: false,
    );

void main() {
  group('preflightRequiresPositionalConfirmation', () {
    test('returns false when there are no warnings', () {
      expect(preflightRequiresPositionalConfirmation(_preflight()), isFalse);
    });

    test(
      'returns false for non-positional warning codes (data-quality / readiness)',
      () {
        final p = _preflight(warnings: [
          _warn('arm_round_trip_missing_arm_plot_number'),
          _warn('arm_round_trip_duplicate_arm_plot_number'),
          _warn('arm_round_trip_arm_import_session_id_missing'),
          _warn('arm_round_trip_non_recorded_ratings_in_shell_session'),
          _warn('trial_readiness_some_other_check'),
        ]);
        expect(preflightRequiresPositionalConfirmation(p), isFalse);
      },
    );

    test('returns true when assessment matcher fallback is predicted', () {
      final p = _preflight(
        warnings: [_warn('arm_round_trip_fallback_assessment_match_used')],
      );
      expect(preflightRequiresPositionalConfirmation(p), isTrue);
    });

    test('returns true when column index anchors are missing', () {
      final p = _preflight(
        warnings: [_warn('arm_round_trip_missing_arm_import_column_index')],
      );
      expect(preflightRequiresPositionalConfirmation(p), isTrue);
    });

    test('returns true when column index anchors are duplicated', () {
      final p = _preflight(
        warnings: [_warn('arm_round_trip_duplicate_arm_import_column_index')],
      );
      expect(preflightRequiresPositionalConfirmation(p), isTrue);
    });

    test(
      'returns true when positional code appears alongside unrelated warnings',
      () {
        final p = _preflight(warnings: [
          _warn('arm_round_trip_missing_arm_plot_number'),
          _warn('arm_round_trip_fallback_assessment_match_used'),
          _warn('trial_readiness_some_other_check'),
        ]);
        expect(preflightRequiresPositionalConfirmation(p), isTrue);
      },
    );
  });
}
