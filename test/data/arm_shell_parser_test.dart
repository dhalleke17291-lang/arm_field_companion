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
}
