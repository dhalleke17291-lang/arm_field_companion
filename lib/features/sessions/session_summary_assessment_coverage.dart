import '../../core/database/app_database.dart';
import '../../domain/ratings/result_status.dart';

/// Per-assessment RECORDED coverage across target plots (non-guard) for session summary.
class SessionAssessmentCoverageRow {
  const SessionAssessmentCoverageRow({
    required this.assessmentId,
    required this.assessmentName,
    required this.recordedCount,
    required this.targetPlotCount,
  });

  final int assessmentId;
  final String assessmentName;
  final int recordedCount;
  final int targetPlotCount;

  bool get isIncomplete =>
      targetPlotCount > 0 && recordedCount < targetPlotCount;

  double get progressFraction => targetPlotCount <= 0
      ? 1.0
      : (recordedCount / targetPlotCount).clamp(0.0, 1.0);
}

/// Counts target plots with a **current** rating row for each session assessment
/// where [RatingRecord.resultStatus] is [ResultStatusDb.recorded].
///
/// [plotsForTrial] must match [PlotRepository.getPlotsForTrial] (non-deleted rows).
List<SessionAssessmentCoverageRow> computeSessionSummaryAssessmentCoverage({
  required List<Plot> plotsForTrial,
  required List<Assessment> sessionAssessments,
  required List<RatingRecord> currentSessionRatings,
}) {
  final targetPlots = plotsForTrial.where((p) => !p.isGuardRow).toList();
  final targetIds = targetPlots.map((p) => p.id).toSet();
  if (targetIds.isEmpty || sessionAssessments.isEmpty) {
    return sessionAssessments
        .map(
          (a) => SessionAssessmentCoverageRow(
            assessmentId: a.id,
            assessmentName: a.name,
            recordedCount: 0,
            targetPlotCount: targetPlots.length,
          ),
        )
        .toList();
  }

  final sessionAssessmentIds =
      sessionAssessments.map((a) => a.id).toSet();
  final recordedPlotIdsByAssessment = <int, Set<int>>{
    for (final a in sessionAssessments) a.id: <int>{},
  };

  for (final r in currentSessionRatings) {
    if (!sessionAssessmentIds.contains(r.assessmentId)) continue;
    if (!targetIds.contains(r.plotPk)) continue;
    if (r.resultStatus != ResultStatusDb.recorded) continue;
    recordedPlotIdsByAssessment[r.assessmentId]!.add(r.plotPk);
  }

  return sessionAssessments
      .map(
        (a) => SessionAssessmentCoverageRow(
          assessmentId: a.id,
          assessmentName: a.name,
          recordedCount: recordedPlotIdsByAssessment[a.id]!.length,
          targetPlotCount: targetPlots.length,
        ),
      )
      .toList();
}
