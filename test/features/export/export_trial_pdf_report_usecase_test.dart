import 'dart:io';
import 'dart:typed_data';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/export_confidence_policy.dart';
import 'package:arm_field_companion/features/export/export_trial_pdf_report_usecase.dart';
import 'package:arm_field_companion/features/export/report_data_assembly_service.dart';
import 'package:arm_field_companion/features/export/report_pdf_builder_service.dart';
import 'package:arm_field_companion/features/export/standalone_report_data.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

Future<void> _insertCompatibilityProfile({
  required AppDatabase db,
  required int trialId,
  required ImportConfidence exportConfidence,
  String? exportBlockReason,
}) async {
  final repo = ArmImportPersistenceRepository(db);
  const snapPayload = ImportSnapshotPayload(
    sourceFile: 't.csv',
    sourceRoute: 'arm_csv_v1',
    armVersion: null,
    rawHeaders: [],
    columnOrder: [],
    rowTypePatterns: [],
    plotCount: 0,
    treatmentCount: 0,
    assessmentCount: 0,
    identityColumns: [],
    assessmentTokens: [],
    treatmentTokens: [],
    plotTokens: [],
    unknownPatterns: [],
    hasSubsamples: false,
    hasMultiApplication: false,
    hasSparseData: false,
    hasRepeatedCodes: false,
    rawFileChecksum: 'chk',
  );
  final snapshotId = await repo.insertImportSnapshot(snapPayload, trialId: trialId);
  final profilePayload = CompatibilityProfilePayload(
    exportRoute: 'arm_xml_v1',
    columnMap: {},
    plotMap: {},
    treatmentMap: {},
    dataStartRow: 2,
    headerEndRow: 1,
    identityRowMarkers: const [],
    columnOrderOnExport: const [],
    identityFieldOrder: const [],
    knownUnsupported: const [],
    exportConfidence: exportConfidence,
    exportBlockReason: exportBlockReason,
  );
  await repo.insertCompatibilityProfile(
    profilePayload,
    trialId: trialId,
    snapshotId: snapshotId,
  );
}

Trial _trial({int id = 1, String name = 'Test Trial'}) => Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      isArmLinked: false,
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
  late AppDatabase db;
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('pdf_report_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockAssembly = MockReportDataAssemblyService();
    fakePdfBuilder = FakeReportPdfBuilderService();
    useCase = ExportTrialPdfReportUseCase(
      assemblyService: mockAssembly,
      pdfBuilder: fakePdfBuilder,
      armImportPersistenceRepository: ArmImportPersistenceRepository(db),
      shareOverride: (files, {String? text}) async {},
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ExportTrialPdfReportUseCase', () {
    test('SUCCESS: assembles, builds, writes, and shares', () async {
      final trial = _trial(name: 'Canola 2026');

      final result = await useCase.execute(trial: trial);

      expect(result.warningMessage, isNull);
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

      final result = await useCase.execute(trial: trial);

      expect(result.warningMessage, isNull);
      expect(mockAssembly.lastAssembled, isNotNull);
      expect(mockAssembly.lastAssembled!.trial.name, 'Wheat Trial');
      expect(fakePdfBuilder.lastBuilt!.trial.name, 'Wheat Trial');
    });

    test('SUCCESS: filename uses safe name pattern', () async {
      final trial = _trial(name: 'Trial With Spaces & Special!');

      final result = await useCase.execute(trial: trial);

      expect(result.warningMessage, isNull);
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

    test('blocked confidence prevents PDF export', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'PdfBlock', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.blocked,
        exportBlockReason: 'schema mismatch',
      );
      final trial = _trial(id: trialId, name: 'PdfBlock');

      try {
        await useCase.execute(trial: trial);
        fail('expected ExportBlockedByConfidenceException');
      } on ExportBlockedByConfidenceException catch (e) {
        expect(e.toString(), contains(kBlockedExportMessage));
        expect(e.toString(), contains('Reason: schema mismatch'));
      }
      expect(mockAssembly.lastAssembled, isNull);
    });

    test('low confidence allows PDF export and returns warning', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'PdfLow', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.low,
      );
      final trial = _trial(id: trialId, name: 'PdfLow');

      final result = await useCase.execute(trial: trial);

      expect(result.warningMessage, kWarnExportMessage);
      expect(mockAssembly.lastAssembled, isNotNull);
    });

    test('high confidence allows PDF export without confidence warning', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'PdfHigh', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      final trial = _trial(id: trialId, name: 'PdfHigh');

      final result = await useCase.execute(trial: trial);

      expect(result.warningMessage, isNull);
      expect(mockAssembly.lastAssembled, isNotNull);
    });
  });
}
