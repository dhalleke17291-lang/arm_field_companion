import 'dart:io';

import 'package:arm_field_companion/data/services/arm_shell_parser.dart';
import 'package:arm_field_companion/data/services/arm_value_injector.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

String _cellStr(Sheet sheet, int row, int col) {
  final v = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? '';
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return v.value.toString();
  return v.toString();
}

void main() {
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('arm_value_injector');
    tempPath = dir.path;
  });

  test('injects Comments sheet ECM body from persisted text', () async {
    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      ratingTypes: const ['CONTRO'],
      commentsSheetBody: 'Original note from fixture.',
    );
    final shellImport = await ArmShellParser(shellPath).parse();
    expect(shellImport.commentsSheetText, 'Original note from fixture.');

    final outPath =
        '$tempPath/filled_${DateTime.now().microsecondsSinceEpoch}.xlsx';
    final injector = ArmValueInjector(shellImport);
    await injector.inject(
      const [],
      outPath,
      commentsSheetText:
          'Updated from arm_trial_metadata.shell_comments_sheet.',
    );

    final reparsed = await ArmShellParser(outPath).parse();
    expect(
      reparsed.commentsSheetText,
      'Updated from arm_trial_metadata.shell_comments_sheet.',
    );
  });

  test('omits Comments injection when commentsSheetText is null', () async {
    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      ratingTypes: const ['CONTRO'],
      commentsSheetBody: 'Keep me.',
    );
    final shellImport = await ArmShellParser(shellPath).parse();

    final outPath =
        '$tempPath/filled_${DateTime.now().microsecondsSinceEpoch}.xlsx';
    await ArmValueInjector(shellImport).inject(const [], outPath);

    final reparsed = await ArmShellParser(outPath).parse();
    expect(reparsed.commentsSheetText, 'Keep me.');
  });

  group('Subsample Plot Data injection', () {
    // Shell layout: 2 plots (101, 102), 1 ARM column ('3'), numSubsamples = 3.
    // Subsample Plot Data rows (0-based): 48=101-sub1, 49=101-sub2, 50=101-sub3,
    //                                     51=102-sub1, 52=102-sub2, 53=102-sub3.
    // ARM column '3' maps to col index 2.

    test('writes sub-unit values into correct Subsample Plot Data cells',
        () async {
      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101, 102],
        armColumnIds: const ['3'],
        seNames: const ['W003'],
        ratingTypes: const ['CONTRO'],
        subsamplePlotDataMirror: true,
        numSubsamples: 3,
      );
      final shellImport = await ArmShellParser(shellPath).parse();
      expect(shellImport.subsamplePlotRows.length, 6,
          reason: '2 plots × 3 subsamples');

      final outPath =
          '$tempPath/sub_filled_${DateTime.now().microsecondsSinceEpoch}.xlsx';
      final result = await ArmValueInjector(shellImport).inject(
        const [],
        outPath,
        subsampleValues: const [
          ArmSubsampleRatingValue(
              plotNumber: 101, armColumnId: '3', subUnitId: 1, value: '25'),
          ArmSubsampleRatingValue(
              plotNumber: 101, armColumnId: '3', subUnitId: 2, value: '30'),
          ArmSubsampleRatingValue(
              plotNumber: 101, armColumnId: '3', subUnitId: 3, value: '35'),
          ArmSubsampleRatingValue(
              plotNumber: 102, armColumnId: '3', subUnitId: 1, value: '40'),
          // sub-units 2 and 3 for plot 102 intentionally omitted → blank cells
        ],
      );

      expect(result.hasSkips, false);
      final bytes = await File(outPath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sub = excel.sheets['Subsample Plot Data'];
      expect(sub, isNotNull);

      // plot 101 rows 48–50, col 2
      expect(_cellStr(sub!, 48, 2), '25');
      expect(_cellStr(sub, 49, 2), '30');
      expect(_cellStr(sub, 50, 2), '35');
      // plot 102 sub-unit 1 at row 51
      expect(_cellStr(sub, 51, 2), '40');
      // omitted cells stay blank
      expect(_cellStr(sub, 52, 2), '');
      expect(_cellStr(sub, 53, 2), '');
    });

    test('skip reason added when Subsample Plot Data sheet is absent', () async {
      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['3'],
        seNames: const ['W003'],
        ratingTypes: const ['CONTRO'],
        // subsamplePlotDataMirror intentionally false → no sheet
      );
      final shellImport = await ArmShellParser(shellPath).parse();

      final outPath =
          '$tempPath/no_sub_sheet_${DateTime.now().microsecondsSinceEpoch}.xlsx';
      final result = await ArmValueInjector(shellImport).inject(
        const [],
        outPath,
        subsampleValues: const [
          ArmSubsampleRatingValue(
              plotNumber: 101, armColumnId: '3', subUnitId: 1, value: '10'),
        ],
      );

      expect(result.hasSkips, true);
      expect(
        result.skippedReasons.any((r) => r.contains('Subsample Plot Data')),
        true,
      );
    });

    test('omits Subsample Plot Data injection when subsampleValues is null',
        () async {
      final shellPath = await writeArmShellFixture(
        tempPath,
        plotNumbers: const [101],
        armColumnIds: const ['3'],
        seNames: const ['W003'],
        ratingTypes: const ['CONTRO'],
        subsamplePlotDataMirror: true,
        numSubsamples: 2,
      );
      final shellImport = await ArmShellParser(shellPath).parse();

      final outPath =
          '$tempPath/no_sub_values_${DateTime.now().microsecondsSinceEpoch}.xlsx';
      final result =
          await ArmValueInjector(shellImport).inject(const [], outPath);

      expect(result.hasSkips, false);
      // Subsample Plot Data sheet is present but untouched — cells stay blank.
      final bytes = await File(outPath).readAsBytes();
      final sub =
          Excel.decodeBytes(bytes).sheets['Subsample Plot Data'];
      expect(sub, isNotNull);
      expect(_cellStr(sub!, 48, 2), '');
      expect(_cellStr(sub, 49, 2), '');
    });
  });
}
