import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/export/domain/export_session_csv_usecase.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockExportRepository implements ExportRepository {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> auditRows = [];
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
    return auditRows;
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
  late ExportSessionCsvUsecase useCase;
  late MockExportRepository mockRepo;
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('export_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    mockRepo = MockExportRepository();
    useCase = ExportSessionCsvUsecase(mockRepo);
  });

  group('ExportSessionCsvUsecase', () {
    test(
        'FAILURE: rejects export when session is open and requireSessionClosed is true',
        () async {
      final result = await useCase.exportSessionToCsv(
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

    test(
        'SUCCESS: allows export when session is open and requireSessionClosed is false',
        () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
      ];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: false,
        requireSessionClosed: false,
      );
      expect(result.success, true);
      expect(result.rowCount, 1);
    });

    test('SUCCESS: exports with zero rows and sets warning message', () async {
      mockRepo.rows = [];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.rowCount, 0);
      expect(result.warningMessage, isNotNull);
      expect(result.warningMessage, contains('No ratings'));
    });

    test('SUCCESS: exports multiple rows and sets correct rowCount', () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
        {'plot_id': '002', 'value': '3.0'},
        {'plot_id': '003', 'value': '7.0'},
      ];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.rowCount, 3);
      expect(result.warningMessage, isNull);
    });

    test('SUCCESS: filePath is non-null on successful export', () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
      ];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.filePath, isNotNull);
      expect(result.filePath, contains('AFC_export'));
    });

    test('FAILURE: DB error returns failure result', () async {
      mockRepo.shouldThrow = true;
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Export failed'));
    });

    test('SUCCESS: enriches rows with trial and session metadata', () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
      ];
      final result = await useCase.exportSessionToCsv(
        sessionId: 42,
        trialId: 7,
        trialName: 'Canola 2026',
        sessionName: 'Session 3',
        sessionDateLocal: '2026-03-10',
        exportedByDisplayName: 'P. Singh',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.filePath, contains('Canola_2026'));
    });

    test('SUCCESS: auditFilePath set when audit rows exist', () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
      ];
      mockRepo.auditRows = [
        {'event_type': 'RATING_SAVED', 'description': 'test'},
      ];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.auditFilePath, isNotNull);
    });

    test('SUCCESS: auditFilePath is null when no audit rows', () async {
      mockRepo.rows = [
        {'plot_id': '001', 'value': '5.0'},
      ];
      mockRepo.auditRows = [];
      final result = await useCase.exportSessionToCsv(
        sessionId: 1,
        trialId: 1,
        trialName: 'Test Trial',
        sessionName: 'Session 1',
        sessionDateLocal: '2026-03-10',
        isSessionClosed: true,
      );
      expect(result.success, true);
      expect(result.auditFilePath, isNull);
    });
  });
}
