import 'package:arm_field_companion/features/trials/tabs/application_sheet_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── parseBbch ─────────────────────────────────────────────────────────────

  group('parseBbch', () {
    test('1 — returns integer for valid input', () {
      expect(parseBbch('32'), 32);
      expect(parseBbch('0'), 0);
      expect(parseBbch('99'), 99);
    });

    test('2 — returns null for empty string', () {
      expect(parseBbch(''), isNull);
      expect(parseBbch('   '), isNull);
    });

    test('3 — returns null for non-integer input', () {
      expect(parseBbch('abc'), isNull);
      expect(parseBbch('3.5'), isNull);
    });

    test('4 — trims whitespace before parsing', () {
      expect(parseBbch('  45  '), 45);
    });
  });

  // ─── validateBbch ──────────────────────────────────────────────────────────

  group('validateBbch', () {
    test('5 — accepts 0', () {
      expect(validateBbch('0'), isNull);
    });

    test('6 — accepts 99', () {
      expect(validateBbch('99'), isNull);
    });

    test('7 — accepts empty (nullable field)', () {
      expect(validateBbch(''), isNull);
      expect(validateBbch(null), isNull);
      expect(validateBbch('   '), isNull);
    });

    test('8 — rejects values below 0', () {
      expect(validateBbch('-1'), 'Enter a value between 0 and 99');
    });

    test('9 — rejects values above 99', () {
      expect(validateBbch('100'), 'Enter a value between 0 and 99');
      expect(validateBbch('999'), 'Enter a value between 0 and 99');
    });

    test('10 — rejects non-integer text', () {
      expect(validateBbch('abc'), 'Enter a value between 0 and 99');
    });
  });
}
