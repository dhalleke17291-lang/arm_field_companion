import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
import 'package:arm_field_companion/core/diagnostics/trial_export_diagnostics.dart';
import 'package:arm_field_companion/data/repositories/assessment_definition_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_assessment_definition_resolver.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_report_builder.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_snapshot_service.dart';
import 'package:arm_field_companion/features/arm_import/data/compatibility_profile_builder.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/arm_import/usecases/arm_import_usecase.dart';
import 'package:arm_field_companion/features/export/domain/compute_arm_round_trip_diagnostics_usecase.dart';
import 'package:arm_field_companion/features/export/domain/export_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/usecases/compute_session_completeness_usecase.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

ArmImportUseCase _makeArmImport(AppDatabase db) {
  return ArmImportUseCase(
    db,
    TrialRepository(db),
    TreatmentRepository(db),
    PlotRepository(db),
    AssignmentRepository(db),
    ArmAssessmentDefinitionResolver(AssessmentDefinitionRepository(db)),
    TrialAssessmentRepository(db),
    SessionRepository(db),
    SaveRatingUseCase(
      RatingRepository(db),
      RatingIntegrityGuard(
        PlotRepository(db),
        SessionRepository(db),
        TreatmentRepository(db, AssignmentRepository(db)),
      ),
    ),
    ArmCsvParser(),
    ArmImportSnapshotService(),
    CompatibilityProfileBuilder(),
    ArmImportPersistenceRepository(db),
    ArmImportReportBuilder(),
  );
}

Future<void> _insertHighConfidenceProfile({
  required AppDatabase db,
  required int trialId,
  required List<String> columnOrderOnExport,
  List<Map<String, dynamic>> assessmentTokens = const [],
}) async {
  final repo = ArmImportPersistenceRepository(db);
  final snapPayload = ImportSnapshotPayload(
    sourceFile: 'chain.csv',
    sourceRoute: 'arm_csv_v1',
    armVersion: null,
    rawHeaders: [],
    columnOrder: [],
    rowTypePatterns: [],
    plotCount: 0,
    treatmentCount: 0,
    assessmentCount: 0,
    identityColumns: [],
    assessmentTokens: assessmentTokens,
    treatmentTokens: [],
    plotTokens: [],
    unknownPatterns: [],
    hasSubsamples: false,
    hasMultiApplication: false,
    hasSparseData: false,
    hasRepeatedCodes: false,
    rawFileChecksum: 'chain_${trialId}_${columnOrderOnExport.length}',
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
    columnOrderOnExport: columnOrderOnExport,
    identityFieldOrder: const [],
    knownUnsupported: const [],
    exportConfidence: ImportConfidence.high,
    exportBlockReason: null,
  );
  await repo.insertCompatibilityProfile(
    profilePayload,
    trialId: trialId,
    snapshotId: snapshotId,
  );
}

String _cellString(Sheet sheet, int row, int col) {
  final v = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  return v.toString();
}

/// Same layout as [export_arm_rating_shell_usecase_test.dart] — Plot Data shell.
Future<String> _writeShell(
  String tempDir, {
  required List<int> plotNumbers,
  required List<String> armColumnIds,
  required List<String> seNames,
}) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Plot Data');
  final sheet = excel['Plot Data'];

  void setText(int r, int c, String t) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
        .value = TextCellValue(t);
  }

  void setInt(int r, int c, int v) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
        .value = IntCellValue(v);
  }

  setText(1, 2, 'T');
  setText(2, 2, 'id');
  setText(3, 2, 'c');
  setText(4, 2, 'cr');
  setText(5, 2, 'f');

  for (var i = 0; i < armColumnIds.length; i++) {
    final col = 2 + i;
    setText(7, col, armColumnIds[i]);
    setText(15, col, '1-Jul-26');
    setText(17, col, seNames[i]);
    setText(20, col, 'TYPE');
    setText(21, col, 'u');
    setText(29, col, 'st');
    setText(41, col, 'tim');
    setText(46, col, '1');
  }

  setText(47, 0, '041TRT');
  setText(47, 1, 'Plot (Sub)');

  for (var i = 0; i < plotNumbers.length; i++) {
    final row = 48 + i;
    setInt(row, 0, 1);
    setInt(row, 1, plotNumbers[i]);
  }

  final path = '$tempDir/shell_chain_${DateTime.now().microsecondsSinceEpoch}.xlsx';
  final b = excel.encode();
  if (b == null) throw StateError('encode');
  await File(path).writeAsBytes(b);
  return path;
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

void main() {
  late AppDatabase db;
  late String tempPath;
  final capturedFindings = <DiagnosticFinding>[];

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('arm_full_chain');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    capturedFindings.clear();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'full ARM chain: import → SaveRating → completeness → shell export (happy path)',
    () async {
      const csv =
          'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n101,1,1,5\n';
      final unique = DateTime.now().microsecondsSinceEpoch;
      final fileName = 'chain_$unique.csv';

      final importResult =
          await _makeArmImport(db).execute(csv, sourceFileName: fileName);
      expect(importResult.success, true, reason: importResult.errorMessage);
      final trialId = importResult.trialId!;

      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      expect(trialRow.isArmLinked, true);
      expect(trialRow.armImportSessionId, isNotNull);

      final plotRows = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(trialId)))
          .get();
      expect(plotRows, hasLength(1));
      expect(plotRows.single.armPlotNumber, 101);

      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(trialId)))
          .get();
      expect(tas, hasLength(1));
      expect(
        tas.single.armImportColumnIndex,
        2,
        reason: 'Import stores shell-aligned index (CSV col 3 → sheet col 2)',
      );
      expect(tas.single.legacyAssessmentId, isNotNull);

      final sessionId = trialRow.armImportSessionId!;
      final plotPk = plotRows.single.id;
      final legacyAsmId = tas.single.legacyAssessmentId!;

      final ratingRepo = RatingRepository(db);
      final before = await ratingRepo.getCurrentRating(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: legacyAsmId,
        sessionId: sessionId,
      );
      expect(before, isNotNull);
      expect(before!.numericValue, 5.0);

      final saveUc = SaveRatingUseCase(
        ratingRepo,
        RatingIntegrityGuard(
          PlotRepository(db),
          SessionRepository(db),
          TreatmentRepository(db, AssignmentRepository(db)),
        ),
      );
      final saveResult = await saveUc.execute(
        SaveRatingInput(
          trialId: trialId,
          plotPk: plotPk,
          assessmentId: legacyAsmId,
          sessionId: sessionId,
          resultStatus: ResultStatusDb.recorded,
          numericValue: 88.5,
          isSessionClosed: false,
        ),
      );
      expect(saveResult.isSuccess, true, reason: saveResult.errorMessage);

      final after = await ratingRepo.getCurrentRating(
        trialId: trialId,
        plotPk: plotPk,
        assessmentId: legacyAsmId,
        sessionId: sessionId,
      );
      expect(after!.numericValue, 88.5);

      final chainRows = await (db.select(db.ratingRecords)
            ..where((r) =>
                r.plotPk.equals(plotPk) &
                r.assessmentId.equals(legacyAsmId) &
                r.sessionId.equals(sessionId)))
          .get();
      expect(chainRows.where((r) => r.isCurrent).length, 1);
      expect(chainRows.length, greaterThanOrEqualTo(2));

      final completeness = await ComputeSessionCompletenessUseCase(
        SessionRepository(db),
        PlotRepository(db),
        ratingRepo,
      ).execute(sessionId: sessionId);

      expect(completeness.expectedPlots, 1);
      expect(completeness.completedPlots, 1);
      expect(completeness.incompletePlots, 0);
      expect(completeness.canClose, true);

      await _insertHighConfidenceProfile(
        db: db,
        trialId: trialId,
        columnOrderOnExport: const ['AVEFA 1-Jul-26 CONTRO %'],
        assessmentTokens: [
          {
            'rawHeader': 'AVEFA 1-Jul-26 CONTRO %',
            'armCode': 'AVEFA',
            'timingCode': '1-Jul-26',
            'unit': '%',
            'ratingDate': null,
            'assessmentKey': 'k',
          },
        ],
      );

      final shellPath = await _writeShell(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['001EID001'],
        seNames: const ['AVEFA'],
      );

      final exportUc = ExportArmRatingShellUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        ratingRepository: ratingRepo,
        sessionRepository: SessionRepository(db),
        persistence: ArmImportPersistenceRepository(db),
        armColumnMappingRepository: ArmColumnMappingRepository(db),
        shareOverride: (_) async {},
        pickShellPathOverride: () async => shellPath,
        publishExportDiagnostics: (tid, findings, label) {
          expect(tid, trialId);
          expect(label, kArmRatingShellExportAttemptLabel);
          capturedFindings
            ..clear()
            ..addAll(findings);
        },
      );

      final exportResult = await exportUc.execute(trial: trialRow);
      expect(exportResult.success, true, reason: exportResult.errorMessage);

      expect(
        capturedFindings.any(
          (f) =>
              f.code == 'arm_rating_shell_strict_structural_block' &&
              f.blocksExport,
        ),
        false,
      );
      expect(
        capturedFindings.any((f) => f.blocksExport),
        false,
      );
      expect(
        capturedFindings.any(
          (f) => f.code == 'arm_round_trip_fallback_assessment_match_used',
        ),
        false,
      );

      final rtReport = await ComputeArmRoundTripDiagnosticsUseCase(
        plotRepository: PlotRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        sessionRepository: SessionRepository(db),
        ratingRepository: ratingRepo,
      ).execute(trial: trialRow);

      expect(rtReport.resolvedShellSessionId, trialRow.armImportSessionId);

      final outPath = exportResult.filePath;
      expect(outPath, isNotNull);
      final bytes = await File(outPath!).readAsBytes();
      final decoded = Excel.decodeBytes(bytes);
      final plotSheet = decoded.sheets['Plot Data'];
      expect(plotSheet, isNotNull);
      expect(_cellString(plotSheet!, 48, 2), '88.5');

      final freshTrial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      expect(freshTrial.armImportSessionId, sessionId);
    },
  );
}
