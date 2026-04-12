import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/export_confidence_policy.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/export/export_trial_usecase.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/diagnostics/trial_readiness.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _seedPlotForExportTrial(AppDatabase db, int trialId) async {
  await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
}

ExportTrialUseCase _makeUseCase(AppDatabase db) {
  return ExportTrialUseCase(
    trialRepository: TrialRepository(db),
    plotRepository: PlotRepository(db),
    treatmentRepository: TreatmentRepository(db),
    applicationRepository: ApplicationRepository(db),
    applicationProductRepository: ApplicationProductRepository(db),
    seedingRepository: SeedingRepository(db),
    sessionRepository: SessionRepository(db),
    ratingRepository: RatingRepository(db),
    assignmentRepository: AssignmentRepository(db),
    photoRepository: PhotoRepository(db),
    weatherSnapshotRepository: WeatherSnapshotRepository(db),
    notesRepository: NotesRepository(db),
    armImportPersistenceRepository: ArmImportPersistenceRepository(db),
  );
}

Trial _trialFromId(int id) => Trial(
      id: id,
      name: 'T',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      isArmLinked: false,
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ExportTrialUseCase confidence gate', () {
    test('blocked confidence prevents flat CSV export', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Block', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.blocked,
        exportBlockReason: 'bad layout',
      );
      final uc = _makeUseCase(db);
      final trial = _trialFromId(trialId);

      try {
        await uc.execute(trial: trial, format: ExportFormat.flatCsv);
        fail('expected ExportBlockedByConfidenceException');
      } on ExportBlockedByConfidenceException catch (e) {
        expect(e.toString(), contains(kBlockedExportMessage));
        expect(e.toString(), contains('bad layout'));
      }
    });

    test('low confidence allows export and exposes warning on bundle', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Low', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.low,
      );
      final uc = _makeUseCase(db);
      final trial = _trialFromId(trialId);
      await _seedPlotForExportTrial(db, trialId);

      final bundle =
          await uc.execute(trial: trial, format: ExportFormat.flatCsv);
      expect(bundle.warningMessage, kWarnExportMessage);
    });

    test('high confidence allows export without confidence warning', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'High', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      final uc = _makeUseCase(db);
      final trial = _trialFromId(trialId);
      await _seedPlotForExportTrial(db, trialId);

      final bundle =
          await uc.execute(trial: trial, format: ExportFormat.flatCsv);
      expect(bundle.warningMessage, isNull);
    });

    test('readiness blockers prevent export when precheck passed', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'R', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      await _seedPlotForExportTrial(db, trialId);
      final uc = _makeUseCase(db);
      final trial = _trialFromId(trialId);
      const badReport = TrialReadinessReport(checks: [
        TrialReadinessCheck(
          code: 'no_plots',
          label: 'No plots defined',
          severity: TrialCheckSeverity.blocker,
        ),
      ]);
      expect(
        () => uc.execute(
          trial: trial,
          format: ExportFormat.flatCsv,
          trialReadinessPrecheck: badReport,
        ),
        throwsA(isA<ExportBlockedByReadinessException>()),
      );
    });

    test('flat CSV bundle includes notes.csv for field notes', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'NotesTrial', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      await _seedPlotForExportTrial(db, trialId);
      final plotPk = await PlotRepository(db)
          .insertPlot(trialId: trialId, plotId: '202');
      final notesRepo = NotesRepository(db);
      await notesRepo.createNote(
        trialId: trialId,
        plotPk: plotPk,
        sessionId: null,
        content: 'Deer tracks near rep 3',
        createdBy: 'Tester',
      );
      final uc = _makeUseCase(db);
      final trial = Trial(
        id: trialId,
        name: 'NotesTrial',
        status: 'active',
        workspaceType: 'efficacy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: false,
        isArmLinked: false,
      );
      final bundle =
          await uc.execute(trial: trial, format: ExportFormat.flatCsv);
      expect(bundle.notesCsv, contains('note_id'));
      expect(bundle.notesCsv, contains('Deer tracks near rep 3'));
      expect(bundle.notesCsv, contains('NotesTrial'));
      expect(bundle.notesCsv, contains('202'));
      expect(bundle.dataDictionaryCsv, contains('notes.csv'));
    });

    test('flat CSV bundle prepends UTF-8 BOM on each table for Excel', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'BomCsv', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      await _seedPlotForExportTrial(db, trialId);
      final uc = _makeUseCase(db);
      final trial = _trialFromId(trialId);

      final bundle =
          await uc.execute(trial: trial, format: ExportFormat.flatCsv);
      for (final csv in [
        bundle.observationsCsv,
        bundle.observationsArmTransferCsv,
        bundle.treatmentsCsv,
        bundle.plotAssignmentsCsv,
        bundle.applicationsCsv,
        bundle.seedingCsv,
        bundle.sessionsCsv,
        bundle.notesCsv,
        bundle.dataDictionaryCsv,
      ]) {
        expect(
          csv.startsWith('\uFEFF'),
          isTrue,
          reason: 'each flat CSV should start with UTF-8 BOM',
        );
      }
    });
  });
}
