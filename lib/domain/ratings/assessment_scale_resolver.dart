import '../../core/database/app_database.dart';

/// Resolved numeric scale after applying definition vs assessment precedence.
class AssessmentScale {
  const AssessmentScale({this.minValue, this.maxValue});

  final double? minValue;
  final double? maxValue;
}

/// Optional ARM definition bounds keyed from [RatingScreen.scaleMap].
typedef AssessmentDefinitionScale = ({double? scaleMin, double? scaleMax});

/// Phase-1 policy: prefer definition scale, then [Assessment] row.
///
/// Does not apply UI defaults (e.g. 0 / unit cap); callers add those for entry + validation.
AssessmentScale resolveAssessmentScale({
  required Assessment assessment,
  AssessmentDefinitionScale? definitionScale,
}) {
  return AssessmentScale(
    minValue: definitionScale?.scaleMin ?? assessment.minValue,
    maxValue: definitionScale?.scaleMax ?? assessment.maxValue,
  );
}

/// Unit-aware default max when [Assessment.maxValue] is null (e.g. plant height cm cap 350).
int defaultNumericMaxForAssessmentUnit(String? unit) {
  switch (unit?.toLowerCase().trim()) {
    case 'cm':
      return 350;
    case 'm':
      return 4;
    case '%':
      return 100;
    case 'kg/ha':
      return 20000;
    case 'plants/plot':
      return 999;
    default:
      return 999;
  }
}

/// Bounds for clamping and validation (definition scale + assessment row + UI defaults).
({double min, double max}) resolvedNumericBoundsForAssessment(
  Assessment assessment,
  AssessmentDefinitionScale? definitionScale,
) {
  final resolved = resolveAssessmentScale(
    assessment: assessment,
    definitionScale: definitionScale,
  );
  return (
    min: resolved.minValue ?? 0.0,
    max: resolved.maxValue ??
        defaultNumericMaxForAssessmentUnit(assessment.unit).toDouble(),
  );
}
