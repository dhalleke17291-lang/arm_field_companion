import 'dart:io';

import 'package:arm_field_companion/data/services/arm_shell_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

void main() {
  late String tempPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('arm_shell_parser');
    tempPath = dir.path;
  });

  test('parses seDescription from row 14 per assessment column', () async {
    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      seDescriptions: const ['Percent weed control in plot'],
      ratingDates: const ['1-Jul-26'],
      ratingTypes: const ['CONTRO'],
    );
    final shell = await ArmShellParser(path).parse();
    expect(shell.assessmentColumns, hasLength(1));
    expect(
      shell.assessmentColumns.single.seDescription,
      'Percent weed control in plot',
    );
    expect(shell.assessmentColumns.single.ratingDate, '1-Jul-26');
  });

  test('reads collect basis from row 24 and size unit from row 23', () async {
    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      plotDataSizeUnit: 'PLOT',
      plotDataCollectBasis: '1',
    );
    final shell = await ArmShellParser(path).parse();
    final c = shell.assessmentColumns.single;
    expect(c.sizeUnit, 'PLOT');
    expect(c.collectBasis, '1');
  });

  test('pestCodeFromSheet comes from row 9, not SE Name row', () async {
    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      pestCodesFromSheet: const ['EPPO123'],
      ratingTypes: const ['CONTRO'],
    );
    final shell = await ArmShellParser(path).parse();
    final c = shell.assessmentColumns.single;
    expect(c.seName, 'W003');
    expect(c.pestCodeFromSheet, 'EPPO123');
  });

  test('Applications sheet: parses populated columns C and D (79 rows)', () async {
    List<String?> app79({
      String? r1date,
      String? r7timing,
    }) {
      final r = List<String?>.filled(79, null);
      r[0] = r1date;
      r[6] = r7timing;
      return r;
    }

    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      ratingTypes: const ['CONTRO'],
      applicationSheetColumns: [
        app79(r1date: '10-May-26', r7timing: 'A1'),
        app79(r1date: '11-May-26', r7timing: 'A3'),
      ],
    );
    final shell = await ArmShellParser(path).parse();
    expect(shell.applicationSheetColumns, hasLength(2));
    expect(shell.applicationSheetColumns[0].columnIndex, 2);
    expect(shell.applicationSheetColumns[0].row01To79[0], '10-May-26');
    expect(shell.applicationSheetColumns[0].row01To79[6], 'A1');
    expect(shell.applicationSheetColumns[1].columnIndex, 3);
    expect(shell.applicationSheetColumns[1].row01To79[0], '11-May-26');
    expect(shell.applicationSheetColumns[1].row01To79[6], 'A3');
  });

  test('Applications sheet: missing in minimal workbook → empty list', () async {
    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      ratingTypes: const ['CONTRO'],
    );
    final shell = await ArmShellParser(path).parse();
    expect(shell.applicationSheetColumns, isEmpty);
  });

  test('Comments sheet: parses ECM body text from column B', () async {
    final path = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['3'],
      seNames: const ['W003'],
      ratingTypes: const ['CONTRO'],
      commentsSheetBody: 'Plot layout adjusted per cooperator.',
    );
    final shell = await ArmShellParser(path).parse();
    expect(
      shell.commentsSheetText,
      'Plot layout adjusted per cooperator.',
    );
  });

  test('AgQuest fixture: Comments sheet present but empty body → null', () async {
    final shell = await ArmShellParser(
      'test/fixtures/arm_shells/AgQuest_RatingShell.xlsx',
    ).parse();
    expect(shell.commentsSheetText, isNull);
  });
}
