import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/export/domain/export_session_arm_xml_usecase.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockExportRepository implements ExportRepository {
  List<Map<String, Object?>> rows = [];
  bool shouldThrow = false;

  @override
  AppDatabase get db => throw UnimplementedError('not needed in tests');

  @override
  Future<List<Map<String, Object?>>> buildSessionExportRows(
      {required int sessionId}) async {
    if (shouldThrow) throw Exception('Mock DB error');
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> buildSessionAuditExportRows(
      {required int sessionId}) async {
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> buildTrialExportRows({
    required int trialId,
  }) async => [];
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
  late ExportSessionArmXmlUsecase useCase;
  late _MockExportRepository mockRepo;
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('arm_xml_export_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    mockRepo = _MockExportRepository();
    useCase = ExportSessionArmXmlUsecase(mockRepo);
  });

  group('ExportSessionArmXmlUsecase', () {
    test(
        'FAILURE: rejects export when session is open and requireSessionClosed is true',
        () async {
      final result = await useCase.exportSessionToArmXml(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: false,
        requireSessionClosed: true,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('closed'));
    });

    test('SUCCESS: allows export when session is closed', () async {
      mockRepo.rows = [];
      final result = await useCase.exportSessionToArmXml(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.filePath, isNotNull);
      expect(result.filePath, contains('AFC_arm_export'));
      expect(result.filePath, endsWith('.xml'));
    });

    test('SUCCESS: written XML contains arm_export root and trial/session',
        () async {
      mockRepo.rows = [];
      final result = await useCase.exportSessionToArmXml(
        sessionId: 42,
        trialId: 7,
        trialName: 'Wheat 2026',
        sessionName: 'Quick',
        sessionDateLocal: '2026-03-11',
        isSessionClosed: true,
      );
      expect(result.success, true);
      final content = await File(result.filePath!).readAsString();
      expect(content, contains('<arm_export'));
      expect(content, contains('Wheat 2026'));
      expect(content, contains('Quick'));
      expect(content, contains('<trial'));
      expect(content, contains('<session'));
    });

    test('SUCCESS: exports ratings when rows provided', () async {
      mockRepo.rows = [
        {
          'plot_pk': 101,
          'plot_id': 'P1',
          'rep': 1,
          'treatment_id': 10,
          'treatment_code': 'T1',
          'treatment_name': 'Control',
          'assessment_id': 1,
          'assessment_name': 'Yield',
          'unit': 'kg',
          'effective_result_status': 'completed',
          'effective_numeric_value': 5.5,
          'effective_text_value': null,
          'result_status': 'completed',
          'numeric_value': 5.5,
          'text_value': null,
          'created_at': '2026-03-11T10:00:00',
          'rater_name': 'Tech',
        },
      ];
      final result = await useCase.exportSessionToArmXml(
        sessionId: 1,
        trialId: 1,
        trialName: 'T',
        sessionName: 'S',
        sessionDateLocal: '2026-03-11',
        isSessionClosed: true,
      );
      expect(result.success, true);
      final content = await File(result.filePath!).readAsString();
      expect(content, contains('<rating'));
      expect(content, contains('completed'));
      expect(content, contains('5.5'));
      expect(content, contains('<treatment'));
      expect(content, contains('T1'));
      expect(content, contains('<assessment'));
      expect(content, contains('Yield'));
    });

    test('FAILURE: DB error returns failure result', () async {
      mockRepo.shouldThrow = true;
      final result = await useCase.exportSessionToArmXml(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('ARM XML export failed'));
    });
  });
}
