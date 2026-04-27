import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/features/derived/domain/anova.dart';

void main() {
  group('computeOneWayAnova (CRD)', () {
    test('basic 3 treatments — known textbook values', () {
      // Example: 3 treatments, 4 reps each.
      // T1: 45, 50, 55, 60 → mean=52.5
      // T2: 30, 35, 40, 45 → mean=37.5
      // T3: 20, 25, 30, 35 → mean=27.5
      // Grand mean = 39.17
      final result = computeOneWayAnova({
        'T1': [45, 50, 55, 60],
        'T2': [30, 35, 40, 45],
        'T3': [20, 25, 30, 35],
      });

      expect(result, isNotNull);
      expect(result!.model, 'CRD');
      expect(result.totalN, 12);
      expect(result.sourceRows.length, 3); // Treatment, Error, Total

      // Treatment df = 2, Error df = 9, Total df = 11
      expect(result.sourceRows[0].df, 2); // Treatment
      expect(result.sourceRows[1].df, 9); // Error
      expect(result.sourceRows[2].df, 11); // Total

      // F should be significant (large separation between means)
      expect(result.treatmentF, greaterThan(1));
      expect(result.treatmentPValue, lessThan(0.05));
      expect(result.isSignificant, true);

      // LSD should exist
      expect(result.lsd, isNotNull);
      expect(result.lsd!, greaterThan(0));

      // Letters: T1 should be 'a' (highest), T3 should differ
      expect(result.treatmentMeansWithLetters.length, 3);
      expect(result.treatmentMeansWithLetters[0].treatmentCode, 'T1');
      expect(result.treatmentMeansWithLetters[2].treatmentCode, 'T3');
    });

    test('2 identical treatments → not significant', () {
      final result = computeOneWayAnova({
        'A': [10, 10, 10, 10],
        'B': [10, 10, 10, 10],
      });
      expect(result, isNotNull);
      // F = 0 when means are identical, MSE = 0 → special case
      // Actually both SS_treatment and SS_error are 0
    });

    test('2 treatments with clear difference', () {
      final result = computeOneWayAnova({
        'High': [80, 85, 90, 95],
        'Low': [20, 25, 30, 35],
      });
      expect(result, isNotNull);
      expect(result!.treatmentPValue, lessThan(0.001));
      expect(result.significance, SignificanceLevel.highlySignificant);
      // Letters should differ
      expect(result.treatmentMeansWithLetters[0].letter, 'a');
      expect(result.treatmentMeansWithLetters[1].letter, 'b');
    });

    test('treatments with no significant difference → same letter', () {
      // Very similar means with high variance
      final result = computeOneWayAnova({
        'A': [40, 60, 50, 30],
        'B': [45, 55, 50, 35],
      });
      expect(result, isNotNull);
      expect(result!.treatmentPValue, greaterThan(0.05));
      expect(result.isSignificant, false);
      // Both should share letter 'a' since not significantly different
      expect(result.treatmentMeansWithLetters[0].letter,
          result.treatmentMeansWithLetters[1].letter);
    });

    test('returns null for fewer than 2 treatments', () {
      expect(computeOneWayAnova({'A': [10, 20, 30]}), isNull);
    });

    test('returns null for insufficient data', () {
      expect(computeOneWayAnova({'A': [10], 'B': [20]}), isNull);
    });

    test('handles unbalanced design', () {
      final result = computeOneWayAnova({
        'A': [10, 20, 30, 40],
        'B': [50, 60],
        'C': [70, 80, 90],
      });
      expect(result, isNotNull);
      expect(result!.totalN, 9);
    });

    test('significance level classification', () {
      expect(classifyPValue(0.001), SignificanceLevel.highlySignificant);
      expect(classifyPValue(0.03), SignificanceLevel.significant);
      expect(classifyPValue(0.07), SignificanceLevel.marginallysignificant);
      expect(classifyPValue(0.15), SignificanceLevel.notSignificant);
    });
  });

  group('computeRcbdAnova', () {
    test('basic RCBD — 3 treatments, 4 reps', () {
      // Treatment means clearly separated.
      final result = computeRcbdAnova({
        'T1': {1: 50, 2: 55, 3: 48, 4: 52},
        'T2': {1: 35, 2: 40, 3: 33, 4: 37},
        'T3': {1: 22, 2: 27, 3: 20, 4: 25},
      });

      expect(result, isNotNull);
      expect(result!.model, 'RCBD');
      expect(result.totalN, 12);

      // RCBD ANOVA table has 4 rows: Treatment, Rep, Error, Total
      expect(result.sourceRows.length, 4);
      expect(result.sourceRows[0].source, 'Treatment');
      expect(result.sourceRows[1].source, 'Rep (Block)');
      expect(result.sourceRows[2].source, 'Error');
      expect(result.sourceRows[3].source, 'Total');

      // df: Treatment=2, Rep=3, Error=6, Total=11
      expect(result.sourceRows[0].df, 2);
      expect(result.sourceRows[1].df, 3);
      expect(result.sourceRows[2].df, 6);
      expect(result.sourceRows[3].df, 11);

      // Should be highly significant
      expect(result.treatmentPValue, lessThan(0.01));
      expect(result.lsd, isNotNull);
      expect(result.treatmentMeansWithLetters.length, 3);
    });

    test('RCBD with no treatment effect → not significant', () {
      // Treatments vary around similar means with noise; rep effect present.
      final result = computeRcbdAnova({
        'A': {1: 12, 2: 22, 3: 28, 4: 38},
        'B': {1: 10, 2: 24, 3: 32, 4: 36},
        'C': {1: 14, 2: 18, 3: 30, 4: 42},
      });

      expect(result, isNotNull);
      expect(result!.treatmentPValue, greaterThan(0.05));
      expect(result.isSignificant, false);
    });

    test('falls back to one-way when unbalanced', () {
      // T1 missing rep 3
      final result = computeRcbdAnova({
        'T1': {1: 50, 2: 55, 4: 52},
        'T2': {1: 35, 2: 40, 3: 33, 4: 37},
      });

      expect(result, isNotNull);
      expect(result!.model, 'CRD'); // fell back to one-way
    });

    test('returns null for fewer than 2 treatments', () {
      expect(computeRcbdAnova({'A': {1: 10, 2: 20}}), isNull);
    });

    test('returns null for fewer than 2 reps', () {
      expect(computeRcbdAnova({'A': {1: 10}, 'B': {1: 20}}), isNull);
    });
  });

  group('significance letters', () {
    test('3 clearly separated treatments get distinct letters', () {
      final result = computeOneWayAnova({
        'A': [90, 92, 88, 91],
        'B': [50, 52, 48, 51],
        'C': [10, 12, 8, 11],
      });
      expect(result, isNotNull);
      final letters =
          result!.treatmentMeansWithLetters.map((m) => m.letter).toList();
      // All different: a, b, c
      expect(letters.toSet().length, 3);
    });

    test('2 similar + 1 different → shared letter', () {
      // A and B are close, C is far.
      final result = computeOneWayAnova({
        'A': [80, 82, 78, 81],
        'B': [78, 80, 76, 79],
        'C': [40, 42, 38, 41],
      });
      expect(result, isNotNull);
      // A and B should share a letter, C should be different
      final m = result!.treatmentMeansWithLetters;
      expect(m[0].letter.contains('a'), true); // A highest
      expect(m[1].letter.contains('a'), true); // B shares with A
      expect(m[2].letter.contains('a'), false); // C is different from A
    });
  });

  group('AnovaResult helpers', () {
    test('significanceLevelLabel covers all cases', () {
      expect(significanceLevelLabel(SignificanceLevel.highlySignificant),
          contains('0.01'));
      expect(significanceLevelLabel(SignificanceLevel.significant),
          contains('0.05'));
      expect(significanceLevelLabel(SignificanceLevel.marginallysignificant),
          contains('0.10'));
      expect(significanceLevelLabel(SignificanceLevel.notSignificant),
          contains('Not'));
    });
  });
}
