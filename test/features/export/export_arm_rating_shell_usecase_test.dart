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
  bool isArmLinked = false,
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

double _cellNum(Sheet sheet, int row, int col) {
  final v = _cell(sheet, row, col);
  if (v is DoubleCellValue) return v.value;
  if (v is IntCellValue) return v.value.toDouble();
  fail('expected numeric cell at row $row col $col, got $v');
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

  ExportArmRatingShellUseCase makeUc() => ExportArmRatingShellUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        treatmentRepository: TreatmentRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        ratingRepository: RatingRepository(db),
        sessionRepository: SessionRepository(db),
        persistence: ArmImportPersistenceRepository(db),
        shareOverride: (_) async {},
      );

  group('ExportArmRatingShellUseCase', () {
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

    test('numeric rating written to correct cell', () async {
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

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final path = r.filePath;
      if (path == null) fail('expected file path');
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      final v = _cell(sheet, 2, 4);
      expect(v, isA<DoubleCellValue>());
      expect((v as DoubleCellValue).value, 42.5);
    });

    test('blank rating written as empty string not zero', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Blank', workspaceType: 'efficacy');
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
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-01-01',
            ),
          );

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['AVEFA 1-Jul-26 CONTRO %'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final pathBlank = r.filePath;
      if (pathBlank == null) fail('expected file path');
      final bytes = await File(pathBlank).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      expect(_cellString(sheet, 2, 4), '');
      final v = _cell(sheet, 2, 4);
      expect(v, isNot(isA<IntCellValue>()));
      expect(v is DoubleCellValue, false);
    });

    test('plot order is ascending by plotNumber', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Order', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '2',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 2,
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
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
        columnOrderOnExport: const ['AVEFA'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final pathOrder = r.filePath;
      if (pathOrder == null) fail('expected file path');
      final bytes = await File(pathOrder).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      expect(_cellString(sheet, 2, 0), '1');
      expect(_cellString(sheet, 3, 0), '2');
    });

    test('assessment column order matches columnOrderOnExport', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Col', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      for (final code in ['ZZZ', 'AAA']) {
        final defId = await db.into(db.assessmentDefinitions).insert(
              AssessmentDefinitionsCompanion.insert(
                code: code,
                name: code,
                category: 'pest',
              ),
            );
        final legacyId = await db.into(db.assessments).insert(
              AssessmentsCompanion.insert(
                trialId: trialId,
                name: 'L$code',
              ),
            );
        await db.into(db.trialAssessments).insert(
              TrialAssessmentsCompanion.insert(
                trialId: trialId,
                assessmentDefinitionId: defId,
                legacyAssessmentId: Value(legacyId),
                sortOrder: Value(code == 'ZZZ' ? 0 : 1),
                pestCode: Value(code),
              ),
            );
      }
      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['ZZZ hdr', 'AAA hdr'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final pathCol = r.filePath;
      if (pathCol == null) fail('expected file path');
      final bytes = await File(pathCol).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      expect(_cellString(sheet, 1, 4), 'ZZZ hdr');
      expect(_cellString(sheet, 1, 5), 'AAA hdr');
    });

    test('treatment name written in col 3', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'TN', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'Product Alpha',
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
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
        columnOrderOnExport: const ['AVEFA'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final pathTn = r.filePath;
      if (pathTn == null) fail('expected file path');
      final bytes = await File(pathTn).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      expect(_cellString(sheet, 2, 3), 'Product Alpha');
    });

    test('longer pestCode wins when shorter code is substring', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'Sub', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defAb = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'DEFAB',
              name: 'AB',
              category: 'pest',
            ),
          );
      final defAbc = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'DEFABC',
              name: 'ABC',
              category: 'pest',
            ),
          );
      final legAb = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'LAB',
            ),
          );
      final legAbc = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'LABC',
            ),
          );
      final taAb = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defAb,
              legacyAssessmentId: Value(legAb),
              sortOrder: const Value(0),
              pestCode: const Value('AB'),
            ),
          );
      final taAbc = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defAbc,
              legacyAssessmentId: Value(legAbc),
              sortOrder: const Value(1),
              pestCode: const Value('ABC'),
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
              assessmentId: legAbc,
              sessionId: sessionId,
              trialAssessmentId: Value(taAbc),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(7.0),
              isCurrent: const Value(true),
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legAb,
              sessionId: sessionId,
              trialAssessmentId: Value(taAb),
              resultStatus: const Value('RECORDED'),
              numericValue: const Value(3.0),
              isCurrent: const Value(true),
            ),
          );

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['ABC column', 'AB column'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      final pathSub = r.filePath;
      if (pathSub == null) fail('expected file path');
      final bytes = await File(pathSub).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      expect(_cellNum(sheet, 2, 4), 7.0);
      expect(_cellNum(sheet, 2, 5), 3.0);
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

      final uc = makeUc();
      final r = await uc.execute(trial: trialRow);
      expect(r.success, true);
      final pathArm = r.filePath;
      if (pathArm == null) fail('expected file path');
      final bytes = await File(pathArm).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Plot Data'];
      final v = _cell(sheet, 2, 4);
      if (v is DoubleCellValue) {
        expect(v.value, 77.0);
      } else if (v is IntCellValue) {
        expect(v.value, 77);
      } else {
        fail('expected numeric cell, got $v');
      }
    });

    test('null pestCode falls back to definition code with warning', () async {
      final trialRepo = TrialRepository(db);
      final trialId =
          await trialRepo.createTrial(name: 'NullPest', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'XCODE',
              name: 'X',
              category: 'pest',
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'Legacy X',
            ),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S1',
              sessionDateLocal: '2026-01-01',
            ),
          );

      await _insertCompatibilityProfile(
        db: db,
        trialId: trialId,
        exportConfidence: ImportConfidence.high,
        columnOrderOnExport: const ['XCODE hdr'],
      );

      final uc = makeUc();
      final r = await uc.execute(trial: _trial(id: trialId));
      expect(r.success, true);
      expect(r.warningMessage, contains('unknownPattern'));
      expect(r.warningMessage, contains('pestCode'));
    });
  });
}
