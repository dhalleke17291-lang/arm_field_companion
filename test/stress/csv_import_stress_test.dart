import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/photos/photo_export_name_builder.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stress_import_helpers.dart';

String _buildLargeTrialCsv() {
  final headers = <String>[
    'Plot No.',
    'trt',
    'reps',
    'AVEFA 1-Jul-26 CONTRO %',
    'AVEFA 2-Jul-26 LODGIN #',
    'AVEFA 3-Jul-26 PESINC %',
    'AVEFA 4-Jul-26 PHYGEN %',
    'AVEFA 5-Jul-26 WYIELD KG/HA',
    'AVEFA 6-Jul-26 CONTRO %',
    'AVEFA 7-Jul-26 LODGIN #',
    'AVEFA 8-Jul-26 PESINC %',
    'AVEFA 9-Jul-26 PHYGEN %',
    'AVEFA 10-Jul-26 WYIELD KG/HA',
    'AVEFA 11-Jul-26 CONTRO %',
    'AVEFA 12-Jul-26 LODGIN #',
    'AVEFA 13-Jul-26 PESINC %',
    'AVEFA 14-Jul-26 PHYGEN %',
    'AVEFA 15-Jul-26 WYIELD KG/HA',
  ];
  final buf = StringBuffer()..writeln(headers.join(','));
  for (var i = 0; i < 200; i++) {
    final plot = 101 + i;
    final trt = (i % 8) + 1;
    final rep = (i % 4) + 1;
    final vals = List.generate(15, (c) => '${(i + c) % 100}');
    buf.writeln('$plot,$trt,$rep,${vals.join(',')}');
  }
  return buf.toString();
}

/// One header row plus [dataRows] (each full CSV row after the header).
String _stressCsv(String trailingHeaderCols, List<String> dataRows) {
  return 'Plot No.,trt,reps,$trailingHeaderCols\n${dataRows.join('\n')}';
}

List<String> _rows16(String Function(int i) trailingAfterRep) {
  return List.generate(16, (i) => '${101 + i},1,1${trailingAfterRep(i)}');
}

int _csvDataRowCount(String csv) {
  final lines =
      csv.split('\n').where((l) => l.trim().isNotEmpty).toList(growable: false);
  expect(lines, isNotEmpty);
  return lines.length - 1;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('stress CSV import / export', () {
    test('1 large trial: 200 plots, 15 assessments, plot export rows', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _buildLargeTrialCsv();
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'large_trial_$u.csv');
      expect(r.success, isTrue, reason: r.errorMessage);
      final tid = r.trialId!;

      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, 200);

      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid)))
          .get();
      expect(tas.length, 15);
      final aams = await ArmColumnMappingRepository(db)
          .getAssessmentMetadatasForTrial(tid);
      final aamByTa = {for (final a in aams) a.trialAssessmentId: a};
      expect(
        tas.map((e) => aamByTa[e.id]?.armImportColumnIndex).toSet().length,
        15,
      );

      final bundle = await exportStressTrialUseCase(db).execute(
        trial: (await (db.select(db.trials)..where((t) => t.id.equals(tid)))
            .getSingle()),
        format: ExportFormat.flatCsv,
      );
      expect(_csvDataRowCount(bundle.plotAssignmentsCsv), 200);
    });

    test('2 minimal trial: 2 plots, 1 assessment, export valid', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      const csv = 'Plot No.,trt,reps,Treatment Name,AVEFA 1-Jul-26 CONTRO %\n'
          '101,1,1,Check,3\n'
          '102,2,1,Product X,7\n';
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'minimal_trial_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;

      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, 2);

      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid)))
          .get();
      expect(tas.length, 1);

      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle = await exportStressTrialUseCase(db)
          .execute(trial: trial, format: ExportFormat.flatCsv);
      expect(_csvDataRowCount(bundle.plotAssignmentsCsv), 2);
      expect(bundle.observationsCsv, contains('101'));
      expect(bundle.observationsCsv, contains('102'));
    });

    test('3 count assessment CNTLIV: integers, scale whole numbers', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final vals = [0, 3, 7, 12, 5, 9, 2, 11, 4, 8, 1, 6, 10, 14, 3, 7];
      final csv = _stressCsv(
        'AVEFA 1-Jul-26 CNTLIV ea',
        _rows16((i) => ',${vals[i]}'),
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'count_assessment_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final sid = r.importSessionId!;

      final ratings = await (db.select(db.ratingRecords)
            ..where((rr) => rr.trialId.equals(tid) & rr.sessionId.equals(sid)))
          .get();
      expect(ratings.length, 16);
      for (final rr in ratings) {
        expect(rr.numericValue, isNotNull);
        expect(rr.numericValue == rr.numericValue!.roundToDouble(), isTrue);
      }
    });

    test('4 mixed types CONTRO %, CNTLIV ea, LODGIN #', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %,AVEFA 2-Jul-26 CNTLIV ea,AVEFA 3-Jul-26 LODGIN #',
        _rows16((i) => ',${i * 5 % 100},${i * 3},${i % 10}'),
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'mixed_types_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;

      final defs = await db.select(db.assessmentDefinitions).get();
      final byId = {for (final d in defs) d.id: d};

      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      expect(tas.length, 3);
      for (final ta in tas) {
        final def = byId[ta.assessmentDefinitionId];
        expect(def, isNotNull);
        expect(def!.dataType, 'numeric');
      }
    });

    test('5 duplicate CONTRO with different dates: 3 TrialAssessment, 3 export values',
        () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %,AVEFA 2-Jul-26 CONTRO %,AVEFA 3-Jul-26 CONTRO %',
        _rows16((i) => ',${i + 1},${i + 2},${i + 3}'),
      );
      final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(csv);
      final headers = table.first.map((c) => c.toString()).toList();
      final dataRows = table.skip(1).toList();
      final parsed = ArmCsvParser().parse(
        headers: headers,
        rows: dataRows,
        sourceFileName: 'dup.csv',
      );
      final keys = parsed.assessments.map((a) => a.columnInstanceKey).toSet();
      expect(keys.length, 3);

      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'duplicate_columns_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final aamRows2 = await ArmColumnMappingRepository(db)
          .getAssessmentMetadatasForTrial(tid);
      final aamByTa2 = {for (final a in aamRows2) a.trialAssessmentId: a};
      final tas = (await (db.select(db.trialAssessments)
                ..where((t) => t.trialId.equals(tid)))
              .get())
        ..sort((a, b) => (aamByTa2[a.id]?.armImportColumnIndex ?? 0)
            .compareTo(aamByTa2[b.id]?.armImportColumnIndex ?? 0));
      expect(tas.length, 3);

      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle = await exportStressTrialUseCase(db)
          .execute(trial: trial, format: ExportFormat.flatCsv);
      final outTable = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(bundle.observationsCsv);
      expect(outTable.length, 1 + 16 * 3);
    });

    test('6 special characters preserved; photo stem sanitizes', () async {
      const name =
          "Müller's Trial #3 — São Paulo (2026)";
      const csv = 'Plot No.,trt,reps,Treatment Name,AVEFA 1-Jul-26 CONTRO %\n'
          '101,1,1,Azoxystrobín 250SC,1\n'
          '102,2,1,Tébuconazole + Prothio.,2\n';
      final r = await stressArmImportUseCase(db).execute(
        csv,
        sourceFileName: '$name.csv',
      );
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      expect(trial.name, name);

      final trts = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(tid))
            ..orderBy([(t) => OrderingTerm.asc(t.code)]))
          .get();
      expect(trts.any((t) => t.name.contains('Azoxystrob')), isTrue);
      expect(trts.any((t) => t.name.contains('Tébuconazole')), isTrue);

      final bundle = await exportStressTrialUseCase(db)
          .execute(trial: trial, format: ExportFormat.flatCsv);
      expect(bundle.observationsCsv.contains('Müller'), isTrue);
      expect(bundle.observationsCsv.contains('São Paulo'), isTrue);

      final stem = sanitizeTrialNameForPhotoExport(trial.name);
      expect(stem.contains('Müller'), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(stem), isTrue);
    });

    test('7 trailing and middle blank rows; whitespace-only as missing', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final rows = <String>[];
      for (var i = 0; i < 8; i++) {
        rows.add('${101 + i},1,1,${5 + i}');
      }
      rows.add(',,,');
      for (var i = 0; i < 8; i++) {
        rows.add('${109 + i},1,1,   ');
      }
      rows.add('');
      rows.add('');
      final csv = _stressCsv('AVEFA 1-Jul-26 CONTRO %', rows);
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'trailing_blanks_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, 16);
      final sid = r.importSessionId!;
      final ratings = await (db.select(db.ratingRecords)
            ..where((rr) => rr.sessionId.equals(sid) & rr.isCurrent.equals(true)))
          .get();
      expect(ratings.length, 8);
    });

    test('8 Windows CRLF import matches newline normalization', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final unix = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %',
        _rows16((i) => ',1'),
      );
      final crlf = unix.replaceAll('\n', '\r\n');

      final ru = await stressArmImportUseCase(db)
          .execute(unix, sourceFileName: 'unix_$u.csv');
      final rc = await stressArmImportUseCase(db)
          .execute(crlf, sourceFileName: 'crlf_$u.csv');
      expect(ru.success, isTrue);
      expect(rc.success, isTrue);

      Future<int> plotCount(int trialId) async {
        final rows = await (db.select(db.plots)
              ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
            .get();
        return rows.length;
      }

      expect(await plotCount(ru.trialId!), 16);
      expect(await plotCount(rc.trialId!), 16);
    });

    test('9 UTF-8 BOM: import strips BOM so first header parses', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final body = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %',
        _rows16((i) => ',2'),
      );
      final withBom = '\uFEFF$body';
      expect(withBom.startsWith('\uFEFF'), isTrue);
      final r = await stressArmImportUseCase(db)
          .execute(withBom, sourceFileName: 'bom_utf8_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, 16);
    });

    test('11 three adjacent CONTRO columns: three instances, long export rows',
        () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _stressCsv(
        'AVEFA 1-Jul-26 CONTRO %,AVEFA 1-Jul-26 CONTRO %,AVEFA 1-Jul-26 CONTRO %',
        _rows16((i) => ',1,2,3'),
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'subsamples_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid)))
          .get();
      expect(tas.length, 3);
      final trial = await (db.select(db.trials)..where((t) => t.id.equals(tid)))
          .getSingle();
      final bundle = await exportStressTrialUseCase(db)
          .execute(trial: trial, format: ExportFormat.flatCsv);
      final table = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(bundle.observationsCsv);
      expect(table.length, 1 + 16 * 3);
    });

    test('12 dateless assessment header parses without crash', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _stressCsv(
        'AVEFA CONTRO %',
        _rows16((i) => ',4'),
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'dateless_header_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid)))
          .get();
      expect(tas.length, 1);
    });

    test('13 extra identity-like columns ignored', () async {
      final u = DateTime.now().microsecondsSinceEpoch;
      final csv = _stressCsv(
        'GPS_LAT,GPS_LON,SOIL_TYPE,NOTES,AVEFA 1-Jul-26 CONTRO %',
        _rows16((i) => ',45.1,-100.2,Loam,Note$i,6'),
      );
      final r = await stressArmImportUseCase(db)
          .execute(csv, sourceFileName: 'extra_columns_$u.csv');
      expect(r.success, isTrue);
      final tid = r.trialId!;
      final plots = await (db.select(db.plots)
            ..where((p) => p.trialId.equals(tid) & p.isDeleted.equals(false)))
          .get();
      expect(plots.length, 16);
      final tas = await (db.select(db.trialAssessments)
            ..where((t) => t.trialId.equals(tid)))
          .get();
      expect(tas.length, 1);
    });
  });
}
