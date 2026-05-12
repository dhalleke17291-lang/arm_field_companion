import 'package:arm_field_companion/domain/trial_cognition/trial_readiness_statement.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure unit tests for the bridge function that maps a
/// [TrialReadinessStatement] (cognition layer) to a single
/// [TrialReadinessCheck] (diagnostics layer).
///
/// Three-state coverage:
///   - ready              → pass
///   - ready_with_cautions → warning
///   - not_ready          → blocker

TrialReadinessStatement _readyStatement() => const TrialReadinessStatement(
      statusLabel: 'Export ready',
      summaryText: 'Trial is ready for export and analysis.',
      reasons: [],
      actionItems: [],
      cautions: [],
      isReadyForExport: true,
    );

TrialReadinessStatement _readyWithCautionsStatement({
  required List<String> cautions,
}) =>
    TrialReadinessStatement(
      statusLabel: 'Export ready',
      summaryText: 'Trial is ready for export and analysis.',
      reasons: const [],
      actionItems: const [],
      cautions: cautions,
      isReadyForExport: true,
    );

TrialReadinessStatement _notReadyStatement({
  required List<String> actionItems,
  List<String> cautions = const [],
}) =>
    TrialReadinessStatement(
      statusLabel: 'Not export-ready',
      summaryText: 'Trial is not currently export-ready.',
      reasons: const [],
      actionItems: actionItems,
      cautions: cautions,
      isReadyForExport: false,
    );

void main() {
  group('buildCognitionReadinessCheck', () {
    test('Bridge-1: ready + empty cautions → pass check', () {
      final check = buildCognitionReadinessCheck(_readyStatement());

      expect(check.code, 'trial_cognition_ready');
      expect(check.severity, TrialCheckSeverity.pass);
      expect(check.detail, isNull);
      expect(check.label, contains('export-ready'));
    });

    test('Bridge-2: ready + non-empty cautions → warning check with detail',
        () {
      final check = buildCognitionReadinessCheck(
        _readyWithCautionsStatement(cautions: const [
          'CV on primary endpoint assessment is 32%.',
          'Site/season condition noted: drought stress this season.',
        ]),
      );

      expect(check.code, 'trial_cognition_ready_with_cautions');
      expect(check.severity, TrialCheckSeverity.warning);
      expect(check.detail, isNotNull);
      expect(check.detail, contains('CV on primary endpoint assessment is 32%.'));
      expect(check.detail,
          contains('drought stress this season'));
      expect(check.label, contains('cautions'));
    });

    test('Bridge-3: not ready → blocker check with actionItems detail', () {
      final check = buildCognitionReadinessCheck(
        _notReadyStatement(actionItems: const [
          'Resolve: Primary endpoint data',
          'Add: Photo Evidence',
        ]),
      );

      expect(check.code, 'trial_cognition_not_export_ready');
      expect(check.severity, TrialCheckSeverity.blocker);
      expect(check.detail, isNotNull);
      expect(check.detail, contains('Resolve: Primary endpoint data'));
      expect(check.detail, contains('Add: Photo Evidence'));
    });

    test(
        'Bridge-3b: not ready + empty actionItems → blocker check falls back to summaryText',
        () {
      // Edge case: !isReadyForExport but no actionItems and no cautions.
      // Detail should fall back to summaryText rather than render an empty string.
      final check = buildCognitionReadinessCheck(
        _notReadyStatement(actionItems: const []),
      );

      expect(check.code, 'trial_cognition_not_export_ready');
      expect(check.severity, TrialCheckSeverity.blocker);
      expect(check.detail, 'Trial is not currently export-ready.');
    });

    test('Bridge-truncation: cautions list of 8 truncates to 6 in detail', () {
      final manyCautions = List.generate(8, (i) => 'caution-$i');
      final check = buildCognitionReadinessCheck(
        _readyWithCautionsStatement(cautions: manyCautions),
      );

      expect(check.severity, TrialCheckSeverity.warning);
      expect(check.detail, isNotNull);
      // First 6 included; last 2 not.
      for (var i = 0; i < 6; i++) {
        expect(check.detail, contains('caution-$i'));
      }
      expect(check.detail, isNot(contains('caution-6')));
      expect(check.detail, isNot(contains('caution-7')));
    });
  });
}
