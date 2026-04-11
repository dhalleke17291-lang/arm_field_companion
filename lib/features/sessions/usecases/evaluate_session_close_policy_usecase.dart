import '../../../core/database/app_database.dart';
import '../../../core/plot_analysis_eligibility.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../domain/session_close_attention_summary.dart';
import '../domain/session_close_policy_result.dart';
import '../domain/session_completeness_report.dart';
import 'compute_session_completeness_usecase.dart';

/// Orchestrates completeness + legacy attention signals for session close (UI-free).
class EvaluateSessionClosePolicyUseCase {
  EvaluateSessionClosePolicyUseCase(
    this._computeSessionCompleteness,
    this._plotRepository,
    this._ratingRepository,
  );

  final ComputeSessionCompletenessUseCase _computeSessionCompleteness;
  final PlotRepository _plotRepository;
  final RatingRepository _ratingRepository;

  Future<SessionClosePolicyResult> execute({
    required int sessionId,
    required int trialId,
  }) async {
    final completenessReport =
        await _computeSessionCompleteness.execute(sessionId: sessionId);

    final plots = await _plotRepository.getPlotsForTrial(trialId);
    final ratedPks = await _ratingRepository.getRatedPlotPksForSession(sessionId);
    final flaggedIds =
        await _plotRepository.getFlaggedPlotPksForSession(sessionId);
    final ratings =
        await _ratingRepository.getCurrentRatingsForSession(sessionId);
    final corrections =
        await _ratingRepository.getPlotPksWithCorrectionsForSession(sessionId);

    final attentionSummary = _computeSessionCloseAttentionSummary(
      plots: plots,
      ratedPks: ratedPks,
      flaggedIds: flaggedIds,
      ratings: ratings,
      corrections: corrections,
    );

    final hasCompletenessWarnings = completenessReport.issues.any(
      (i) => i.severity == SessionCompletenessIssueSeverity.warning,
    );

    final SessionClosePolicyDecision decision;
    if (!completenessReport.canClose) {
      decision = SessionClosePolicyDecision.blocked;
    } else if (hasCompletenessWarnings || attentionSummary.needsAttention) {
      decision = SessionClosePolicyDecision.warnBeforeClose;
    } else {
      decision = SessionClosePolicyDecision.proceedToClose;
    }

    return SessionClosePolicyResult(
      decision: decision,
      completenessReport: completenessReport,
      attentionSummary: attentionSummary,
    );
  }
}

/// Matches plot-queue / session summary semantics for pre-close warning only.
/// Uses [isAnalyzablePlot] (non-guard, not excluded from analysis).
SessionCloseAttentionSummary _computeSessionCloseAttentionSummary({
  required List<Plot> plots,
  required Set<int> ratedPks,
  required Set<int> flaggedIds,
  required List<RatingRecord> ratings,
  required Set<int> corrections,
}) {
  final targetPlots = plots.where(isAnalyzablePlot).toList();
  final targetPlotPkSet = targetPlots.map((p) => p.id).toSet();

  final totalPlots = targetPlots.length;
  final ratedPlots =
      targetPlots.where((p) => ratedPks.contains(p.id)).length;
  final unratedPlots =
      targetPlots.where((p) => !ratedPks.contains(p.id)).length;
  final flaggedPlots =
      flaggedIds.where(targetPlotPkSet.contains).length;
  final ratingsByPlot = <int, List<RatingRecord>>{};
  for (final r in ratings) {
    ratingsByPlot.putIfAbsent(r.plotPk, () => []).add(r);
  }
  var issuesPlots = 0;
  var editedPlots = 0;
  for (final plot in targetPlots) {
    final pr = ratingsByPlot[plot.id] ?? [];
    if (pr.any((r) => r.resultStatus != 'RECORDED')) {
      issuesPlots++;
    }
    if (pr.any((r) => r.amended || (r.previousId != null)) ||
        corrections.contains(plot.id)) {
      editedPlots++;
    }
  }
  return SessionCloseAttentionSummary(
    totalPlots: totalPlots,
    ratedPlots: ratedPlots,
    unratedPlots: unratedPlots,
    flaggedPlots: flaggedPlots,
    issuesPlots: issuesPlots,
    editedPlots: editedPlots,
  );
}
