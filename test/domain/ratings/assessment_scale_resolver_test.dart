import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/ratings/assessment_scale_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Assessment _assessment({double? minValue, double? maxValue}) {
  return Assessment(
    id: 1,
    trialId: 1,
    name: 'A',
    dataType: 'numeric',
    minValue: minValue,
    maxValue: maxValue,
    unit: null,
    isActive: true,
  );
}

void main() {
  group('resolveAssessmentScale', () {
    test('definition scale wins when present', () {
      final r = resolveAssessmentScale(
        assessment: _assessment(minValue: 0, maxValue: 100),
        definitionScale: (scaleMin: 10, scaleMax: 50),
      );
      expect(r.minValue, 10);
      expect(r.maxValue, 50);
    });

    test('falls back to assessment when definition null fields', () {
      final r = resolveAssessmentScale(
        assessment: _assessment(minValue: 2, maxValue: 8),
        definitionScale: (scaleMin: null, scaleMax: null),
      );
      expect(r.minValue, 2);
      expect(r.maxValue, 8);
    });

    test('falls back to assessment when no definition scale', () {
      final r = resolveAssessmentScale(
        assessment: _assessment(minValue: 1, maxValue: 9),
        definitionScale: null,
      );
      expect(r.minValue, 1);
      expect(r.maxValue, 9);
    });

    test('partial definition: min from definition, max from assessment', () {
      final r = resolveAssessmentScale(
        assessment: _assessment(minValue: 0, maxValue: 99),
        definitionScale: (scaleMin: 5, scaleMax: null),
      );
      expect(r.minValue, 5);
      expect(r.maxValue, 99);
    });
  });
}
