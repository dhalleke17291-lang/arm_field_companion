import '../../../core/database/app_database.dart';
import '../../../core/plot_sort.dart';
import '../../trials/trial_repository.dart';
import '../../plots/plot_repository.dart';
import '../session_repository.dart';
import '../../ratings/rating_repository.dart';

/// Input for starting or continuing a rating session.
class StartOrContinueRatingInput {
  final int sessionId;

  const StartOrContinueRatingInput({
    required this.sessionId,
  });
}

/// Result DTO for starting or continuing rating.
///
/// This is deliberately UI-agnostic: widgets can decide whether to
/// show a "session complete" banner or jump into the RatingScreen.
class StartOrContinueRatingResult {
  final bool success;
  final Trial? trial;
  final Session? session;
  final List<Plot>? allPlotsSerpentine;
  final List<Assessment>? assessments;
  final int? startPlotIndex;
  final bool isSessionComplete;
  final String? errorMessage;

  const StartOrContinueRatingResult._({
    required this.success,
    this.trial,
    this.session,
    this.allPlotsSerpentine,
    this.assessments,
    this.startPlotIndex,
    required this.isSessionComplete,
    this.errorMessage,
  });

  factory StartOrContinueRatingResult.success({
    required Trial trial,
    required Session session,
    required List<Plot> allPlotsSerpentine,
    required List<Assessment> assessments,
    required int startPlotIndex,
    required bool isSessionComplete,
  }) {
    return StartOrContinueRatingResult._(
      success: true,
      trial: trial,
      session: session,
      allPlotsSerpentine: allPlotsSerpentine,
      assessments: assessments,
      startPlotIndex: startPlotIndex,
      isSessionComplete: isSessionComplete,
    );
  }

  factory StartOrContinueRatingResult.failure(String message) {
    return StartOrContinueRatingResult._(
      success: false,
      isSessionComplete: false,
      errorMessage: message,
    );
  }
}

/// Use case that resolves the correct entry point into the rating flow
/// for a given session.
///
/// Responsibilities:
/// - Load Trial + Session for context.
/// - Load all plots for the trial and sort them in serpentine order.
/// - Load session assessments.
/// - Determine the "next" plot in serpentine order based on which plots
///   already have current ratings in the session.
///
/// Semantics:
/// - If no plots have ratings, start at the first plot in serpentine order.
/// - If some plots have ratings, resume at the plot immediately after the
///   last-rated plot in serpentine order.
/// - If all plots have ratings, mark the session as complete and point
///   startPlotIndex at the last plot (so UI can still open a review view).
class StartOrContinueRatingUseCase {
  final SessionRepository _sessionRepository;
  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final RatingRepository _ratingRepository;

  StartOrContinueRatingUseCase(
    this._sessionRepository,
    this._trialRepository,
    this._plotRepository,
    this._ratingRepository,
  );

  Future<StartOrContinueRatingResult> execute(
      StartOrContinueRatingInput input) async {
    try {
      final session =
          await _sessionRepository.getSessionById(input.sessionId);
      if (session == null) {
        return StartOrContinueRatingResult.failure('Session not found');
      }

      final trial = await _trialRepository.getTrialById(session.trialId);
      if (trial == null) {
        return StartOrContinueRatingResult.failure('Trial not found');
      }

      final plots = await _plotRepository.getPlotsForTrial(trial.id);
      if (plots.isEmpty) {
        return StartOrContinueRatingResult.failure(
            'No plots in this trial. Import plots before rating.');
      }

      // Serpentine walking order (grid-aware, with defined fallback).
      final serpentinePlots = sortPlotsSerpentine(plots);

      final assessments =
          await _sessionRepository.getSessionAssessments(session.id);
      if (assessments.isEmpty) {
        return StartOrContinueRatingResult.failure(
            'No assessments in this session.');
      }

      // Determine which plots have any current ratings in this session.
      final ratings =
          await _ratingRepository.getCurrentRatingsForSession(session.id);
      final ratedPlotPks = ratings.map((r) => r.plotPk).toSet();

      // Find the last-rated plot in serpentine order, if any.
      var lastRatedIndex = -1;
      for (var i = 0; i < serpentinePlots.length; i++) {
        if (ratedPlotPks.contains(serpentinePlots[i].id)) {
          lastRatedIndex = i;
        }
      }

      final bool allRated;
      final int startIndex;

      if (lastRatedIndex == -1) {
        // Nothing rated yet — start at the first serpentine plot.
        allRated = false;
        startIndex = 0;
      } else if (lastRatedIndex >= serpentinePlots.length - 1) {
        // All plots have at least one rating — session is complete.
        allRated = true;
        startIndex = serpentinePlots.length - 1;
      } else {
        // Resume at the plot after the last-rated plot in serpentine order.
        allRated = false;
        startIndex = lastRatedIndex + 1;
      }

      return StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: serpentinePlots,
        assessments: assessments,
        startPlotIndex: startIndex,
        isSessionComplete: allRated,
      );
    } catch (e) {
      return StartOrContinueRatingResult.failure(
          'Failed to resolve rating entry: $e');
    }
  }
}

