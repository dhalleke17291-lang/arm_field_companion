import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/features/plots/utils/plot_analysis_utils.dart';

void main() {
  group('getCVTier', () {
    test('PAU-1: CV < 15 → acceptable', () {
      expect(getCVTier(0), CVTier.acceptable);
      expect(getCVTier(14.9), CVTier.acceptable);
    });

    test('PAU-2: 15 ≤ CV < 25 → moderate', () {
      expect(getCVTier(15), CVTier.moderate);
      expect(getCVTier(24.9), CVTier.moderate);
    });

    test('PAU-3: CV ≥ 25 → high', () {
      expect(getCVTier(25), CVTier.high);
      expect(getCVTier(100), CVTier.high);
    });
  });

  group('computeSD', () {
    test('PAU-4: single value returns 0', () {
      expect(computeSD([42.0]), 0.0);
    });

    test('PAU-5: identical values returns 0', () {
      expect(computeSD([5.0, 5.0, 5.0, 5.0]), 0.0);
    });

    test('PAU-6: known SD — [2, 4, 4, 4, 5, 5, 7, 9] sample SD ≈ 2.138', () {
      // Sample SD (n-1): √(32/7) ≈ 2.138; population SD would be 2.0
      final result = computeSD([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(result, closeTo(2.138, 0.001));
    });

    test('PAU-7: two values [0, 10] → SD = 7.071', () {
      final result = computeSD([0, 10]);
      expect(result, closeTo(7.071, 0.01));
    });
  });

  group('computePooledCV', () {
    test('PAU-8: single treatment with n=1 → null (no df)', () {
      final result = computePooledCV(means: [10.0], sds: [0.0], ns: [1]);
      expect(result, isNull);
    });

    test('PAU-9: grand mean 0 → null', () {
      final result = computePooledCV(means: [0.0], sds: [1.0], ns: [5]);
      expect(result, isNull);
    });

    test('PAU-10: known case — 2 treatments, 4 plots each', () {
      // T1: mean=50, sd=5, n=4; T2: mean=50, sd=5, n=4
      // pooledSd = 5, grandMean = 50, CV = 10%
      final result = computePooledCV(
        means: [50.0, 50.0],
        sds: [5.0, 5.0],
        ns: [4, 4],
      );
      expect(result, closeTo(10.0, 0.001));
    });

    test('PAU-11: different treatment sizes weighted correctly', () {
      // T1: mean=100, sd=10, n=3; T2: mean=100, sd=20, n=5
      // pooledVar = (2*100 + 4*400)/(2+4) = (200+1600)/6 = 300, pooledSd ≈ 17.32
      // grandMean = (3*100 + 5*100)/8 = 100, CV ≈ 17.32%
      final result = computePooledCV(
        means: [100.0, 100.0],
        sds: [10.0, 20.0],
        ns: [3, 5],
      );
      expect(result, closeTo(17.32, 0.1));
    });
  });

  group('detectOutlierIndices', () {
    test('PAU-12: < 4 values returns empty', () {
      expect(detectOutlierIndices([1.0, 2.0, 3.0]), isEmpty);
    });

    test('PAU-13: all identical (zero IQR) returns empty', () {
      expect(detectOutlierIndices([5.0, 5.0, 5.0, 5.0, 5.0]), isEmpty);
    });

    test('PAU-14: clear outlier detected', () {
      // [10, 11, 10, 12, 11, 100] — 100 is a clear outlier
      final indices =
          detectOutlierIndices([10.0, 11.0, 10.0, 12.0, 11.0, 100.0]);
      expect(indices, contains(5));
      expect(indices.length, 1);
    });

    test('PAU-15: no outliers in normally distributed data', () {
      final indices = detectOutlierIndices([8.0, 9.0, 10.0, 11.0, 12.0]);
      expect(indices, isEmpty);
    });
  });

  group('detectZeroVariance', () {
    test('PAU-16: all non-zero SDs → false', () {
      expect(detectZeroVariance([1.0, 2.0, 0.5]), isFalse);
    });

    test('PAU-17: one zero SD → true', () {
      expect(detectZeroVariance([1.0, 0.0, 2.0]), isTrue);
    });

    test('PAU-18: empty list → false', () {
      expect(detectZeroVariance([]), isFalse);
    });
  });

  group('computeQuartiles', () {
    test('PAU-19: empty returns zeros', () {
      final q = computeQuartiles([]);
      expect(q.q1, 0.0);
      expect(q.median, 0.0);
      expect(q.q3, 0.0);
    });

    test('PAU-20: [1,2,3,4,5] — median=3, q1=2, q3=4 (inclusive-index interp)', () {
      // index = p/100 * (n-1): Q1 index=1.0 → sorted[1]=2; Q3 index=3.0 → sorted[3]=4
      final q = computeQuartiles([1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(q.median, closeTo(3.0, 0.001));
      expect(q.q1, closeTo(2.0, 0.001));
      expect(q.q3, closeTo(4.0, 0.001));
    });

    test('PAU-21: single value — all quartiles equal that value', () {
      final q = computeQuartiles([7.0]);
      expect(q.q1, 7.0);
      expect(q.median, 7.0);
      expect(q.q3, 7.0);
    });
  });
}
