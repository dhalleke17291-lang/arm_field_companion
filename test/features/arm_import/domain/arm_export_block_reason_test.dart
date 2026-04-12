import 'package:arm_field_companion/features/arm_import/domain/arm_export_block_reason.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/parsed_arm_csv.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/unknown_pattern_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns null when import is not blocked', () {
    const parsed = ParsedArmCsv(
      sourceFileName: 'x.csv',
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: [],
      columnOrder: [],
      columns: [],
      dataRows: [],
      assessments: [],
      unknownPatterns: [],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: false,
      importConfidence: ImportConfidence.high,
    );
    expect(buildExportBlockReasonFromParsed(parsed), isNull);
  });

  test('blocked with duplicate-assessment-column-instance builds concrete reason',
      () {
    const parsed = ParsedArmCsv(
      sourceFileName: 'x.csv',
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: [],
      columnOrder: [],
      columns: [],
      dataRows: [],
      assessments: [],
      unknownPatterns: [
        UnknownPatternFlag(
          type: 'duplicate-assessment-column-instance',
          severity: PatternSeverity.high,
          affectsExport: true,
          rawValue: 'CONTRO|1-Jul-26|%|col3',
        ),
      ],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: true,
      importConfidence: ImportConfidence.blocked,
    );
    final r = buildExportBlockReasonFromParsed(parsed);
    expect(r, isNotNull);
    expect(r, contains('CONTRO|1-Jul-26|%|col3'));
    expect(r, contains('safe rating sheet round-trip export'));
  });

  test('repeated semantic assessment flag alone does not build block reason', () {
    const parsed = ParsedArmCsv(
      sourceFileName: 'x.csv',
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: [],
      columnOrder: [],
      columns: [],
      dataRows: [],
      assessments: [],
      unknownPatterns: [
        UnknownPatternFlag(
          type: 'repeated-semantic-assessment-key',
          severity: PatternSeverity.low,
          affectsExport: false,
          rawValue: 'CONTRO|1-Jul-26|%',
        ),
      ],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: true,
      importConfidence: ImportConfidence.high,
    );
    expect(buildExportBlockReasonFromParsed(parsed), isNull);
  });

  test('blocked with no high flags uses identity fallback', () {
    const parsed = ParsedArmCsv(
      sourceFileName: 'x.csv',
      sourceRoute: 'arm_csv_v1_unvalidated',
      armVersionHint: null,
      rawHeaders: [],
      columnOrder: [],
      columns: [],
      dataRows: [],
      assessments: [],
      unknownPatterns: [],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: false,
      importConfidence: ImportConfidence.blocked,
    );
    final r = buildExportBlockReasonFromParsed(parsed);
    expect(r, isNotNull);
    expect(r, contains('plot'));
    expect(r, contains('treatment'));
  });
}
