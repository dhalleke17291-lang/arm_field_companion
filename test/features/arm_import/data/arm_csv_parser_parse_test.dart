import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';

void main() {
  final parser = ArmCsvParser();

  test('parse returns ParsedArmCsv — metadata, assessments, high confidence', () {
    const sourceName = 'trial_book.csv';
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
      sourceFileName: sourceName,
    );

    expect(parsed.sourceFileName, sourceName);
    expect(parsed.rawHeaders, headers);
    expect(parsed.columnOrder, headers);
    expect(parsed.assessments.length, 1);
    expect(parsed.importConfidence, ImportConfidence.high);
    expect(parsed.hasSparseData, isFalse);
    expect(parsed.hasRepeatedCodes, isFalse);
  });

  test('sparse data detected when assessment cell empty', () {
    final headers = [
      'Plot No.',
      'trt',
      'reps',
      'AVEFA 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 1, ''],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 'sparse.csv',
    );

    expect(parsed.hasSparseData, isTrue);
  });

  test('repeated assessment key — flag and blocked confidence', () {
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
      sourceFileName: 'dup.csv',
    );

    expect(parsed.hasRepeatedCodes, isTrue);
    expect(
      parsed.unknownPatterns
          .where((f) => f.type == 'repeated-assessment-key')
          .length,
      1,
    );
    expect(parsed.importConfidence, ImportConfidence.blocked);
  });

  test('tryParseAssessmentToken accepts mixed-case Yield; armCode YIELD unit bu/ac', () {
    final t = parser.tryParseAssessmentToken(' 1-Sep-26 Yield bu/ac');
    expect(t, isNotNull);
    expect(t!.armCode, 'YIELD');
    expect(t.unit, 'bu/ac');
    expect(t.timingCode, '1-Sep-26');
  });

  test('missing rep column — identity incomplete — blocked', () {
    final headers = [
      'Plot No.',
      'trt',
      'AVEFA 1-Jul-26 CONTRO %',
    ];
    final rows = [
      [101, 1, 5],
    ];

    final parsed = parser.parse(
      headers: headers,
      rows: rows,
      sourceFileName: 'no_rep.csv',
    );

    expect(parsed.importConfidence, ImportConfidence.blocked);
  });
}
