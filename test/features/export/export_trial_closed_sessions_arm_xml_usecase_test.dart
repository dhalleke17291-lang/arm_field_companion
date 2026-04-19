import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart';
import 'package:arm_field_companion/features/export/domain/export_session_arm_xml_usecase.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockExportRepository implements ExportRepository {
  @override
  AppDatabase get db => throw UnimplementedError('not needed in tests');

  @override
  Future<List<Map<String, Object?>>> buildSessionExportRows(
      {required int sessionId}) async {
    return [];
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

class _MockSessionRepository implements SessionRepository {
  List<Session> sessions = [];
  bool shouldThrow = false;

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async {
    if (shouldThrow) throw Exception('Mock session error');
    return sessions;
  }

  @override
  Future<List<Session>> getAllActiveSessions() async => sessions;

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal,
          {int? createdByUserId}) async =>
      [];

  @override
  Stream<Session?> watchOpenSession(int trialId) => throw UnimplementedError();

  @override
  Future<Session?> getOpenSession(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<Session?> getSessionById(int id) async => throw UnimplementedError();

  @override
  Future<void> updateSessionCropStageBbch(int sessionId, int? cropStageBbch) async {}

  @override
  Future<void> updateSessionCropInjury(int sessionId, {required String status, String? notes, String? photoIds}) async {}

  @override
  Future<Session> createSession({
    required int trialId,
    required String name,
    required String sessionDateLocal,
    required List<int> assessmentIds,
    String? raterName,
    int? createdByUserId,
    int? cropStageBbch,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> closeSession(
    int sessionId, {
    String? raterName,
    int? closedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async =>
      throw UnimplementedError();

  @override
  Future<bool> isAssessmentInSession(int assessmentId, int sessionId) async =>
      false;

  @override
  Future<void> updateSessionAssessmentOrder(
    int sessionId,
    List<int> assessmentIdsInOrder,
  ) async {}

  @override
  Future<void> softDeleteSession(int sessionId,
      {String? deletedBy, int? deletedByUserId}) async {}

  @override
  Future<List<Session>> getDeletedSessionsForTrial(int trialId) async => [];

  @override
  Future<List<Session>> getAllDeletedSessions() async => [];

  @override
  Future<Session?> getDeletedSessionById(int id) async => null;

  @override
  Future<SessionRestoreResult> restoreSession(int sessionId,
          {String? restoredBy, int? restoredByUserId}) async =>
      SessionRestoreResult.failure('Not implemented');

  @override
  Stream<bool> watchTrialHasSessionData(int trialId) => Stream.value(false);

  @override
  Future<int?> resolveSessionIdForRatingShell(Trial trial) async => null;

  @override
  Future<int> deduplicateSessionAssessments(int sessionId) async => 0;

  @override
  Future<int> deduplicateSessionAssessmentsForTrial(int trialId) async => 0;

  @override
  Future<Map<int, DateTime>> getLatestSessionStartedAtByTrial() async => {};
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
  late ExportTrialClosedSessionsArmXmlUsecase batchUseCase;
  late ExportSessionArmXmlUsecase sessionArmXmlUsecase;
  late _MockExportRepository mockExportRepo;
  late _MockSessionRepository mockSessionRepo;
  late String tempPath;

  setUpAll(() async {
    final dir =
        await Directory.systemTemp.createTemp('batch_arm_xml_export_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });


  setUp(() {
    mockExportRepo = _MockExportRepository();
    sessionArmXmlUsecase = ExportSessionArmXmlUsecase(mockExportRepo);
    mockSessionRepo = _MockSessionRepository();
    batchUseCase = ExportTrialClosedSessionsArmXmlUsecase(
      sessionArmXmlUsecase,
      mockSessionRepo,
    );
  });

  group('ExportTrialClosedSessionsArmXmlUsecase', () {
    test('FAILURE: no closed sessions returns failure', () async {
      mockSessionRepo.sessions = [
        Session(
          id: 1,
          trialId: 10,
          name: 'Open Session',
          startedAt: DateTime(2026, 3, 1),
          endedAt: null,
          sessionDateLocal: '2026-03-01',
          raterName: 'Tech',
          createdByUserId: null,
          status: 'open',
          isDeleted: false,
        ),
      ];
      final result = await batchUseCase.execute(
        trialId: 10,
        trialName: 'Wheat 2026',
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('closed'));
    });

    test('FAILURE: empty sessions list returns failure', () async {
      mockSessionRepo.sessions = [];
      final result = await batchUseCase.execute(
        trialId: 10,
        trialName: 'Wheat 2026',
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('closed'));
    });

    test('SUCCESS: one closed session produces ZIP with one XML', () async {
      mockSessionRepo.sessions = [
        Session(
          id: 1,
          trialId: 10,
          name: 'Session 1',
          startedAt: DateTime(2026, 3, 1),
          endedAt: DateTime(2026, 3, 1, 12, 0),
          sessionDateLocal: '2026-03-01',
          raterName: 'Tech',
          createdByUserId: null,
          status: 'closed',
          isDeleted: false,
        ),
      ];
      final result = await batchUseCase.execute(
        trialId: 10,
        trialName: 'Wheat 2026',
      );
      expect(result.success, true);
      expect(result.filePath, isNotNull);
      expect(result.filePath, contains('AFC_trial'));
      expect(result.filePath, contains('arm_xml'));
      expect(result.filePath, endsWith('.zip'));
      expect(result.sessionCount, 1);

      final zipFile = File(result.filePath!);
      expect(await zipFile.exists(), true);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.length, 1);
      expect(archive.files.first.name, contains('AFC_arm_export'));
      expect(archive.files.first.name, endsWith('.xml'));
    });

    test('SUCCESS: two closed sessions produces ZIP with two XMLs', () async {
      mockSessionRepo.sessions = [
        Session(
          id: 1,
          trialId: 10,
          name: 'Session 1',
          startedAt: DateTime(2026, 3, 1),
          endedAt: DateTime(2026, 3, 1, 12, 0),
          sessionDateLocal: '2026-03-01',
          raterName: 'Tech',
          createdByUserId: null,
          status: 'closed',
          isDeleted: false,
        ),
        Session(
          id: 2,
          trialId: 10,
          name: 'Session 2',
          startedAt: DateTime(2026, 3, 2),
          endedAt: DateTime(2026, 3, 2, 12, 0),
          sessionDateLocal: '2026-03-02',
          raterName: 'Tech',
          createdByUserId: null,
          status: 'closed',
          isDeleted: false,
        ),
      ];
      final result = await batchUseCase.execute(
        trialId: 10,
        trialName: 'Wheat 2026',
      );
      expect(result.success, true);
      expect(result.sessionCount, 2);
      final bytes = await File(result.filePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.length, 2);
    });

    test('FAILURE: session repo throws returns failure', () async {
      mockSessionRepo.sessions = [
        Session(
          id: 1,
          trialId: 10,
          name: 'S1',
          startedAt: DateTime(2026, 3, 1),
          endedAt: DateTime(2026, 3, 1),
          sessionDateLocal: '2026-03-01',
          raterName: null,
          createdByUserId: null,
          status: 'closed',
          isDeleted: false,
        ),
      ];
      mockSessionRepo.shouldThrow = true;
      final result = await batchUseCase.execute(
        trialId: 10,
        trialName: 'Trial',
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Batch XML'));
    });
  });
}
