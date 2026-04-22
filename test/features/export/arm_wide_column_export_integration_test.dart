import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/diagnostics/trial_export_diagnostics.dart';
import 'package:arm_field_companion/core/excel_column_letters.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/domain/export_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/data/services/arm_shell_parser.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

/// 26 assessment columns at sheet column indices 2..27 → … Z, AA, AB at 25–27.
const int kWideAssessmentCount = 26;

Future<void> _insertHighConfidenceProfile({
  required AppDatabase db,
  required int trialId,
  required List<Map<String, dynamic>> assessmentTokens,
}) async {
  final repo = ArmImportPersistenceRepository(db);
  final snapPayload = ImportSnapshotPayload(
    sourceFile: 'wide.csv',
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
    rawFileChecksum: 'wide_$trialId',
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
    columnOrderOnExport: [
      for (var i = 0; i < kWideAssessmentCount; i++) 'WC$i',
    ],
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

Future<String> _writeWideShell(
  String tempDir, {
  required List<String> armColumnIds,
  required List<String> seNames,
}) async {
  expect(armColumnIds.length, kWideAssessmentCount);
  expect(seNames.length, kWideAssessmentCount);

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

  for (var i = 0; i < kWideAssessmentCount; i++) {
    final col = 2 + i;
    setText(7, col, armColumnIds[i]);
    setText(15, col, '');
    setText(17, col, seNames[i]);
    setText(20, col, 'TYPE');
    setText(21, col, 'u');
    setText(29, col, 'st');
    setText(41, col, 'tim');
    setText(46, col, '1');
  }

  setText(47, 0, '041TRT');
  setText(47, 1, 'Plot (Sub)');
  setInt(48, 0, 1);
  setInt(48, 1, 101);

  final path = '$tempDir/shell_wide_${DateTime.now().microsecondsSinceEpoch}.xlsx';
  final b = excel.encode();
  if (b == null) throw StateError('encode');
  await File(path).writeAsBytes(b);
  return path;
}

String _cellString(Sheet sheet, int row, int col) {
  final v = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  return v.toString();
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

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('arm_wide_col');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'wide-column ARM shell export: columns through Z, AA, AB inject correctly',
    () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'WideCol', workspaceType: 'efficacy');

      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final plotPk = await db.into(db.plots).insert(
            PlotsCompanion.insert(
              trialId: trialId,
              plotId: '101',
              rep: const Value(1),
              treatmentId: Value(trtId),
              plotSortIndex: const Value(1),
              armPlotNumber: const Value(101),
            ),
          );

      final armColumnIds = <String>[];
      final seNames = <String>[];
      final legacyIds = <int>[];

      for (var i = 0; i < kWideAssessmentCount; i++) {
        final colIdx = 2 + i;
        armColumnIds.add('WIDE_${columnIndexToLettersZeroBased(colIdx)}_$colIdx');
        seNames.add('WC$i');

        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'WC$i',
                name: 'Wide $i',
                category: 'pest',
              ),
            );
        final legacyId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'L$i',
              ),
            );
        await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyId),
                sortOrder: Value(i),
                pestCode: Value('WC$i'),
                armImportColumnIndex: Value(colIdx),
              ),
            );
        legacyIds.add(legacyId);
      }

      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Wide session',
              sessionDateLocal: '2026-04-01',
            ),
          );

      for (var i = 0; i < kWideAssessmentCount; i++) {
        await db.into(db.sessionAssessments).insert(
              SessionAssessmentsCompanion.insert(
                sessionId: sessionId,
                assessmentId: legacyIds[i],
                sortOrder: Value(i),
              ),
            );
      }

      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: sessionId,
      );

      Future<void> insertRating(int legacyIdx, double value) async {
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyIds[legacyIdx],
                sessionId: sessionId,
                resultStatus: const Value(ResultStatusDb.recorded),
                numericValue: Value(value),
                isCurrent: const Value(true),
              ),
            );
      }

      await insertRating(23, 11);
      await insertRating(24, 22);
      await insertRating(25, 33);

      await _insertHighConfidenceProfile(
        db: db,
        trialId: trialId,
        assessmentTokens: [
          for (var i = 0; i < kWideAssessmentCount; i++)
            {
              'rawHeader': 'WC$i',
              'armCode': 'WC$i',
              'timingCode': '',
              'unit': '',
              'ratingDate': null,
              'assessmentKey': 'k$i',
            },
        ],
      );

      final shellPath = await _writeWideShell(
        tempPath,
        armColumnIds: armColumnIds,
        seNames: seNames,
      );

      final shellImport = await ArmShellParser(shellPath).parse();
      expect(shellImport.assessmentColumns.length, kWideAssessmentCount);

      final zCol = shellImport.assessmentColumns
          .where((c) => c.columnIndex == 25)
          .single;
      final aaCol = shellImport.assessmentColumns
          .where((c) => c.columnIndex == 26)
          .single;
      final abCol = shellImport.assessmentColumns
          .where((c) => c.columnIndex == 27)
          .single;

      expect(zCol.columnLetter, columnIndexToLettersZeroBased(25));
      expect(aaCol.columnLetter, columnIndexToLettersZeroBased(26));
      expect(abCol.columnLetter, columnIndexToLettersZeroBased(27));
      expect(zCol.columnLetter, 'Z');
      expect(aaCol.columnLetter, 'AA');
      expect(abCol.columnLetter, 'AB');

      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();

      final captured = <String>[];
      final exportUc = ExportArmRatingShellUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        ratingRepository: RatingRepository(db),
        sessionRepository: SessionRepository(db),
        persistence: ArmImportPersistenceRepository(db),
        armColumnMappingRepository: ArmColumnMappingRepository(db),
        shareOverride: (_) async {},
        pickShellPathOverride: () async => shellPath,
        publishExportDiagnostics: (tid, findings, label) {
          expect(tid, trialId);
          expect(label, kArmRatingShellExportAttemptLabel);
          captured
            ..clear()
            ..addAll(findings.map((f) => f.code));
        },
      );

      final result = await exportUc.execute(trial: trialRow);
      expect(result.success, true, reason: result.errorMessage);
      expect(
        captured.contains('arm_rating_shell_strict_structural_block'),
        false,
      );

      final outPath = result.filePath;
      expect(outPath, isNotNull);
      final bytes = await File(outPath!).readAsBytes();
      final book = Excel.decodeBytes(bytes);
      final plotSheet = book.sheets['Plot Data'];
      expect(plotSheet, isNotNull);

      expect(double.parse(_cellString(plotSheet!, 48, 25)), 11);
      expect(double.parse(_cellString(plotSheet, 48, 26)), 22);
      expect(double.parse(_cellString(plotSheet, 48, 27)), 33);
    },
  );
}
