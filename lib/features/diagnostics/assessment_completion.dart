/// Per–trial-assessment rating coverage across **data** plots (non–guard rows).
///
/// [ratedPlotCount] and [analyzablePlotCount] reflect plots that count toward
/// analysis ([isAnalyzablePlot]). [totalDataPlots] is all non-guard rows;
/// [excludedFromAnalysisCount] is non-guard plots excluded from analysis.
///
/// [trialAssessmentId] is [TrialAssessment.id] when linked to the library.
/// Legacy-only assessments use **negative** `assessments.id` as the key (same
/// value as [trialAssessmentId] on the model).
class AssessmentCompletion {
  const AssessmentCompletion({
    required this.trialAssessmentId,
    required this.assessmentName,
    required this.ratedPlotCount,
    required this.analyzablePlotCount,
    required this.totalDataPlots,
    required this.excludedFromAnalysisCount,
  });

  final int trialAssessmentId;
  final String assessmentName;
  final int ratedPlotCount;
  /// Non-guard plots that count toward completion and statistics.
  final int analyzablePlotCount;
  /// All non-guard plots (denominator for “data plots” copy).
  final int totalDataPlots;
  /// Non-guard plots excluded from analysis (user or guard-adjacent rules).
  final int excludedFromAnalysisCount;

  bool get isComplete =>
      analyzablePlotCount <= 0 || ratedPlotCount >= analyzablePlotCount;

  double get progressFraction => analyzablePlotCount <= 0
      ? 1.0
      : (ratedPlotCount / analyzablePlotCount).clamp(0.0, 1.0);
}
