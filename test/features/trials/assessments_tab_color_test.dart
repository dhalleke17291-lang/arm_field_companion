import 'package:arm_field_companion/core/assessment_result_direction.dart';
import 'package:arm_field_companion/core/design/app_design_tokens.dart';
import 'package:arm_field_companion/features/derived/domain/trial_statistics.dart';
import 'package:arm_field_companion/features/trials/tabs/assessments_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentsTab.checkPctColor CV suppression', () {
    test('CV below threshold → direction-aware color (higherIsBetter, positive delta)', () {
      final color = AssessmentsTab.checkPctColor(
        10.0,
        ResultDirection.higherIsBetter,
        cv: 49.9,
      );
      expect(color, AppDesignTokens.successFg);
    });

    test('CV at threshold exactly → suppressed (boundary inclusive, >=)', () {
      final color = AssessmentsTab.checkPctColor(
        10.0,
        ResultDirection.higherIsBetter,
        cv: kHighCvDeltaColorSuppressionThreshold,
      );
      expect(color, AppDesignTokens.secondaryText);
    });

    test('CV above threshold → suppressed', () {
      final color = AssessmentsTab.checkPctColor(
        10.0,
        ResultDirection.higherIsBetter,
        cv: 50.1,
      );
      expect(color, AppDesignTokens.secondaryText);
    });

    test('CV null → suppressed (unknown CV defaults to suppression)', () {
      final color = AssessmentsTab.checkPctColor(
        10.0,
        ResultDirection.higherIsBetter,
        cv: null,
      );
      expect(color, AppDesignTokens.secondaryText);
    });

    test('CV below threshold, negative delta, higherIsBetter → missedColor', () {
      final color = AssessmentsTab.checkPctColor(
        -15.0,
        ResultDirection.higherIsBetter,
        cv: 30.0,
      );
      expect(color, AppDesignTokens.missedColor);
    });

    test('CV below threshold, negative delta, lowerIsBetter → successFg', () {
      final color = AssessmentsTab.checkPctColor(
        -15.0,
        ResultDirection.lowerIsBetter,
        cv: 30.0,
      );
      expect(color, AppDesignTokens.successFg);
    });

    test('CV below threshold, neutral direction → secondaryText regardless of delta', () {
      final color = AssessmentsTab.checkPctColor(
        50.0,
        ResultDirection.neutral,
        cv: 30.0,
      );
      expect(color, AppDesignTokens.secondaryText);
    });

    test('CV below threshold, delta = 0, higherIsBetter → successFg (0 satisfies >= 0)', () {
      final color = AssessmentsTab.checkPctColor(
        0.0,
        ResultDirection.higherIsBetter,
        cv: 30.0,
      );
      expect(color, AppDesignTokens.successFg);
    });
  });
}
