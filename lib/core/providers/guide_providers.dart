import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../data/repositories/assessment_guide_repository.dart';
import 'infrastructure_providers.dart';

final assessmentGuideRepositoryProvider =
    Provider<AssessmentGuideRepository>((ref) {
  return AssessmentGuideRepository(ref.watch(databaseProvider));
});

/// True when any non-deleted guide anchor exists for this trial assessment
/// (any lane). Drives the info icon visibility on the rating screen.
/// Param: (trialAssessmentId, assessmentDefinitionId?)
final hasGuideForAssessmentProvider =
    StreamProvider.family<bool, (int, int?)>((ref, params) {
  return ref.watch(assessmentGuideRepositoryProvider).watchHasAnyGuide(
        trialAssessmentId: params.$1,
        assessmentDefinitionId: params.$2,
      );
});

/// All non-deleted Lane 3 (customer_upload) anchors for a trial assessment.
/// Used in the coordinator's guide management sheet.
final customerAnchorsForTrialAssessmentProvider =
    StreamProvider.family<List<AssessmentGuideAnchor>, int>((ref, trialAssessmentId) {
  return ref
      .watch(assessmentGuideRepositoryProvider)
      .watchCustomerAnchors(trialAssessmentId);
});
