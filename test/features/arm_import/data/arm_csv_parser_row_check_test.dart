import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';

/// Column order matches [classifyHeaders] indices: 0 Trial ID, 1 Plot No., 2 trt, 3 reps, …
List<String> standardHeaders() => [
      'Trial ID',
      'Plot No.',
      'trt',
      'reps',
      'Treatment Name',
    ];

void main() {
  final parser = ArmCsvParser();

  test('normal rows — no integrity flags', () {
    final headers = standardHeaders();
    final rows = [
      ['T1', '1', '2', '1', 'N1'],
      ['T1', '2', '1', '1', 'N2'],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(result.rowCount, 2);
    expect(result.flags, isEmpty);
    expect(result.parsedRows[0]['Plot No.'], '1');
    expect(result.parsedRows[0]['trt'], '2');
    expect(result.parsedRows[1]['Plot No.'], '2');
  });

  test('blank cell becomes null', () {
    final headers = standardHeaders();
    final rows = [
      ['', '1', '2', '1', 'Name'],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(result.parsedRows[0]['Trial ID'], isNull);
    expect(result.parsedRows[0]['Treatment Name'], 'Name');
  });

  test('missing or invalid plot number', () {
    final headers = standardHeaders();
    final rows = [
      ['T1', '', '2', '1', ''],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(
      result.flags.where((f) => f.type == 'missing-or-invalid-plot-number'),
      isNotEmpty,
    );
  });

  test('duplicate plot number', () {
    final headers = standardHeaders();
    final rows = [
      ['T1', '1', '2', '1', 'A'],
      ['T1', '1', '3', '1', 'B'],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(
      result.flags.where((f) => f.type == 'duplicate-plot-number'),
      isNotEmpty,
    );
  });

  test('missing treatment number', () {
    final headers = standardHeaders();
    final rows = [
      ['T1', '1', '', '1', ''],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(
      result.flags.where((f) => f.type == 'missing-treatment-number'),
      isNotEmpty,
    );
  });

  test('missing rep', () {
    final headers = standardHeaders();
    final rows = [
      ['T1', '1', '2', '', ''],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(
      result.flags.where((f) => f.type == 'missing-rep'),
      isNotEmpty,
    );
  });

  test('short row — missing cells yield nulls and integrity flags', () {
    final headers = standardHeaders();
    final rows = [
      ['only-one-cell'],
    ];

    final result = parser.verifyRows(rows: rows, headers: headers);

    expect(result.rowCount, 1);
    expect(result.parsedRows[0]['Trial ID'], 'only-one-cell');
    expect(result.parsedRows[0]['Plot No.'], isNull);
    expect(result.parsedRows[0]['trt'], isNull);
    expect(result.parsedRows[0]['reps'], isNull);

    expect(
      result.flags.where((f) => f.type == 'missing-or-invalid-plot-number'),
      isNotEmpty,
    );
    expect(
      result.flags.where((f) => f.type == 'missing-treatment-number'),
      isNotEmpty,
    );
    expect(
      result.flags.where((f) => f.type == 'missing-rep'),
      isNotEmpty,
    );
  });
}
