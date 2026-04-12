import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_csv_parser.dart';

void main() {
  test('debug classification output', () {
    final headers = [
      'Trial ID',
      'Plot No.',
      'trt',
      'reps',
      'Treatment Name',
      'Form Conc',
      'Form Unit',
      'Form Type',
      ' Rate',
      'Rate Unit',
      'Appl Code',
      'AVEFA 1-Jul-26 CONTRO %',
      'SomeRandomColumn',
    ];

    final parser = ArmCsvParser();
    final result = parser.classifyHeaders(headers);

    for (final col in result) {
      // ignore: avoid_print
      print(
        '${col.index}: "${col.header}" -> ${col.kind}'
        '${col.identityRole != null ? ' [${col.identityRole}]' : ''}'
        '${col.assessmentToken != null ? ' [${col.assessmentToken!.assessmentKey}]' : ''}',
      );
    }

    expect(result.length, headers.length);
  });
}
