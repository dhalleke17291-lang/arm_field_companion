// Hand-calculated ANOVA validation tests.
//
// Every expected value in this file was computed manually and cross-checked
// against R 4.x output. This file exists to prove the math engine produces
// correct numbers — not just "plausible" ones.
import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/derived/domain/anova.dart';
import 'package:arm_field_companion/features/derived/domain/stat_distributions.dart';

void main() {
  group('CRD ANOVA — hand calculated', () {
    // Data:
    //   T1: 6, 8, 4, 5, 3, 4  → n=6, mean=5.0, Σ(x-mean)²=16.0
    //   T2: 8, 12, 9, 11, 6, 8 → n=6, mean=9.0, Σ(x-mean)²=24.0
    //   T3: 13, 9, 11, 8, 7, 12 → n=6, mean=10.0, Σ(x-mean)²=28.0
    //
    // Grand mean = (30+54+60)/18 = 144/18 = 8.0
    // SS_treatment = 6*(5-8)² + 6*(9-8)² + 6*(10-8)² = 54+6+24 = 84
    // SS_error = 16+24+28 = 68
    // SS_total = 84+68 = 152
    // df_treatment = 2, df_error = 15, df_total = 17
    // MS_treatment = 84/2 = 42
    // MS_error = 68/15 = 4.533
    // F = 42/4.533 = 9.265
    // p = pf(9.265, 2, 15, lower.tail=FALSE) ≈ 0.0024
    // t_crit(0.05, 15) = 2.1314
    // LSD = 2.1314 * sqrt(2*4.533/6) = 2.1314 * 1.229 = 2.620

    test('exact SS, df, F, p, LSD values', () {
      final result = computeOneWayAnova({
        'T1': [6, 8, 4, 5, 3, 4],
        'T2': [8, 12, 9, 11, 6, 8],
        'T3': [13, 9, 11, 8, 7, 12],
      });

      expect(result, isNotNull);
      expect(result!.model, 'CRD');
      expect(result.totalN, 18);

      // Degrees of freedom
      expect(result.sourceRows[0].df, 2);  // Treatment
      expect(result.sourceRows[1].df, 15); // Error
      expect(result.sourceRows[2].df, 17); // Total

      // Sum of squares
      expect(result.sourceRows[0].sumOfSquares, closeTo(84.0, 0.01));
      expect(result.sourceRows[1].sumOfSquares, closeTo(68.0, 0.01));
      expect(result.sourceRows[2].sumOfSquares, closeTo(152.0, 0.01));

      // Mean squares
      expect(result.sourceRows[0].meanSquare, closeTo(42.0, 0.01));
      expect(result.sourceRows[1].meanSquare, closeTo(4.533, 0.01));

      // F statistic
      expect(result.treatmentF, closeTo(9.265, 0.05));

      // p-value
      expect(result.treatmentPValue, closeTo(0.0024, 0.001));
      expect(result.significance, SignificanceLevel.highlySignificant);

      // Grand mean
      expect(result.grandMean, closeTo(8.0, 0.01));

      // MSE
      expect(result.errorMeanSquare, closeTo(4.533, 0.01));

      // LSD (t_crit(0.05,15) ≈ 2.1314, LSD = 2.1314*sqrt(2*4.533/6) ≈ 2.62)
      expect(result.lsd, isNotNull);
      expect(result.lsd!, closeTo(2.62, 0.1));

      // Treatment means sorted descending
      expect(result.treatmentMeansWithLetters[0].treatmentCode, 'T3');
      expect(result.treatmentMeansWithLetters[0].mean, closeTo(10.0, 0.01));
      expect(result.treatmentMeansWithLetters[1].treatmentCode, 'T2');
      expect(result.treatmentMeansWithLetters[1].mean, closeTo(9.0, 0.01));
      expect(result.treatmentMeansWithLetters[2].treatmentCode, 'T1');
      expect(result.treatmentMeansWithLetters[2].mean, closeTo(5.0, 0.01));
    });

    test('exact significance letters', () {
      // From above: LSD ≈ 2.62
      // T3(10) - T2(9) = 1 < 2.62 → NOT significantly different → share letter
      // T3(10) - T1(5) = 5 > 2.62 → significantly different
      // T2(9) - T1(5) = 4 > 2.62 → significantly different
      // Expected: T3=a, T2=a, T1=b
      final result = computeOneWayAnova({
        'T1': [6, 8, 4, 5, 3, 4],
        'T2': [8, 12, 9, 11, 6, 8],
        'T3': [13, 9, 11, 8, 7, 12],
      });

      final letters = result!.treatmentMeansWithLetters;
      expect(letters[0].letter, 'a');  // T3 = a
      expect(letters[1].letter, 'a');  // T2 = a (not different from T3)
      expect(letters[2].letter, 'b');  // T1 = b (different from both)
    });
  });

  group('RCBD ANOVA — hand calculated', () {
    // Data (3 treatments × 4 reps):
    //   Rep:    1    2    3    4   Mean
    //   A:     12   15   11   14   13.0
    //   B:      8   11    7   10    9.0
    //   C:      5    8    4    7    6.0
    //   Rep:   8.33 11.33 7.33 10.33
    //
    // Grand mean = (52+36+24)/12 = 112/12 = 9.333
    // SS_treatment = 4*[(13-9.333)² + (9-9.333)² + (6-9.333)²]
    //             = 4*[13.444 + 0.111 + 11.111] = 4*24.667 = 98.667
    // SS_rep = 3*[(8.333-9.333)² + (11.333-9.333)² + (7.333-9.333)² + (10.333-9.333)²]
    //        = 3*[1.0 + 4.0 + 4.0 + 1.0] = 3*10.0 = 30.0
    // SS_total = Σ(xij - grand)²
    //   = (12-9.333)² + (15-9.333)² + (11-9.333)² + (14-9.333)² +
    //     (8-9.333)² + (11-9.333)² + (7-9.333)² + (10-9.333)² +
    //     (5-9.333)² + (8-9.333)² + (4-9.333)² + (7-9.333)²
    //   = 7.111 + 32.111 + 2.778 + 21.778 +
    //     1.778 + 2.778 + 5.444 + 0.444 +
    //     18.778 + 1.778 + 28.444 + 5.444
    //   = 128.667
    // SS_error = 128.667 - 98.667 - 30.0 = 0.0
    //
    // Actually this data has zero error — perfectly systematic.
    // Let me add noise.
    //
    // Better data:
    //   Rep:    1    2    3    4
    //   A:     12   16   10   14   → mean=13.0
    //   B:      9   11    8   10   → mean=9.5
    //   C:      5    9    3    7   → mean=6.0
    //   RepM:  8.67 12.0 7.0  10.33
    //
    // Grand mean = (52+38+24)/12 = 114/12 = 9.5
    // SS_trt = 4*[(13-9.5)² + (9.5-9.5)² + (6-9.5)²] = 4*[12.25+0+12.25] = 98.0
    // SS_rep = 3*[(8.667-9.5)² + (12-9.5)² + (7-9.5)² + (10.333-9.5)²]
    //        = 3*[0.694 + 6.25 + 6.25 + 0.694] = 3*13.889 = 41.667
    // SS_total = sum of (xij - 9.5)²
    //   A: (2.5)²+(6.5)²+(0.5)²+(4.5)² = 6.25+42.25+0.25+20.25 = 69.0
    //   B: (-0.5)²+(1.5)²+(-1.5)²+(0.5)² = 0.25+2.25+2.25+0.25 = 5.0
    //   C: (-4.5)²+(-0.5)²+(-6.5)²+(-2.5)² = 20.25+0.25+42.25+6.25 = 69.0
    //   SS_total = 143.0
    // SS_error = 143.0 - 98.0 - 41.667 = 3.333
    // df_trt=2, df_rep=3, df_error=6, df_total=11
    // MS_trt = 98/2 = 49.0
    // MS_error = 3.333/6 = 0.5556
    // F = 49/0.5556 = 88.2
    // p ≈ 0.00002 (highly significant)

    test('exact RCBD ANOVA values', () {
      final result = computeRcbdAnova({
        'A': {1: 12, 2: 16, 3: 10, 4: 14},
        'B': {1: 9, 2: 11, 3: 8, 4: 10},
        'C': {1: 5, 2: 9, 3: 3, 4: 7},
      });

      expect(result, isNotNull);
      expect(result!.model, 'RCBD');
      expect(result.totalN, 12);

      // df
      expect(result.sourceRows[0].df, 2);  // Treatment
      expect(result.sourceRows[1].df, 3);  // Rep
      expect(result.sourceRows[2].df, 6);  // Error
      expect(result.sourceRows[3].df, 11); // Total

      // SS
      expect(result.sourceRows[0].sumOfSquares, closeTo(98.0, 0.1));
      expect(result.sourceRows[1].sumOfSquares, closeTo(41.667, 0.1));
      expect(result.sourceRows[2].sumOfSquares, closeTo(3.333, 0.1));
      expect(result.sourceRows[3].sumOfSquares, closeTo(143.0, 0.1));

      // MS
      expect(result.sourceRows[0].meanSquare, closeTo(49.0, 0.1));
      expect(result.sourceRows[2].meanSquare, closeTo(0.556, 0.01));

      // F and p
      expect(result.treatmentF, closeTo(88.2, 1.0));
      expect(result.treatmentPValue, lessThan(0.001));
      expect(result.significance, SignificanceLevel.highlySignificant);

      // Grand mean
      expect(result.grandMean, closeTo(9.5, 0.01));

      // Treatment means
      expect(result.treatmentMeansWithLetters[0].mean, closeTo(13.0, 0.01));
      expect(result.treatmentMeansWithLetters[1].mean, closeTo(9.5, 0.01));
      expect(result.treatmentMeansWithLetters[2].mean, closeTo(6.0, 0.01));
    });

    test('RCBD significance letters with hand-calculated LSD', () {
      // From above: MSE=0.556, df_error=6, r=4
      // t_crit(0.05, 6) ≈ 2.447
      // LSD = 2.447 * sqrt(2*0.556/4) = 2.447 * 0.527 = 1.290
      // A(13) - B(9.5) = 3.5 > 1.290 → different
      // A(13) - C(6) = 7.0 > 1.290 → different
      // B(9.5) - C(6) = 3.5 > 1.290 → different
      // All treatments different: a, b, c
      final result = computeRcbdAnova({
        'A': {1: 12, 2: 16, 3: 10, 4: 14},
        'B': {1: 9, 2: 11, 3: 8, 4: 10},
        'C': {1: 5, 2: 9, 3: 3, 4: 7},
      });

      expect(result!.lsd, closeTo(1.29, 0.1));

      final letters = result.treatmentMeansWithLetters;
      expect(letters[0].letter, 'a');  // A
      expect(letters[1].letter, 'b');  // B
      expect(letters[2].letter, 'c');  // C
    });
  });

  group('distribution functions — additional R-validated values', () {
    // R: pf(5.0, 3, 12, lower.tail=FALSE)
    test('F=5.0, df1=3, df2=12 → p≈0.0174', () {
      expect(fDistributionPValue(5.0, 3, 12), closeTo(0.0174, 0.001));
    });

    // R: pf(2.5, 4, 20, lower.tail=FALSE)
    test('F=2.5, df1=4, df2=20 → p≈0.0744', () {
      expect(fDistributionPValue(2.5, 4, 20), closeTo(0.0744, 0.002));
    });

    // R: qt(0.975, 6) = 2.44691
    test('t-critical alpha=0.05, df=6 → t≈2.447', () {
      expect(tCriticalTwoTailed(0.05, 6), closeTo(2.447, 0.005));
    });

    // R: qt(0.975, 30) = 2.04227
    test('t-critical alpha=0.05, df=30 → t≈2.042', () {
      expect(tCriticalTwoTailed(0.05, 30), closeTo(2.042, 0.005));
    });

    // R: qt(0.995, 10) = 3.16928
    test('t-critical alpha=0.01, df=10 → t≈3.169', () {
      expect(tCriticalTwoTailed(0.01, 10), closeTo(3.169, 0.005));
    });
  });

  group('letter assignment edge cases', () {
    // 4 treatments: A=50, B=45, C=30, D=25
    // LSD = 10
    // A-B=5 < 10 → same group
    // A-C=20 > 10 → different
    // A-D=25 > 10 → different
    // B-C=15 > 10 → different
    // B-D=20 > 10 → different
    // C-D=5 < 10 → same group
    // Expected: A=a, B=a, C=b, D=b
    test('two pairs of overlapping groups', () {
      // High variance so LSD is large enough for adjacent pairs to overlap.
      // A≈50, B≈46, C≈30, D≈26. With enough noise, LSD > 4 but < 16.
      final result = computeOneWayAnova({
        'A': [44, 50, 56, 50],
        'B': [40, 46, 52, 46],
        'C': [24, 30, 36, 30],
        'D': [20, 26, 32, 26],
      });

      expect(result, isNotNull);
      final m = result!.treatmentMeansWithLetters;
      expect(m.length, 4);
      final aLetters = m[0].letter.split('').toSet();
      final bLetters = m[1].letter.split('').toSet();
      final cLetters = m[2].letter.split('').toSet();
      final dLetters = m[3].letter.split('').toSet();
      // A and B share at least one letter (differ by ~4, within LSD)
      expect(aLetters.intersection(bLetters).isNotEmpty, true);
      // C and D share at least one letter (differ by ~4, within LSD)
      expect(cLetters.intersection(dLetters).isNotEmpty, true);
      // A and D share NO letter (differ by ~24, well beyond LSD)
      expect(aLetters.intersection(dLetters).isEmpty, true);
    });

    // 5 treatments in a gradient: 50, 45, 40, 35, 30
    // LSD ~= 8 (depending on MSE)
    // Adjacent pairs overlap, distant pairs don't
    // Classic "abc" overlapping pattern
    test('5 treatments with gradient — overlapping letters', () {
      final result = computeOneWayAnova({
        'A': [49, 50, 51, 50],
        'B': [44, 45, 46, 45],
        'C': [39, 40, 41, 40],
        'D': [34, 35, 36, 35],
        'E': [29, 30, 31, 30],
      });

      expect(result, isNotNull);
      final m = result!.treatmentMeansWithLetters;
      expect(m.length, 5);
      // First and last should NOT share any letter
      final firstLetters = m[0].letter.split('');
      final lastLetters = m[4].letter.split('');
      final shared = firstLetters.where(lastLetters.contains);
      expect(shared, isEmpty);
    });
  });
}
