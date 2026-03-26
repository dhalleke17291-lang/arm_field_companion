import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/export_trial_pdf_report_usecase.dart';
import 'package:arm_field_companion/features/export/report_data_assembly_service.dart';
import 'package:arm_field_companion/features/export/report_pdf_builder_service.dart';
import 'package:arm_field_companion/features/export/standalone_report_data.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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

class FakeReportPdfBuilderService extends ReportPdfBuilderService {
  StandaloneReportData? lastBuilt;
  static final _pdfHeader = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-

  @override
  Future<Uint8List> build(
    StandaloneReportData data, {
    ReportProfile profile = ReportProfile.research,
  }) async {
    lastBuilt = data;
    return Uint8List.fromList(_pdfHeader + List.filled(200, 0));
  }
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

void main() {
  late ExportTrialPdfReportUseCase useCase;
  late MockReportDataAssemblyService mockAssembly;
  late FakeReportPdfBuilderService fakePdfBuilder;
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('pdf_report_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    mockAssembly = MockReportDataAssemblyService();
    fakePdfBuilder = FakeReportPdfBuilderService();
    useCase = ExportTrialPdfReportUseCase(
      assemblyService: mockAssembly,
      pdfBuilder: fakePdfBuilder,
      shareOverride: (files, {String? text}) async {},
    );
  });

  group('ExportTrialPdfReportUseCase', () {
    test('SUCCESS: assembles, builds, writes, and shares', () async {
      final trial = _trial(name: 'Canola 2026');

      await useCase.execute(trial: trial);

      expect(mockAssembly.lastAssembled, isNotNull);
      expect(mockAssembly.lastAssembled!.trial.name, 'Canola 2026');
      expect(fakePdfBuilder.lastBuilt, isNotNull);
      expect(fakePdfBuilder.lastBuilt!.trial.name, 'Canola 2026');

      final files = Directory(tempPath)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('AGQ_Canola_2026_') && f.path.endsWith('.pdf'))
          .toList();
      expect(files, isNotEmpty);
      final file = files.first;
      final bytes = await file.readAsBytes();
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2d]);
    });

    test('SUCCESS: assembly is invoked before build', () async {
      final trial = _trial(name: 'Wheat Trial');

      await useCase.execute(trial: trial);

      expect(mockAssembly.lastAssembled, isNotNull);
      expect(mockAssembly.lastAssembled!.trial.name, 'Wheat Trial');
      expect(fakePdfBuilder.lastBuilt!.trial.name, 'Wheat Trial');
    });

    test('SUCCESS: filename uses safe name pattern', () async {
      final trial = _trial(name: 'Trial With Spaces & Special!');

      await useCase.execute(trial: trial);

      final files = Directory(tempPath)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'));
      expect(files, isNotEmpty);
      expect(
        files.any((f) => f.path.contains('AGQ_') && f.path.contains('.pdf')),
        isTrue,
      );
    });
  });
}
