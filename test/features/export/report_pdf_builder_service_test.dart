import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/export/report_pdf_builder_service.dart';
import 'package:arm_field_companion/features/export/standalone_report_data.dart';

void main() {
  late ReportPdfBuilderService service;

  setUp(() {
    service = ReportPdfBuilderService();
  });

  group('ReportPdfBuilderService', () {
    test('build returns non-empty PDF bytes', () async {
      const data = StandaloneReportData(
        trial: TrialReportSummary(
          id: 1,
          name: 'Test Trial',
          status: 'active',
          workspaceType: 'efficacy',
        ),
        treatments: [
          TreatmentReportSummary(
            id: 1,
            code: 'T1',
            name: 'Control',
            treatmentType: 'control',
            componentCount: 0,
          ),
        ],
        plots: [
          PlotReportSummary(
            plotPk: 1,
            plotId: 'P1',
            rep: 1,
            treatmentCode: 'T1',
          ),
        ],
        sessions: [
          SessionReportSummary(
            id: 1,
            name: 'Session 1',
            sessionDateLocal: '2026-03-18',
            status: 'closed',
          ),
        ],
        applications: ApplicationsReportSummary(count: 0, events: []),
        photoCount: PhotoReportSummary(count: 0),
      );

      final bytes = await service.build(data);

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2d]); // %PDF-
    });
  });
}
