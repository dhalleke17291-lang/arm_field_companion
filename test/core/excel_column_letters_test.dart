import 'package:arm_field_companion/core/excel_column_letters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('columnIndexToLettersZeroBased', () {
    test('A through BA examples', () {
      expect(columnIndexToLettersZeroBased(0), 'A');
      expect(columnIndexToLettersZeroBased(25), 'Z');
      expect(columnIndexToLettersZeroBased(26), 'AA');
      expect(columnIndexToLettersZeroBased(27), 'AB');
      expect(columnIndexToLettersZeroBased(51), 'AZ');
      expect(columnIndexToLettersZeroBased(52), 'BA');
    });
  });

  group('columnLettersToIndexZeroBased', () {
    test('A through BA examples', () {
      expect(columnLettersToIndexZeroBased('A'), 0);
      expect(columnLettersToIndexZeroBased('Z'), 25);
      expect(columnLettersToIndexZeroBased('AA'), 26);
      expect(columnLettersToIndexZeroBased('AB'), 27);
      expect(columnLettersToIndexZeroBased('AZ'), 51);
      expect(columnLettersToIndexZeroBased('BA'), 52);
    });

    test('trim and case', () {
      expect(columnLettersToIndexZeroBased('  aa  '), 26);
      expect(columnLettersToIndexZeroBased('ab'), 27);
      expect(columnLettersToIndexZeroBased(' A '), 0);
    });

    test('invalid returns null', () {
      expect(columnLettersToIndexZeroBased(''), isNull);
      expect(columnLettersToIndexZeroBased('1'), isNull);
      expect(columnLettersToIndexZeroBased('A1'), isNull);
    });
  });

  group('round-trip', () {
    test('selected indices', () {
      for (final idx in [0, 25, 26, 27, 51, 52]) {
        final letters = columnIndexToLettersZeroBased(idx);
        expect(columnLettersToIndexZeroBased(letters), idx);
      }
    });
  });
}
