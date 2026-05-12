import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportFormatDetails', () {
    test('primary export labels are explicit user-facing document names', () {
      expect(ExportFormat.pdfReport.label, 'Trial Results Summary');
      expect(ExportFormat.trialReport.label, 'Trial Report');
      expect(ExportFormat.evidenceReport.label, 'Trial Evidence Record');
      expect(ExportFormat.armHandoff.label, 'ARM Handoff Package');
    });
  });
}
