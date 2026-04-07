import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_snapshot_service.dart';

void main() {
  final parser = ArmCsvParser();
  final snapshotService = ArmImportSnapshotService();

  test('builds snapshot from clean parsed CSV', () {
    const sourcePath = '/tmp/arm_export_trial_001.csv';
    const rawCsv = 'Plot No.,trt,reps,AVEFA 1-Jul-26 CONTRO %\n'
        '101,1,1,5\n'
        '102,2,1,78\n';

    final headers = [
      'Plot No.',
      'trt',
      'reps',
      'AVEFA 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 1, 5],
      [102, 2, 1, 78],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: sourcePath,
    );

    final snap = snapshotService.buildSnapshot(
      parsed: parsed,
      sourceFile: sourcePath,
      rawCsv: rawCsv,
    );

    expect(snap.sourceFile, sourcePath);
    expect(snap.sourceRoute, 'arm_csv_v1_unvalidated');
    expect(snap.plotCount, 2);
    expect(snap.treatmentCount, 2);
    expect(snap.assessmentCount, 1);
    expect(snap.identityColumns, ['Plot No.', 'trt', 'reps']);
    expect(snap.assessmentTokens.length, 1);
    expect(snap.treatmentTokens.length, 0);
    expect(snap.plotTokens.length, 2);
    expect(snap.unknownPatterns, isEmpty);
    expect(snap.rawFileChecksum, isNotEmpty);
  });

  test('treatment metadata headers appear in treatmentTokens', () {
    final headers = [
      'Plot No.',
      'trt',
      'reps',
      'Treatment Name',
      'Form Conc',
      'AVEFA 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 1, 'Check', '500', 5],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 't.csv',
    );

    final snap = snapshotService.buildSnapshot(
      parsed: parsed,
      sourceFile: 't.csv',
      rawCsv: 'x',
    );

    final headersInTokens =
        snap.treatmentTokens.map((m) => m['header'] as String).toList();
    expect(headersInTokens, contains('Treatment Name'));
    expect(headersInTokens, contains('Form Conc'));
  });

  test('duplicate plot rows still produce unique plotCount', () {
    final headers = [
      'Plot No.',
      'trt',
      'reps',
      'AVEFA 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 1, 5],
      [101, 1, 1, 7],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 'd.csv',
    );

    final snap = snapshotService.buildSnapshot(
      parsed: parsed,
      sourceFile: 'd.csv',
      rawCsv: 'y',
    );

    expect(snap.plotCount, 1);
  });

  test('same logical key on two columns — snapshot lists both column indices', () {
    final headers = [
      'Plot No.',
      'trt',
      'reps',
      'AVEFA 1-Jul-26 CONTRO %',
      'XYZZZ 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 1, 5, 9],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 'rep.csv',
    );

    expect(parsed.hasRepeatedCodes, isTrue);

    final snap = snapshotService.buildSnapshot(
      parsed: parsed,
      sourceFile: 'rep.csv',
      rawCsv: 'z',
    );

    expect(snap.hasRepeatedCodes, isTrue);
    expect(
      snap.unknownPatterns.any((m) => m['type'] == 'repeated-assessment-key'),
      isFalse,
    );
    expect(
      snap.unknownPatterns.any((m) => m['type'] == 'repeated-semantic-assessment-key'),
      isTrue,
    );
    final tokens = snap.assessmentTokens;
    expect(tokens.length, 2);
    expect(tokens[0]['columnIndex'], 3);
    expect(tokens[1]['columnIndex'], 4);
    expect(
      tokens[0]['columnInstanceKey'],
      isNot(equals(tokens[1]['columnInstanceKey'])),
    );
  });

  test('checksum uses raw CSV bytes exactly (no normalization)', () {
    final parser = ArmCsvParser();

    final headers = ['Plot No.', 'trt', 'reps'];
    final rows = [
      [101, 1, 1],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 'test.csv',
    );

    final service = ArmImportSnapshotService();

    const rawCsv1 = 'Plot No.,trt,reps\n101,1,1\n';
    const rawCsv2 = 'Plot No.,trt,reps\r\n101,1,1\r\n';

    final snapshot1 = service.buildSnapshot(
      parsed: parsed,
      sourceFile: 'test.csv',
      rawCsv: rawCsv1,
    );

    final snapshot2 = service.buildSnapshot(
      parsed: parsed,
      sourceFile: 'test.csv',
      rawCsv: rawCsv2,
    );

    expect(snapshot1.rawFileChecksum, isNotEmpty);
    expect(snapshot2.rawFileChecksum, isNotEmpty);

    // MUST be different because raw bytes differ
    expect(snapshot1.rawFileChecksum != snapshot2.rawFileChecksum, true);
  });
}
