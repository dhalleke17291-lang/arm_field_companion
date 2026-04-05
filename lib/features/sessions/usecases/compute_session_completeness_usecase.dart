import '../../../domain/ratings/result_status.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../domain/session_completeness_report.dart';
import '../session_repository.dart';

/// Builds a [SessionCompletenessReport] for close gating using repository APIs only.
class ComputeSessionCompletenessUseCase {
  ComputeSessionCompletenessUseCase(
    this._sessionRepository,
    this._plotRepository,
    this._ratingRepository,
  );

  final SessionRepository _sessionRepository;
  final PlotRepository _plotRepository;
  final RatingRepository _ratingRepository;

  /// Loads session, trial plots, session assessments, and current session ratings.
  Future<SessionCompletenessReport> execute({required int sessionId}) async {
    final session = await _sessionRepository.getSessionById(sessionId);
    if (session == null) {
      return const SessionCompletenessReport(
        expectedPlots: 0,
        completedPlots: 0,
        incompletePlots: 0,
        issues: [
          SessionCompletenessIssue(
            severity: SessionCompletenessIssueSeverity.blocker,
            code: SessionCompletenessIssueCode.sessionNotFound,
          ),
        ],
        canClose: false,
      );
    }

    final assessments =
        await _sessionRepository.getSessionAssessments(sessionId);
    if (assessments.isEmpty) {
      final plots = await _plotRepository.getPlotsForTrial(session.trialId);
      final targetPlots = plots.where((p) => !p.isGuardRow).toList();
      final expected = targetPlots.length;
      return SessionCompletenessReport(
        expectedPlots: expected,
        completedPlots: 0,
        incompletePlots: expected,
        issues: const [
          SessionCompletenessIssue(
            severity: SessionCompletenessIssueSeverity.blocker,
            code: SessionCompletenessIssueCode.noSessionAssessments,
          ),
        ],
        canClose: false,
      );
    }

    final plots = await _plotRepository.getPlotsForTrial(session.trialId);
    final targetPlots = plots.where((p) => !p.isGuardRow).toList();
    final expectedPlots = targetPlots.length;

    final ratings =
        await _ratingRepository.getCurrentRatingsForSession(sessionId);
    final assessmentIds = assessments.map((a) => a.id).toSet();

    final byPlotAndAssessment = <String, String>{};
    for (final r in ratings) {
      if (!assessmentIds.contains(r.assessmentId)) continue;
      final key = '${r.plotPk}_${r.assessmentId}';
      byPlotAndAssessment[key] = r.resultStatus;
    }

    final issues = <SessionCompletenessIssue>[];
    var completedPlots = 0;

    for (final plot in targetPlots) {
      var plotComplete = true;

      for (final assessment in assessments) {
        final key = '${plot.id}_${assessment.id}';
        final status = byPlotAndAssessment[key];

        if (status == null) {
          plotComplete = false;
          issues.add(SessionCompletenessIssue(
            severity: SessionCompletenessIssueSeverity.blocker,
            code: SessionCompletenessIssueCode.missingCurrentRating,
            plotPk: plot.id,
            assessmentId: assessment.id,
          ));
          continue;
        }

        if (status == ResultStatusDb.voided) {
          plotComplete = false;
          issues.add(SessionCompletenessIssue(
            severity: SessionCompletenessIssueSeverity.blocker,
            code: SessionCompletenessIssueCode.voidRating,
            plotPk: plot.id,
            assessmentId: assessment.id,
          ));
          continue;
        }

        if (status != ResultStatusDb.recorded) {
          issues.add(SessionCompletenessIssue(
            severity: SessionCompletenessIssueSeverity.warning,
            code: SessionCompletenessIssueCode.nonRecordedStatus,
            plotPk: plot.id,
            assessmentId: assessment.id,
          ));
        }
      }

      if (plotComplete) {
        completedPlots++;
      }
    }

    final incompletePlots = expectedPlots - completedPlots;
    final canClose =
        !issues.any((i) => i.severity == SessionCompletenessIssueSeverity.blocker);

    return SessionCompletenessReport(
      expectedPlots: expectedPlots,
      completedPlots: completedPlots,
      incompletePlots: incompletePlots,
      issues: issues,
      canClose: canClose,
    );
  }
}
