import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/export_trial_pdf_report_usecase.dart';
import 'package:arm_field_companion/features/export/report_data_assembly_service.dart';
import 'package:arm_field_companion/features/export/standalone_report_data.dart';

Trial _trial({int id = 1, String name = 'Test Trial'}) => Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
    );

class MockReportDataAssemblyService implements ReportDataAssemblyService {
  StandaloneReportData? lastAssembled;

  @override
  Future<StandaloneReportData> assembleForTrial(Trial trial) async {
    lastAssembled = StandaloneReportData(
      trial: TrialReportSummary(
        id: trial.id,
        name: trial.name,
        status: trial.status,
        workspaceType: trial.workspaceType,
      ),
      treatments: [],
      plots: [],
      sessions: [],
      applications: const ApplicationsReportSummary(count: 0, events: []),
      photoCount: const PhotoReportSummary(count: 0),
    );
    return lastAssembled!;
  }
}

void main() {
  late ExportTrialPdfReportUseCase useCase;
  late MockReportDataAssemblyService mockAssembly;

  setUp(() {
    mockAssembly = MockReportDataAssemblyService();
    useCase = ExportTrialPdfReportUseCase(assemblyService: mockAssembly);
  });

  group('ExportTrialPdfReportUseCase', () {
    test('SUCCESS: calls assembly then throws PdfReportNotImplementedException',
        () async {
      final trial = _trial(name: 'Canola 2026');

      expect(
        () => useCase.execute(trial: trial),
        throwsA(isA<PdfReportNotImplementedException>()
            .having((e) => e.message, 'message',
                contains('PDF report generation is not implemented yet'))
            .having((e) => e.trialName, 'trialName', 'Canola 2026')),
      );
    });

    test('SUCCESS: assembly is invoked before exception', () async {
      final trial = _trial(name: 'Wheat Trial');

      try {
        await useCase.execute(trial: trial);
      } catch (_) {}

      expect(mockAssembly.lastAssembled, isNotNull);
      expect(mockAssembly.lastAssembled!.trial.name, 'Wheat Trial');
    });
  });
}
