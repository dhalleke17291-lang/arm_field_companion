import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/arm/arm_treatment_metadata_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/domain/export_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/export/export_trial_usecase.dart'
    show PublishTrialExportDiagnostics;
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

Future<void> _insertCompatibilityProfile({
  required AppDatabase db,
  required int trialId,
  required ImportConfidence exportConfidence,
  String? exportBlockReason,
  List<String> columnOrderOnExport = const [],
  List<Map<String, dynamic>> assessmentTokens = const [],
}) async {
  final repo = ArmImportPersistenceRepository(db);
  final snapPayload = ImportSnapshotPayload(
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
    assessmentTokens: assessmentTokens,
    treatmentTokens: [],
    plotTokens: [],
    unknownPatterns: [],
    hasSubsamples: false,
    hasMultiApplication: false,
    hasSparseData: false,
    hasRepeatedCodes: false,
    rawFileChecksum: 'chk_${trialId}_${columnOrderOnExport.length}',
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
    exportConfidence: exportConfidence,
    exportBlockReason: exportBlockReason,
  );
  await repo.insertCompatibilityProfile(
    profilePayload,
    trialId: trialId,
    snapshotId: snapshotId,
  );
}

/// ARM strict export (Phase 2): plot arm numbers, TA column indexes, pinned session.
Future<void> _pinArmExportAnchors(
  AppDatabase db, {
  required int trialId,
  required int plotPk,
  required int armPlotNumber,
  required int trialAssessmentId,
  int armImportColumnIndex = 2,
  required int sessionId,
  DateTime? armImportedAt,
  String? pestCode,
}) async {
  await (db.update(db.plots)..where((p) => p.id.equals(plotPk))).write(
    PlotsCompanion(armPlotNumber: Value(armPlotNumber)),
  );
  await _upsertAamImportColumnIndex(
    db,
    trialAssessmentId,
    armImportColumnIndex,
    pestCode: pestCode,
  );
  await upsertArmTrialMetadataForTest(
    db,
    trialId: trialId,
    isArmLinked: true,
    armImportSessionId: sessionId,
    armImportedAt: armImportedAt,
  );
}

Future<void> _upsertAamImportColumnIndex(
  AppDatabase db,
  int trialAssessmentId,
  int armImportColumnIndex, {
  String? pestCode,
}) async {
  final existing = await (db.select(db.armAssessmentMetadata)
        ..where((m) => m.trialAssessmentId.equals(trialAssessmentId))
        ..limit(1))
      .getSingleOrNull();
  if (existing == null) {
    await db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: trialAssessmentId,
            armImportColumnIndex: Value(armImportColumnIndex),
            pestCode: Value(pestCode),
          ),
        );
  } else {
    await (db.update(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(trialAssessmentId)))
        .write(ArmAssessmentMetadataCompanion(
      armImportColumnIndex: Value(armImportColumnIndex),
      pestCode: pestCode == null ? const Value.absent() : Value(pestCode),
    ));
  }
}

Trial _trial({
  required int id,
  String name = 'Test Trial',
}) =>
    Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
    );

CellValue? _cell(Sheet sheet, int row, int col) {
  return sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
}

String _cellString(Sheet sheet, int row, int col) {
  final v = _cell(sheet, row, col);
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  return v.toString();
}

/// Minimal ARM-style Plot Data sheet for [ArmShellParser] / [ArmValueInjector].
Future<String> writeArmShellFixture(
  String tempDir, {
  required List<int> plotNumbers,
  required List<String> armColumnIds,
  required List<String> seNames,
  List<String>? seDescriptions,
  List<String>? ratingDates,
  List<String>? ratingTypes,
  List<String>? ratingUnits,
  List<String>? ratingTimings,
  /// Row 10 (0-based row 9) — ARM `003EPT` pest code (optional test hook).
  List<String>? pestCodesFromSheet,
  /// Row 24 (0-based) — `018EUS` Collect. Basis.
  String? plotDataCollectBasis,
  /// Row 23 (0-based) — `017EBU` size unit.
  String? plotDataSizeUnit,
  /// Row 39 (0-based) — `033EAB` Assessed By.
  String? plotDataAssessedBy,

  /// Optional **Applications** sheet: one inner list per application column
  /// (C, D, …), each of length **79** (`row01`…`row79`).
  List<List<String?>>? applicationSheetColumns,

  /// Optional **Comments** sheet: `ECM` in A2 and this text in B2 (ARM layout).
  String? commentsSheetBody,

  /// When true, fills **Subsample Plot Data** with the same layout as Plot Data
  /// (for parser tests).
  bool subsamplePlotDataMirror = false,

  /// Number of sub-units per plot written to both sheets when
  /// [subsamplePlotDataMirror] is true. Also sets row-46 descriptor.
  int numSubsamples = 1,
}) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Plot Data');
  final sheet = excel['Plot Data'];

  void populatePlotDataLikeSheet(Sheet target, {int rowsPerPlot = 1}) {
    void setText(int r, int c, String t) {
      target
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(t);
    }

    void setInt(int r, int c, int v) {
      target
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
      if (pestCodesFromSheet != null && i < pestCodesFromSheet.length) {
        setText(9, col, pestCodesFromSheet[i]);
      }
      setText(
        14,
        col,
        seDescriptions != null && i < seDescriptions.length
            ? seDescriptions[i]
            : '',
      );
      setText(
        15,
        col,
        ratingDates != null && i < ratingDates.length ? ratingDates[i] : '',
      );
      setText(17, col, seNames[i]);
      setText(
        20,
        col,
        ratingTypes != null && i < ratingTypes.length ? ratingTypes[i] : 'TYPE',
      );
      setText(
        21,
        col,
        ratingUnits != null && i < ratingUnits.length ? ratingUnits[i] : 'u',
      );
      setText(29, col, 'st');
      setText(
        41,
        col,
        ratingTimings != null && i < ratingTimings.length
            ? ratingTimings[i]
            : 'tim',
      );
      if (plotDataSizeUnit != null) {
        setText(23, col, plotDataSizeUnit);
      }
      if (plotDataCollectBasis != null) {
        setText(24, col, plotDataCollectBasis);
      }
      if (plotDataAssessedBy != null) {
        setText(39, col, plotDataAssessedBy);
      }
      setText(46, col, '$rowsPerPlot');
    }

    setText(47, 0, '041TRT');
    setText(47, 1, 'Plot (Sub)');

    for (var i = 0; i < plotNumbers.length; i++) {
      for (var s = 0; s < rowsPerPlot; s++) {
        final row = 48 + i * rowsPerPlot + s;
        setInt(row, 0, 1);
        setInt(row, 1, plotNumbers[i]);
      }
    }
  }

  populatePlotDataLikeSheet(sheet);
  if (subsamplePlotDataMirror) {
    populatePlotDataLikeSheet(
      excel['Subsample Plot Data'],
      rowsPerPlot: numSubsamples,
    );
  }

  if (applicationSheetColumns != null &&
      applicationSheetColumns.isNotEmpty) {
    final appSheet = excel['Applications'];
    void appSetText(int r, int c, String t) {
      appSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(t);
    }
    for (var i = 0; i < applicationSheetColumns.length; i++) {
      final col = 2 + i;
      final vals = applicationSheetColumns[i];
      if (vals.length != 79) {
        throw ArgumentError(
          'applicationSheetColumns[$i] must have length 79, got ${vals.length}',
        );
      }
      for (var r = 0; r < 79; r++) {
        final v = vals[r];
        if (v != null && v.isNotEmpty) {
          appSetText(r, col, v);
        }
      }
    }
  }

  if (commentsSheetBody != null) {
    final cSheet = excel['Comments'];
    void cSetText(int r, int c, String t) {
      cSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(t);
    }
    cSetText(0, 1, 'Enter all comments in cell below:');
    cSetText(1, 0, 'ECM');
    cSetText(1, 1, commentsSheetBody);
  }

  final path = '$tempDir/shell_${DateTime.now().microsecondsSinceEpoch}.xlsx';
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

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('rating_shell_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ExportArmRatingShellUseCase makeUc({
    Future<String?> Function()? pickShellPathOverride,
    PublishTrialExportDiagnostics? publishExportDiagnostics,
  }) =>
      ExportArmRatingShellUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        ratingRepository: RatingRepository(db),
        sessionRepository: SessionRepository(db),
        persistence: ArmImportPersistenceRepository(db),
        armColumnMappingRepository: ArmColumnMappingRepository(db),
        armApplicationsRepository: ArmApplicationsRepository(db),
        armTreatmentMetadataRepository: ArmTreatmentMetadataRepository(db),
        shareOverride: (_) async {},
        pickShellPathOverride: pickShellPathOverride,
        publishExportDiagnostics: publishExportDiagnostics,
      );

  group('ExportArmRatingShellUseCase', () {
    test('throws when trial is not ARM-linked', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'NoArm', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      final uc = makeUc();
      expect(
        () => uc.execute(trial: _trial(id: trialId)),
        throwsStateError,
      );
    });

    test('blocked confidence returns failure result', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Block', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.blocked,
        exportBlockReason: 'bad',
      );
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);
      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, false);
      expect(r.errorMessage, isNotNull);
    });

    test('empty plots returns failure result', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'NoPlots', workspaceType: 'efficacy');
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
      );
      await upsertArmTrialMetadataForTest(db,
          trialId: trialId, isArmLinked: true);
      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, false);
      expect(r.errorMessage, contains('No plots'));
    });

    test('pick cancelled returns failure', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Cancel', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '101',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'AVEFA',
              name: 'A',
              category: 'pest',
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Legacy A',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-01-01',
            ),
          );
      await _pinArmExportAnchors(
        db,
        trialId: trialId,
        plotPk: plotPk,
        armPlotNumber: 101,
        trialAssessmentId: taId,
        sessionId: sessionId,
        pestCode: 'AVEFA',
      );
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['AVEFA 1-Jul-26 CONTRO %'],
      );
      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final uc = makeUc(pickShellPathOverride: () async => null);
      final r = await uc.execute(trial: trialRow);
      expect(r.success, false);
      expect(r.errorMessage, contains('cancelled'));
    });

    test('numeric rating written to Plot Data sheet', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Num', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'Check',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '101',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'AVEFA',
              name: 'A',
              category: 'pest',
              timingCode: const Value('1-Jul-26'),
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Legacy A',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-01-01',
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legacyAsmId,
              sessionId: sessionId,
              trialAssessmentId: Value(taId),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(42.5),
              isCurrent: const Value(true),
            ),
          );

      await _pinArmExportAnchors(
        db,
        trialId: trialId,
        plotPk: plotPk,
        armPlotNumber: 101,
        trialAssessmentId: taId,
        sessionId: sessionId,
        pestCode: 'AVEFA',
      );

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
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

      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['001EID001'],
        seNames: const ['AVEFA'],
        ratingDates: const ['1-Jul-26'],
      );

      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final capturedCodes = <String>[];
      final uc = makeUc(
        pickShellPathOverride: () async => shellPath,
        publishExportDiagnostics: (_, findings, __) {
          capturedCodes.addAll(findings.map((f) => f.code));
        },
      );
      final r = await uc.execute(trial: trialRow);
      expect(r.success, true);
      expect(
        capturedCodes.contains('arm_round_trip_fallback_assessment_match_used'),
        false,
      );

      final ucNoPick = makeUc(
        publishExportDiagnostics: (_, findings, __) {
          capturedCodes.addAll(findings.map((f) => f.code));
        },
      );
      final r2 = await ucNoPick.execute(
        trial: trialRow,
        selectedShellPath: shellPath,
        suppressShare: true,
      );
      expect(r2.success, isTrue, reason: r2.errorMessage);

      final path = r.filePath;
      if (path == null) fail('expected file path');
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.sheets['Plot Data'];
      expect(sheet, isNotNull);
      expect(_cellString(sheet!, 48, 2), '42.5');
    });

    test(
      'seName matches pestCode before ratingType; avoids positional fallback',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'SeNameMatch', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('RECORDED'),
                numericValue: const Value(19.25),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );
        await _upsertAamImportColumnIndex(db, taId, 99);

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['  aVeFa  '],
          ratingDates: const ['1-Jul-26'],
          ratingTypes: const ['NOT_THE_PEST_CODE'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();
        final codes = <String>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            codes.addAll(findings.map((f) => f.code));
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        expect(
          codes.contains('arm_round_trip_fallback_assessment_match_used'),
          false,
        );
        expect(
          codes.contains('arm_rating_shell_strict_structural_block'),
          false,
        );
        final path = r.filePath;
        if (path == null) fail('expected file path');
        final sheet =
            Excel.decodeBytes(await File(path).readAsBytes()).sheets['Plot Data']!;
        expect(_cellString(sheet, 48, 2), '19.25');
      },
    );

    test(
      'duplicate seName resolved by timing to single shell column',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'SeNameTiming', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('RECORDED'),
                numericValue: const Value(33.33),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );
        await _upsertAamImportColumnIndex(db, taId, 99);

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
          columnOrderOnExport: const [
            'AVEFA 1-Jul-26 CONTRO %',
            'AVEFA 1-Aug-26 CONTRO %',
          ],
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001', '002EID002'],
          seNames: const ['AVEFA', 'AVEFA'],
          ratingDates: const ['', ''],
          ratingTypes: const ['ZZ1', 'ZZ2'],
          ratingTimings: const ['1-Jul-26', '1-Aug-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();
        final codes = <String>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            codes.addAll(findings.map((f) => f.code));
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        expect(
          codes.contains('arm_round_trip_fallback_assessment_match_used'),
          false,
        );
        final path = r.filePath;
        if (path == null) fail('expected file path');
        final sheet =
            Excel.decodeBytes(await File(path).readAsBytes()).sheets['Plot Data']!;
        expect(_cellString(sheet, 48, 2), '33.33');
        expect(_cellString(sheet, 48, 3), '');
      },
    );

    test(
      'shell row maps to data plot only; guard with same plotId is not matched',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'GuardSkip', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
          isGuardRow: true,
        );
        final dataPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '201',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 2,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: dataPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('RECORDED'),
                numericValue: const Value(77.5),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: dataPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['AVEFA'],
          ratingDates: const ['1-Jul-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();
        final findingCodes = <String>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            findingCodes.addAll(findings.map((f) => f.code));
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        expect(
          findingCodes.contains('arm_round_trip_duplicate_arm_plot_number'),
          false,
        );
        final path = r.filePath;
        if (path == null) fail('expected file path');
        final sheet = Excel.decodeBytes(await File(path).readAsBytes())
            .sheets['Plot Data']!;
        expect(_cellString(sheet, 48, 2), '77.5');
      },
    );

    test(
      'NOT_OBSERVED rating exports empty shell cell; non-recorded diagnostic non-blocking',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'NonRec', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('NOT_OBSERVED'),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['AVEFA'],
          ratingDates: const ['1-Jul-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();

        final captured = <DiagnosticFinding>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            captured
              ..clear()
              ..addAll(findings);
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        final outPath = r.filePath;
        expect(outPath, isNotNull);
        final outSheet = Excel.decodeBytes(await File(outPath!).readAsBytes())
            .sheets['Plot Data']!;
        expect(_cellString(outSheet, 48, 2), '');

        final nonRec = captured.where(
          (f) =>
              f.code ==
              'arm_round_trip_non_recorded_ratings_in_shell_session',
        );
        expect(nonRec, isNotEmpty);
        expect(nonRec.single.blocksExport, false);

        expect(
          captured.any((f) => f.code == 'arm_rating_shell_strict_structural_block'),
          false,
        );
      },
    );

    test(
      'TECHNICAL_ISSUE with text exports note into shell cell',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'TechTxt', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('TECHNICAL_ISSUE'),
                textValue: const Value('probe failed'),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['AVEFA'],
          ratingDates: const ['1-Jul-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        final sheet = Excel.decodeBytes(await File(r.filePath!).readAsBytes())
            .sheets['Plot Data']!;
        expect(_cellString(sheet, 48, 2), 'probe failed');
      },
    );

    test(
      'positional fallback with high import confidence blocks export after fallback diagnostic',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'PosFallback', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('RECORDED'),
                numericValue: const Value(7.0),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );
        await _upsertAamImportColumnIndex(db, taId, 99);

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.high,
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

        // seName must not equal pestCode (AVEFA) or seName match would avoid
        // positional fallback and Phase 3 would not run.
        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['OTHERSE'],
          ratingDates: const ['1-Jul-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();

        final captured = <DiagnosticFinding>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            captured
              ..clear()
              ..addAll(findings);
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, false);
        expect(
          captured.map((f) => f.code).contains(
                'arm_round_trip_fallback_assessment_match_used',
              ),
          true,
        );
        expect(
          captured.any(
            (f) =>
                f.code == 'arm_rating_shell_strict_structural_block' &&
                f.blocksExport,
          ),
          true,
        );
        final fb = captured.firstWhere(
          (f) => f.code == 'arm_round_trip_fallback_assessment_match_used',
        );
        expect(fb.blocksExport, false);
        expect(fb.detail, contains('$taId'));
      },
    );

    test(
      'positional fallback with medium import confidence is warning only; export succeeds',
      () async {
        final trialRepo = TrialRepository(db);
        final trialId =
            await trialRepo.createTrial(name: 'PosFallbackMed', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'Check',
        );
        final plotPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
        );
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: 'AVEFA',
                name: 'A',
                category: 'pest',
                timingCode: const Value('1-Jul-26'),
              ),
            );
        final legacyAsmId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'Legacy A',
              ),
            );
        final taId = await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyAsmId),
                sortOrder: const Value(0),
              ),
            );
        final sessionId = await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                trialId: trialId,
                name: 'S1',
                sessionDateLocal: '2026-01-01',
              ),
            );
        await db.into(db.ratingRecords).insert(
              RatingRecordsCompanion.insert(
                trialId: trialId,
                plotPk: plotPk,
                assessmentId: legacyAsmId,
                sessionId: sessionId,
                trialAssessmentId: Value(taId),
                resultStatus: const Value('RECORDED'),
                numericValue: const Value(7.0),
                isCurrent: const Value(true),
              ),
            );

        await _pinArmExportAnchors(
          db,
          trialId: trialId,
          plotPk: plotPk,
          armPlotNumber: 101,
          trialAssessmentId: taId,
          sessionId: sessionId,
          pestCode: 'AVEFA',
        );
        await _upsertAamImportColumnIndex(db, taId, 99);

        await _insertCompatibilityProfile(
          db: db,
          trialId: trialId,
          exportConfidence: ImportConfidence.medium,
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

        final shellPath = await writeArmShellFixture(
          tempPath,
          plotNumbers: const [101],
          armColumnIds: const ['001EID001'],
          seNames: const ['OTHERSE'],
          ratingDates: const ['1-Jul-26'],
        );

        final trialRow =
            await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
                .getSingle();

        final captured = <DiagnosticFinding>[];
        final uc = makeUc(
          pickShellPathOverride: () async => shellPath,
          publishExportDiagnostics: (_, findings, __) {
            captured
              ..clear()
              ..addAll(findings);
          },
        );
        final r = await uc.execute(trial: trialRow);
        expect(r.success, true);
        expect(
          captured.map((f) => f.code).contains(
                'arm_round_trip_fallback_assessment_match_used',
              ),
          true,
        );
        expect(
          captured.any(
            (f) =>
                f.code == 'arm_rating_shell_strict_structural_block' &&
                f.blocksExport,
          ),
          false,
        );
        expect(r.filePath, isNotNull);
      },
    );

    test('ARM-linked trial uses ARM Import Session for ratings not newest session',
        () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'ArmSess', workspaceType: 'efficacy');

      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'Check',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '101',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'AVEFA',
              name: 'A',
              category: 'pest',
              timingCode: const Value('1-Jul-26'),
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Legacy A',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      final armT = DateTime.utc(2026, 3, 1, 12);
      final laterT = DateTime.utc(2026, 3, 3, 12);
      final armSessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Import Session',
              sessionDateLocal: '2026-03-01',
              startedAt: Value(armT),
            ),
          );
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Newer session',
              sessionDateLocal: '2026-03-03',
              startedAt: Value(laterT),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legacyAsmId,
              sessionId: armSessionId,
              trialAssessmentId: Value(taId),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(77.0),
              isCurrent: const Value(true),
            ),
          );

      await _pinArmExportAnchors(
        db,
        trialId: trialId,
        plotPk: plotPk,
        armPlotNumber: 101,
        trialAssessmentId: taId,
        sessionId: armSessionId,
        armImportedAt: armT,
        pestCode: 'AVEFA',
      );
      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
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

      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['001EID001'],
        seNames: const ['AVEFA'],
        ratingDates: const ['1-Jul-26'],
      );

      final uc = makeUc(
        pickShellPathOverride: () async => shellPath,
      );
      final r = await uc.execute(trial: trialRow);
      expect(r.success, true);
      final pathArm = r.filePath;
      if (pathArm == null) fail('expected file path');
      final bytes = await File(pathArm).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.sheets['Plot Data'];
      expect(sheet, isNotNull);
      expect(double.parse(_cellString(sheet!, 48, 2)), 77.0);
    });

    test('strict structural block stops export before shell (duplicate armPlotNumber)',
        () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'DupPlot', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final p1 = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '101',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final p2 = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '102',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 2,
      );
      await (db.update(db.plots)..where((p) => p.id.isIn([p1, p2]))).write(
        const PlotsCompanion(armPlotNumber: Value(101)),
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'AVEFA',
              name: 'A',
              category: 'pest',
              timingCode: const Value('1-Jul-26'),
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Legacy A',
            ),
          );
      final dupTaId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      await _upsertAamImportColumnIndex(db, dupTaId, 2);
      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-01-01',
            ),
          );
      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: sessionId,
      );
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['AVEFA 1-Jul-26 CONTRO %'],
      );
      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['001EID001'],
        seNames: const ['AVEFA'],
        ratingDates: const ['1-Jul-26'],
      );
      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final r = await makeUc(pickShellPathOverride: () async => shellPath)
          .execute(trial: trialRow);
      expect(r.success, false);
      expect(r.errorMessage, contains('duplicate armPlotNumber'));
    });
  });

  test(
    'two same-name same-date assessments export to correct columns by armColumnIdInteger',
    () async {
      final trialRepo = TrialRepository(db);
      final trialId = await trialRepo.createTrial(
          name: 'DupName', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'Check',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '101',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'CONTRO_DUP',
              name: 'CONTRO dup',
              category: 'pest',
              timingCode: const Value('2-Apr-26'),
            ),
          );

      // Two legacy assessments for the two CONTRO columns
      final legacyId1 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
                trialId: trialId, name: 'CONTRO A1', unit: const Value('%')),
          );
      final legacyId2 = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
                trialId: trialId, name: 'CONTRO AA', unit: const Value('%')),
          );

      // Two TrialAssessments with distinct armColumnIdInteger values; per-column
      // ARM anchor fields live on arm_assessment_metadata after v60.
      final taId1 = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyId1),
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId1,
              armColumnIdInteger: const Value(3),
              armImportColumnIndex: const Value(2),
              pestCode: const Value('CONTRO'),
            ),
          );
      final taId2 = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyId2),
              sortOrder: const Value(1),
            ),
          );
      await db.into(db.armAssessmentMetadata).insert(
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId2,
              armColumnIdInteger: const Value(16),
              armImportColumnIndex: const Value(3),
              pestCode: const Value('CONTRO'),
            ),
          );

      final sessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-04-02',
            ),
          );

      // Rating for assessment 1 (ARM Column ID 3) → value 42.0
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legacyId1,
              sessionId: sessionId,
              trialAssessmentId: Value(taId1),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(42.0),
              isCurrent: const Value(true),
            ),
          );

      // Rating for assessment 2 (ARM Column ID 16) → value 77.0
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legacyId2,
              sessionId: sessionId,
              trialAssessmentId: Value(taId2),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(77.0),
              isCurrent: const Value(true),
            ),
          );

      await _pinArmExportAnchors(
        db,
        trialId: trialId,
        plotPk: plotPk,
        armPlotNumber: 101,
        trialAssessmentId: taId1,
        armImportColumnIndex: 2,
        sessionId: sessionId,
      );
      // Pin second assessment too (AAM already has index 3; call is a no-op
      // update path but keeps intent explicit).
      await _upsertAamImportColumnIndex(db, taId2, 3);

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const [
          'CONTRO 2-Apr-26 CONTRO %',
          'CONTRO 2-Apr-26 CONTRO %',
        ],
        assessmentTokens: [
          {
            'rawHeader': 'CONTRO 2-Apr-26 CONTRO %',
            'armCode': 'CONTRO',
            'timingCode': '2-Apr-26',
            'unit': '%',
            'ratingDate': null,
            'assessmentKey': 'k1',
          },
          {
            'rawHeader': 'CONTRO 2-Apr-26 CONTRO %',
            'armCode': 'CONTRO',
            'timingCode': '2-Apr-26',
            'unit': '%',
            'ratingDate': null,
            'assessmentKey': 'k2',
          },
        ],
      );

      // Shell has two columns: C (armColumnId "3") and D (armColumnId "16")
      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['3', '16'],
        seNames: const ['CONTRO', 'CONTRO'],
        ratingDates: const ['2-Apr-26', '2-Apr-26'],
        ratingTypes: const ['CONTRO', 'CONTRO'],
        ratingUnits: const ['%', '%'],
      );

      final trialRow =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();

      final uc = makeUc(pickShellPathOverride: () async => shellPath);
      final r = await uc.execute(trial: trialRow);
      expect(r.success, true, reason: r.errorMessage);

      final outPath = r.filePath;
      expect(outPath, isNotNull);
      final outSheet = Excel.decodeBytes(await File(outPath!).readAsBytes())
          .sheets['Plot Data']!;

      // Column C (index 2) = ARM Column ID 3 → should have value 42.0
      final cellC = _cellString(outSheet, 48, 2);
      // Column D (index 3) = ARM Column ID 16 → should have value 77.0
      final cellD = _cellString(outSheet, 48, 3);

      // Values may be stored as int (42) or double (42.0) depending on Excel encoding.
      expect(double.tryParse(cellC), 42.0,
          reason: 'ARM Column ID 3 (col C) should contain 42');
      expect(double.tryParse(cellD), 77.0,
          reason: 'ARM Column ID 16 (col D) should contain 77');
    },
  );
}
