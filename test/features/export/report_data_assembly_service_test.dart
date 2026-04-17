import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/features/export/report_data_assembly_service.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/features/export/data/export_repository.dart';

Trial _trial({
  int id = 1,
  String name = 'Test Trial',
  String? crop,
  String? location,
  String? season,
  String status = 'active',
  String workspaceType = 'efficacy',
}) =>
    Trial(
      id: id,
      name: name,
      crop: crop,
      location: location,
      season: season,
      status: status,
      workspaceType: workspaceType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      isArmLinked: false,
    );

class MockPlotRepository implements PlotRepository {
  List<Plot> plotsForTrial = [];

  @override
  Future<List<Plot>> getPlotsForTrial(int trialId) async =>
      List.from(plotsForTrial);

  @override
  Stream<List<Plot>> watchPlotsForTrial(int trialId) =>
      Stream.value(plotsForTrial);

  @override
  Future<Set<int>> getFlaggedPlotPksForSession(int sessionId) async => {};

  @override
  Future<Plot?> getPlotByPk(int plotPk) async => throw UnimplementedError();

  @override
  Future<Plot?> getPlotByPlotId(int trialId, String plotId) async =>
      throw UnimplementedError();

  @override
  Future<int> insertPlot({
    required int trialId,
    required String plotId,
    int? plotSortIndex,
    int? rep,
    int? treatmentId,
    String? row,
    String? column,
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
    bool isGuardRow = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotGuardRow(int plotPk, bool isGuardRow) async =>
      throw UnimplementedError();

  @override
  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async =>
      throw UnimplementedError();

  @override
  Future<int> countRepGuardPlotsToInsert(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<int> insertRepGuardPlotsIfNeeded(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<List<Plot>> getPlotsPage({
    required int trialId,
    required int offset,
    int limit = 50,
    int? repFilter,
    int? treatmentFilter,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<int>> getRepsForTrial(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotNotes(int plotPk, String? notes) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotDetails(
    int plotPk, {
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotTreatment(
    int plotPk,
    int? treatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updatePlotsTreatmentsBulk(
    Map<int, int?> plotPkToTreatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> softDeletePlot(int plotPk,
      {String? deletedBy, int? deletedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<List<Plot>> getDeletedPlotsForTrial(int trialId) =>
      throw UnimplementedError();

  @override
  Future<List<Plot>> getAllDeletedPlots() => throw UnimplementedError();

  @override
  Future<Plot?> getDeletedPlotByPk(int plotPk) =>
      throw UnimplementedError();

  @override
  Future<PlotRestoreResult> restorePlot(int plotPk,
          {String? restoredBy, int? restoredByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<void> setPlotExcludedFromAnalysis(
    int plotPk, {
    required String exclusionReason,
    required String damageType,
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> clearPlotExcludedFromAnalysis(
    int plotPk, {
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();
}

class MockTreatmentRepository implements TreatmentRepository {
  List<Treatment> treatmentsForTrial = [];
  Map<int, List<TreatmentComponent>> componentsByTreatmentId = {};

  @override
  Future<List<Treatment>> getTreatmentsForTrial(int trialId) async =>
      List.from(treatmentsForTrial);

  @override
  Stream<List<Treatment>> watchTreatmentsForTrial(int trialId) =>
      Stream.value(treatmentsForTrial);

  @override
  Future<Treatment?> getTreatmentById(int id) async =>
      treatmentsForTrial.where((t) => t.id == id).firstOrNull;

  @override
  Future<Treatment?> getTreatmentForTrial(int treatmentId, int trialId) async {
    final t = await getTreatmentById(treatmentId);
    if (t == null || t.trialId != trialId) return null;
    return t;
  }

  @override
  Future<List<Treatment>> getDeletedTreatmentsForTrial(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<Treatment?> getDeletedTreatmentById(int id) async =>
      throw UnimplementedError();

  @override
  Future<Treatment?> getTreatmentForPlot(int plotPk) async =>
      throw UnimplementedError();

  @override
  Future<int?> getEffectiveTreatmentIdForPlot(int plotPk) async =>
      throw UnimplementedError();

  @override
  Future<List<TreatmentComponent>> getComponentsForTreatment(int treatmentId) async =>
      List.from(componentsByTreatmentId[treatmentId] ?? []);

  @override
  Future<int> insertTreatment({
    required int trialId,
    required String code,
    required String name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateTreatment(int id,
      {String? code,
      String? name,
      String? description,
      String? treatmentType,
      String? timingCode,
      String? eppoCode,
      int? performedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<void> softDeleteTreatment(int id,
          {String? deletedBy, int? deletedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<TreatmentRestoreResult> restoreTreatment(int treatmentId,
          {String? restoredBy, int? restoredByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<int> insertComponent({
    required int treatmentId,
    required int trialId,
    required String productName,
    String? rate,
    String? rateUnit,
    String? applicationTiming,
    String? notes,
    int sortOrder = 0,
    double? activeIngredientPct,
    String? formulationType,
    String? manufacturer,
    String? registrationNumber,
    String? eppoCode,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> softDeleteComponent(int componentId,
          {String? deletedBy, int? deletedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTreatment(int id) async => throw UnimplementedError();

  @override
  Future<void> deleteComponent(int componentId) async =>
      throw UnimplementedError();

  @override
  Future<TreatmentComponent?> getDeletedComponentById(int componentId) async =>
      throw UnimplementedError();

  @override
  Future<TreatmentComponentRestoreResult> restoreComponent(int componentId,
          {String? restoredBy, int? restoredByUserId}) async =>
      throw UnimplementedError();
}

class MockApplicationRepository implements ApplicationRepository {
  List<TrialApplicationEvent> applicationsForTrial = [];

  @override
  Future<List<TrialApplicationEvent>> getApplicationsForTrial(int trialId) async =>
      List.from(applicationsForTrial);

  @override
  Stream<List<TrialApplicationEvent>> watchApplicationsForTrial(int trialId) =>
      Stream.value(applicationsForTrial);

  @override
  Future<String> createApplication(
    TrialApplicationEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateApplication(
    String id,
    TrialApplicationEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> markApplicationApplied({
    required String id,
    required DateTime appliedAt,
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteApplication(String id) async =>
      throw UnimplementedError();

  @override
  Stream<List<ApplicationEvent>> watchEventsForTrial(int trialId) =>
      throw UnimplementedError();

  @override
  Future<List<ApplicationEvent>> getEventsForTrial(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<int> insertEvent({
    required int trialId,
    int? sessionId,
    required int applicationNumber,
    String? timingLabel,
    required String method,
    required DateTime applicationDate,
    String? growthStage,
    String? operatorName,
    String? equipment,
    String? weather,
    String? notes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<ApplicationPlotRecord>> getPlotRecordsForEvent(int eventId) async =>
      throw UnimplementedError();

  @override
  Future<int> insertPlotRecord({
    required int eventId,
    required int plotPk,
    required int trialId,
    String status = 'applied',
    String? notes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> getNextApplicationNumber(int trialId) async =>
      throw UnimplementedError();

  @override
  Future<void> markCompleted({
    required int eventId,
    required int trialId,
    required String completedBy,
    required bool coversEntireTrial,
    List<int>? specificPlotPks,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateEvent(ApplicationEvent event) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteEvent(int eventId) async =>
      throw UnimplementedError();
}

class MockSeedingRepository implements SeedingRepository {
  SeedingEvent? seedingForTrial;

  @override
  Future<SeedingEvent?> getSeedingEventForTrial(int trialId) async =>
      seedingForTrial;

  @override
  Future<void> markSeedingCompleted({
    required String id,
    required DateTime completedAt,
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> upsertSeedingEvent(
    SeedingEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();
}

class MockSessionRepository implements SessionRepository {
  List<Session> sessionsForTrial = [];

  @override
  Future<List<Session>> getSessionsForTrial(int trialId) async =>
      List.from(sessionsForTrial);

  @override
  Future<List<Session>> getAllActiveSessions() async =>
      List.from(sessionsForTrial);

  @override
  Future<List<Session>> getSessionsForDate(String dateLocal,
          {int? createdByUserId}) async =>
      [];

  @override
  Future<Session?> getOpenSession(int trialId) async => null;

  @override
  Stream<Session?> watchOpenSession(int trialId) => Stream.value(null);

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
  Future<void> closeSession(int sessionId,
      {String? raterName, int? closedByUserId}) async {}

  @override
  Future<List<Assessment>> getSessionAssessments(int sessionId) async => [];

  @override
  Future<bool> isAssessmentInSession(int assessmentId, int sessionId) async =>
      false;

  @override
  Future<Session?> getSessionById(int sessionId) async => null;

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
}

class MockAssignmentRepository implements AssignmentRepository {
  List<Assignment> assignmentsForTrial = [];

  @override
  Future<Assignment?> getForPlot(int plotPk) async => null;

  @override
  Future<Assignment?> getForTrialAndPlot(int trialId, int plotPk) async =>
      null;

  @override
  Future<List<Assignment>> getForTrial(int trialId) async =>
      List.from(assignmentsForTrial);

  @override
  Stream<List<Assignment>> watchForTrial(int trialId) =>
      Stream.value(assignmentsForTrial);

  @override
  Future<void> upsert({
    required int trialId,
    required int plotId,
    int? treatmentId,
    int? replication,
    int? block,
    int? range,
    int? column,
    int? position,
    bool? isCheck,
    bool? isControl,
    String? assignmentSource,
    DateTime? assignedAt,
    int? assignedBy,
    String? notes,
  }) async {}

  @override
  Future<void> upsertBulk({
    required int trialId,
    required Map<int, int?> plotPkToTreatmentId,
    String? assignmentSource,
    DateTime? assignedAt,
  }) async {}
}

class MockPhotoRepository implements PhotoRepository {
  List<Photo> photosForTrial = [];

  @override
  Future<List<Photo>> getPhotosForTrial(int trialId) async =>
      List.from(photosForTrial);

  @override
  Stream<List<Photo>> watchPhotosForTrial(int trialId) =>
      Stream.value(photosForTrial);

  @override
  Future<Photo> savePhoto({
    required int trialId,
    required int plotPk,
    required int sessionId,
    required String tempPath,
    required String finalPath,
    String? caption,
    String? raterName,
    int? performedByUserId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> getPhotoCountForSession(int sessionId) async =>
      throw UnimplementedError();

  @override
  Future<List<Photo>> getPhotosForPlot({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<Photo>> getPhotosForPlotInSession({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> softDeletePhoto(int id,
          {String? deletedBy, int? deletedByUserId}) async =>
      throw UnimplementedError();

  @override
  Future<List<Photo>> getDeletedPhotosForSession(int sessionId) async =>
      throw UnimplementedError();

  @override
  Future<void> cleanupOrphanTempFiles() async =>
      throw UnimplementedError();

  @override
  Stream<List<Photo>> watchPhotosForPlot({
    required int trialId,
    required int plotPk,
    required int sessionId,
  }) =>
      throw UnimplementedError();
}

class _MockExportRepository implements ExportRepository {
  @override
  AppDatabase get db => throw UnimplementedError('not needed in tests');

  @override
  Future<List<Map<String, Object?>>> buildSessionExportRows(
          {required int sessionId}) async =>
      throw UnimplementedError('not needed in tests');

  @override
  Future<List<Map<String, Object?>>> buildTrialExportRows(
          {required int trialId}) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> buildSessionAuditExportRows(
          {required int sessionId}) async =>
      throw UnimplementedError('not needed in tests');
}

void main() {
  late ReportDataAssemblyService service;
  late MockPlotRepository mockPlotRepo;
  late MockTreatmentRepository mockTreatmentRepo;
  late MockApplicationRepository mockApplicationRepo;
  late MockSessionRepository mockSessionRepo;
  late MockAssignmentRepository mockAssignmentRepo;
  late MockPhotoRepository mockPhotoRepo;
  late MockSeedingRepository mockSeedingRepo;

  setUp(() {
    mockPlotRepo = MockPlotRepository();
    mockTreatmentRepo = MockTreatmentRepository();
    mockApplicationRepo = MockApplicationRepository();
    mockSessionRepo = MockSessionRepository();
    mockAssignmentRepo = MockAssignmentRepository();
    mockPhotoRepo = MockPhotoRepository();
    mockSeedingRepo = MockSeedingRepository();
    service = ReportDataAssemblyService(
      plotRepository: mockPlotRepo,
      treatmentRepository: mockTreatmentRepo,
      applicationRepository: mockApplicationRepo,
      sessionRepository: mockSessionRepo,
      assignmentRepository: mockAssignmentRepo,
      photoRepository: mockPhotoRepo,
      exportRepository: _MockExportRepository(),
      seedingRepository: mockSeedingRepo,
    );
  });

  group('ReportDataAssemblyService', () {
    test('SUCCESS: assembly with empty trial returns empty sections', () async {
      final trial = _trial(name: 'Empty Trial', crop: 'Wheat');
      final result = await service.assembleForTrial(trial);

      expect(result.trial.id, 1);
      expect(result.trial.name, 'Empty Trial');
      expect(result.trial.crop, 'Wheat');
      expect(result.trial.status, 'active');
      expect(result.trial.workspaceType, 'efficacy');
      expect(result.treatments, isEmpty);
      expect(result.plots, isEmpty);
      expect(result.sessions, isEmpty);
      expect(result.applications.count, 0);
      expect(result.applications.events, isEmpty);
      expect(result.photoCount.count, 0);
      expect(result.seeding, isNull);
    });

    test('SUCCESS: assembly with trial, plots, treatments, sessions, applications, photos', () async {
      final trial = _trial(
        id: 42,
        name: 'Canola 2026',
        crop: 'Canola',
        location: 'Field A',
        season: '2026',
      );
      mockPlotRepo.plotsForTrial = [
        const Plot(
          id: 101,
          trialId: 42,
          plotId: '101',
          plotSortIndex: 1,
          rep: 1,
          treatmentId: 10,
          isGuardRow: false,
          isDeleted: false,
          excludeFromAnalysis: false,
        ),
      ];
      mockTreatmentRepo.treatmentsForTrial = [
        const Treatment(
          id: 10,
          trialId: 42,
          code: 'T1',
          name: 'Control',
          treatmentType: 'control',
          isDeleted: false,
        ),
      ];
      mockTreatmentRepo.componentsByTreatmentId[10] = [
        const TreatmentComponent(
          id: 1,
          treatmentId: 10,
          trialId: 42,
          productName: 'Product A',
          sortOrder: 0,
          isDeleted: false,
        ),
      ];
      mockSessionRepo.sessionsForTrial = [
        Session(
          id: 1,
          trialId: 42,
          name: 'Session 1',
          startedAt: DateTime.now(),
          sessionDateLocal: '2026-03-10',
          status: 'closed',
          isDeleted: false,
        ),
      ];
      mockApplicationRepo.applicationsForTrial = [
        TrialApplicationEvent(
          id: 'evt-1',
          trialId: 42,
          applicationDate: DateTime(2026, 3, 5),
          productName: 'Herbicide X',
          status: 'applied',
          appliedAt: DateTime(2026, 3, 5),
          createdAt: DateTime(2026, 3, 5),
        ),
      ];
      mockPhotoRepo.photosForTrial = [
        Photo(
          id: 1,
          trialId: 42,
          plotPk: 101,
          sessionId: 1,
          filePath: '/path/photo.jpg',
          status: 'final',
          createdAt: DateTime.now(),
          isDeleted: false,
        ),
      ];

      final result = await service.assembleForTrial(trial);

      expect(result.trial.id, 42);
      expect(result.trial.name, 'Canola 2026');
      expect(result.trial.crop, 'Canola');
      expect(result.trial.location, 'Field A');
      expect(result.trial.season, '2026');

      expect(result.treatments.length, 1);
      expect(result.treatments[0].id, 10);
      expect(result.treatments[0].code, 'T1');
      expect(result.treatments[0].name, 'Control');
      expect(result.treatments[0].treatmentType, 'control');
      expect(result.treatments[0].componentCount, 1);

      expect(result.plots.length, 1);
      expect(result.plots[0].plotPk, 101);
      expect(result.plots[0].plotId, '101');
      expect(result.plots[0].rep, 1);
      expect(result.plots[0].treatmentId, 10);
      expect(result.plots[0].treatmentCode, 'T1');

      expect(result.sessions.length, 1);
      expect(result.sessions[0].id, 1);
      expect(result.sessions[0].name, 'Session 1');
      expect(result.sessions[0].sessionDateLocal, '2026-03-10');
      expect(result.sessions[0].status, 'closed');

      expect(result.applications.count, 1);
      expect(result.applications.events[0].id, 'evt-1');
      expect(result.applications.events[0].applicationDate, DateTime(2026, 3, 5));
      expect(result.applications.events[0].productName, 'Herbicide X');
      expect(result.applications.events[0].status, 'applied');
      expect(result.applications.events[0].appliedAt, DateTime(2026, 3, 5));

      expect(result.photoCount.count, 1);
      expect(result.seeding, isNull);
    });

    test('SUCCESS: treatment component count from getComponentsForTreatment', () async {
      final trial = _trial();
      mockTreatmentRepo.treatmentsForTrial = [
        const Treatment(
            id: 1,
            trialId: 1,
            code: 'T1',
            name: 'Treatment 1',
            isDeleted: false),
        const Treatment(
            id: 2,
            trialId: 1,
            code: 'T2',
            name: 'Treatment 2',
            isDeleted: false),
      ];
      mockTreatmentRepo.componentsByTreatmentId[1] = [
        const TreatmentComponent(
            id: 1,
            treatmentId: 1,
            trialId: 1,
            productName: 'A',
            sortOrder: 0,
            isDeleted: false),
        const TreatmentComponent(
            id: 2,
            treatmentId: 1,
            trialId: 1,
            productName: 'B',
            sortOrder: 1,
            isDeleted: false),
      ];
      mockTreatmentRepo.componentsByTreatmentId[2] = [];

      final result = await service.assembleForTrial(trial);

      expect(result.treatments[0].componentCount, 2);
      expect(result.treatments[1].componentCount, 0);
    });

    test('SUCCESS: plot-treatment linkage via assignments', () async {
      final trial = _trial();
      mockPlotRepo.plotsForTrial = [
        const Plot(
          id: 201,
          trialId: 1,
          plotId: '201',
          plotSortIndex: 1,
          rep: null,
          treatmentId: null,
          isGuardRow: false,
          isDeleted: false,
          excludeFromAnalysis: false,
        ),
      ];
      mockTreatmentRepo.treatmentsForTrial = [
        const Treatment(
            id: 5,
            trialId: 1,
            code: 'T5',
            name: 'Assigned Treatment',
            isDeleted: false),
      ];
      mockAssignmentRepo.assignmentsForTrial = [
        Assignment(
          id: 1,
          trialId: 1,
          plotId: 201,
          treatmentId: 5,
          replication: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = await service.assembleForTrial(trial);

      expect(result.plots.length, 1);
      expect(result.plots[0].treatmentId, 5);
      expect(result.plots[0].treatmentCode, 'T5');
      expect(result.plots[0].rep, 2);
    });
  });
}
