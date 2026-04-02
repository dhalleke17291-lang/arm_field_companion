import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/domain/export_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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

Trial _trial({
  required int id,
  String name = 'Test Trial',
  bool isArmLinked = true,
  DateTime? armImportedAt,
}) =>
    Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      isArmLinked: isArmLinked,
      armImportedAt: armImportedAt,
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
  List<String>? ratingDates,
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
    setText(
      15,
      col,
      ratingDates != null && i < ratingDates.length ? ratingDates[i] : '',
    );
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
  }) =>
      ExportArmRatingShellUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        ratingRepository: RatingRepository(db),
        sessionRepository: SessionRepository(db),
        persistence: ArmImportPersistenceRepository(db),
        shareOverride: (_) async {},
        pickShellPathOverride: pickShellPathOverride,
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
        () => uc.execute(trial: _trial(id: trialId, isArmLinked: false)),
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
      await PlotRepository(db).insertPlot(
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
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
              pestCode: const Value('AVEFA'),
            ),
          );
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['AVEFA 1-Jul-26 CONTRO %'],
      );
      final uc = makeUc(pickShellPathOverride: () async => null);
      final r = await uc.execute(trial: _trial(id: trialId));
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
              pestCode: const Value('AVEFA'),
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
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final path = r.filePath;
      if (path == null) fail('expected file path');
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.sheets['Plot Data'];
      expect(sheet, isNotNull);
      expect(_cellString(sheet!, 48, 2), '42.5');
    });

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
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
              pestCode: const Value('AVEFA'),
            ),
          );
      final armT = DateTime.utc(2026, 3, 1, 12);
      final laterT = DateTime.utc(2026, 3, 3, 12);
      final armSessionId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'ARM Import Session',
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
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(77.0),
              isCurrent: const Value(true),
            ),
          );

      await (db.update(db.trials)..where((t) => t.id.equals(trialId))).write(
        TrialsCompanion(
          isArmLinked: const Value(true),
          armImportedAt: Value(DateTime.utc(2026, 3, 1, 12)),
        ),
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
  });
}
