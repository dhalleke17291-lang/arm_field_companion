import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_report_builder.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/parsed_arm_csv.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/unknown_pattern_flag.dart';

void main() {
  final parser = ArmCsvParser();
  final builder = ArmImportReportBuilder();

  test('clean parsed CSV builds high-confidence report', () {
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
      sourceFileName: 'clean.csv',
    );

    final report = builder.build(parsed);

    expect(report.confidence, ImportConfidence.high);
    expect(report.plotsDetected, 2);
    expect(report.treatmentsDetected, 2);
    expect(report.assessmentsDetected, 1);
    expect(report.warnings, isEmpty);
    expect(report.exportStatus, 'Ready');
  });

  test('sparse data adds warning', () {
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

    final report = builder.build(parsed);

    expect(
      report.warnings,
      contains(
        'Some assessment values are blank and were imported as null.',
      ),
    );
  });

  test('repeated assessment key adds warning and blocked status', () {
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

    final report = builder.build(parsed);

    expect(report.confidence, ImportConfidence.blocked);
    expect(
      report.warnings,
      contains(
        'Repeated assessment keys were detected. ARM round-trip export '
        'cannot run safely until this is resolved.',
      ),
    );
    expect(report.exportStatus, 'Blocked');
  });

  test('medium unknown pattern contributes warning text', () {
    const parsed = ParsedArmCsv(
      sourceFileName: 'manual',
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: [],
      columnOrder: [],
      columns: [],
      dataRows: [],
      assessments: [],
      unknownPatterns: [
        UnknownPatternFlag(
          type: 'missing-rep',
          severity: PatternSeverity.medium,
          affectsExport: true,
          rawValue: '',
        ),
      ],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: false,
      importConfidence: ImportConfidence.medium,
    );

    final report = builder.build(parsed);

    expect(
      report.warnings,
      contains('Unvalidated structure detected: missing-rep.'),
    );
    expect(report.exportStatus, 'Needs review');
  });
}
