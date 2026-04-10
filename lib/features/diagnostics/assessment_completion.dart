/// Per–trial-assessment rating coverage across **data** plots (non–guard rows).
///
/// [trialAssessmentId] is [TrialAssessment.id] when linked to the library.
/// Legacy-only assessments use **negative** `assessments.id` as the key (same
/// value as [trialAssessmentId] on the model).
class AssessmentCompletion {
  const AssessmentCompletion({
    required this.trialAssessmentId,
    required this.assessmentName,
    required this.ratedPlotCount,
    required this.totalDataPlots,
  });

  final int trialAssessmentId;
  final String assessmentName;
  final int ratedPlotCount;
  final int totalDataPlots;

  bool get isComplete =>
      totalDataPlots > 0 && ratedPlotCount >= totalDataPlots;

  double get progressFraction => totalDataPlots <= 0
      ? 1.0
      : (ratedPlotCount / totalDataPlots).clamp(0.0, 1.0);
}
