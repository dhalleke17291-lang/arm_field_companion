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
