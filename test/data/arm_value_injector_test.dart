import 'dart:io';

import 'package:arm_field_companion/data/services/arm_shell_parser.dart';
import 'package:arm_field_companion/data/services/arm_value_injector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

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

    final outPath = '$tempPath/filled_${DateTime.now().microsecondsSinceEpoch}.xlsx';
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

    final outPath = '$tempPath/filled_${DateTime.now().microsecondsSinceEpoch}.xlsx';
    await ArmValueInjector(shellImport).inject(const [], outPath);

    final reparsed = await ArmShellParser(outPath).parse();
    expect(reparsed.commentsSheetText, 'Keep me.');
  });
}
