import 'package:arm_field_companion/core/ui/assessment_display_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatParenthetical', () {
    test('null → empty string', () {
      expect(AssessmentDisplayHelper.formatParenthetical(null), '');
    });

    test('empty string → empty string', () {
      expect(AssessmentDisplayHelper.formatParenthetical(''), '');
    });

    test('whitespace only → empty string', () {
      expect(AssessmentDisplayHelper.formatParenthetical('   '), '');
    });

    test('normal value → wrapped in parens with leading space', () {
      expect(AssessmentDisplayHelper.formatParenthetical('W003'), ' (W003)');
    });

    test('value with leading/trailing whitespace → trimmed inside parens', () {
      expect(
          AssessmentDisplayHelper.formatParenthetical('  W003  '), ' (W003)');
    });
  });

  group('compactName empty-parens cleanup', () {
    test('legacyAssessmentDisplayName strips trailing empty parens', () {
      expect(
        AssessmentDisplayHelper.legacyAssessmentDisplayName('CONTRO () — TA6'),
        'CONTRO',
      );
    });

    test('legacyAssessmentDisplayName strips bare empty parens', () {
      expect(
        AssessmentDisplayHelper.legacyAssessmentDisplayName('CONTRO()'),
        'CONTRO',
      );
    });

    test('legacyAssessmentDisplayName preserves non-empty parens', () {
      expect(
        AssessmentDisplayHelper.legacyAssessmentDisplayName('CONTRO (W003) — TA6'),
        'CONTRO (W003)',
      );
    });

    test('legacyAssessmentDisplayName handles name with only parens', () {
      expect(
        AssessmentDisplayHelper.legacyAssessmentDisplayName('()'),
        '()',
      );
    });
  });
}
