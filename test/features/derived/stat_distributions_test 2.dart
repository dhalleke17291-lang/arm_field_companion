import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/derived/domain/stat_distributions.dart';

void main() {
  group('fDistributionPValue', () {
    // Validated against R: pf(q, df1, df2, lower.tail=FALSE)
    test('F=4.26, df1=3, df2=20 → p≈0.018', () {
      final p = fDistributionPValue(4.26, 3, 20);
      expect(p, closeTo(0.0179, 0.001));
    });

    test('F=1.0, df1=5, df2=30 → p≈0.434', () {
      final p = fDistributionPValue(1.0, 5, 30);
      expect(p, closeTo(0.434, 0.005));
    });

    test('F=10.0, df1=2, df2=12 → p≈0.0028', () {
      final p = fDistributionPValue(10.0, 2, 12);
      expect(p, closeTo(0.0028, 0.001));
    });

    test('F=0, any df → p=1.0', () {
      expect(fDistributionPValue(0, 3, 20), closeTo(1.0, 0.001));
    });

    test('very large F → p≈0', () {
      final p = fDistributionPValue(100.0, 3, 20);
      expect(p, lessThan(0.0001));
    });

    // Common ANOVA scenario: 4 treatments, 4 reps (df1=3, df2=12)
    test('F=3.49, df1=3, df2=12 → p≈0.05 (critical value)', () {
      final p = fDistributionPValue(3.49, 3, 12);
      expect(p, closeTo(0.05, 0.005));
    });
  });

  group('tCriticalTwoTailed', () {
    // Validated against R: qt(1-alpha/2, df)
    test('alpha=0.05, df=12 → t≈2.179', () {
      final t = tCriticalTwoTailed(0.05, 12);
      expect(t, closeTo(2.179, 0.005));
    });

    test('alpha=0.05, df=20 → t≈2.086', () {
      final t = tCriticalTwoTailed(0.05, 20);
      expect(t, closeTo(2.086, 0.005));
    });

    test('alpha=0.01, df=12 → t≈3.055', () {
      final t = tCriticalTwoTailed(0.01, 12);
      expect(t, closeTo(3.055, 0.005));
    });

    test('alpha=0.05, df=120 → t≈1.980', () {
      final t = tCriticalTwoTailed(0.05, 120);
      expect(t, closeTo(1.980, 0.005));
    });
  });

  group('tDistributionCdf', () {
    test('t=0, any df → 0.5', () {
      expect(tDistributionCdf(0, 10), closeTo(0.5, 0.001));
    });

    test('positive t → CDF > 0.5', () {
      expect(tDistributionCdf(2.0, 10), greaterThan(0.5));
    });

    test('negative t → CDF < 0.5', () {
      expect(tDistributionCdf(-2.0, 10), lessThan(0.5));
    });

    test('symmetry: CDF(t) + CDF(-t) ≈ 1', () {
      final pos = tDistributionCdf(1.5, 15);
      final neg = tDistributionCdf(-1.5, 15);
      expect(pos + neg, closeTo(1.0, 0.001));
    });
  });

  group('fDistributionCdf', () {
    test('x=0 → 0', () {
      expect(fDistributionCdf(0, 3, 20), 0);
    });

    test('x=1, equal df → CDF≈0.5', () {
      // F(1 | d1=d2) should be close to 0.5
      expect(fDistributionCdf(1.0, 10, 10), closeTo(0.5, 0.02));
    });
  });
}
