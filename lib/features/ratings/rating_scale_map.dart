import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../domain/ratings/assessment_scale_resolver.dart';

/// Maps [Assessment.id] (legacy row) to definition scale via [TrialAssessment.legacyAssessmentId].
Map<int, AssessmentDefinitionScale> buildRatingScaleMap({
  required List<TrialAssessment> trialAssessments,
  required List<AssessmentDefinition> definitions,
  required int trialIdForLog,
}) {
  final defById = {for (final d in definitions) d.id: d};
  final result = <int, AssessmentDefinitionScale>{};
  for (final ta in trialAssessments) {
    final legacyId = ta.legacyAssessmentId;
    if (legacyId == null) continue;
    final def = defById[ta.assessmentDefinitionId];
    if (def == null) continue;
    if (result.containsKey(legacyId)) {
      debugPrint(
        'AssessmentScaleMap: duplicate legacyAssessmentId $legacyId '
        'in trial $trialIdForLog — keeping first, ignoring '
        'assessmentDefinitionId ${ta.assessmentDefinitionId}.',
      );
      continue;
    }
    result[legacyId] = (
      scaleMin: def.scaleMin,
      scaleMax: def.scaleMax,
    );
  }
  return result;
}
