import 'package:arm_field_companion/domain/primitives/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // mean
  // ---------------------------------------------------------------------------

  group('mean', () {
    test('empty list returns NaN', () {
      expect(mean([]), isNaN);
    });

    test('single value returns that value', () {
      expect(mean([7.0]), 7.0);
    });

    test('symmetric list returns center value', () {
      expect(mean([1.0, 2.0, 3.0, 4.0, 5.0]), 3.0);
    });

    test('all zeros returns zero', () {
      expect(mean([0.0, 0.0, 0.0]), 0.0);
    });

    test('negative values are handled correctly', () {
      expect(mean([-3.0, -1.0, 0.0, 1.0, 3.0]), 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // variance
  // ---------------------------------------------------------------------------

  group('variance (population)', () {
    test('empty list returns NaN', () {
      expect(variance([]), isNaN);
    });

    test('single value has zero variance', () {
      expect(variance([42.0]), 0.0);
    });

    test('all identical values have zero variance', () {
      expect(variance([5.0, 5.0, 5.0]), 0.0);
    });

    test('known result: [2, 4, 4, 4, 5, 5, 7, 9] = 4.0', () {
      // Classic textbook example: population variance = 4.0
      expect(
        variance([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]),
        closeTo(4.0, 1e-10),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // stdDev
  // ---------------------------------------------------------------------------

  group('stdDev (population)', () {
    test('empty list returns NaN', () {
      expect(stdDev([]), isNaN);
    });

    test('single value has zero stdDev', () {
      expect(stdDev([99.0]), 0.0);
    });

    test('all identical values have zero stdDev', () {
      expect(stdDev([3.0, 3.0, 3.0]), 0.0);
    });

    test('known result: [2, 4, 4, 4, 5, 5, 7, 9] = 2.0', () {
      expect(
        stdDev([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]),
        closeTo(2.0, 1e-10),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // coefficientOfVariation
  // ---------------------------------------------------------------------------

  group('coefficientOfVariation', () {
    test('empty list returns NaN', () {
      expect(coefficientOfVariation([]), isNaN);
    });

    test('zero mean returns NaN (undefined)', () {
      // Mean = 0; CV = stdDev/0 is undefined.
      expect(coefficientOfVariation([0.0, 0.0, 0.0]), isNaN);
    });

    test('zero mean with mixed values returns NaN', () {
      expect(coefficientOfVariation([-1.0, 0.0, 1.0]), isNaN);
    });

    test('all identical non-zero values returns 0.0', () {
      // stdDev = 0, mean ≠ 0 → CV = 0.
      expect(coefficientOfVariation([5.0, 5.0, 5.0]), 0.0);
    });

    test('single non-zero value returns 0.0', () {
      expect(coefficientOfVariation([10.0]), 0.0);
    });

    test('known result: [2, 4, 4, 4, 5, 5, 7, 9] ≈ 40.0%', () {
      // mean=5, stdDev=2 → CV = 2/5 * 100 = 40.0
      expect(
        coefficientOfVariation([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]),
        closeTo(40.0, 1e-10),
      );
    });

    test('result is expressed as a percentage (not a ratio)', () {
      // mean=100, stdDev ≈ 8.16 → CV ≈ 8.16% — confirms result > 1, not a ratio < 1.
      final cv = coefficientOfVariation([90.0, 100.0, 110.0]);
      expect(cv, greaterThan(1.0));
    });
  });
}
