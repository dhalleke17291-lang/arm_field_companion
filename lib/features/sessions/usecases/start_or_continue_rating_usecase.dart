import '../../../core/database/app_database.dart';
import '../../../core/plot_sort.dart';
import '../../trials/trial_repository.dart';
import '../../plots/plot_repository.dart';
import '../session_repository.dart';
import '../../ratings/rating_repository.dart';

/// Input for starting or continuing a rating session.
class StartOrContinueRatingInput {
  final int sessionId;
  /// Walk order for plot navigation. Defaults to [WalkOrderMode.serpentine] if null.
  final WalkOrderMode? walkOrderMode;
  /// When [walkOrderMode] is [WalkOrderMode.custom], use this ordered list of plot PKs; otherwise ignored.
  final List<int>? customPlotIds;

  const StartOrContinueRatingInput({
    required this.sessionId,
    this.walkOrderMode,
    this.customPlotIds,
  });
}

/// Result DTO for starting or continuing rating.
///
/// This is deliberately UI-agnostic: widgets can decide whether to
/// show navigation-end messaging or jump into the [RatingScreen].
class StartOrContinueRatingResult {
  final bool success;
  final Trial? trial;
  final Session? session;
  final List<Plot>? allPlotsSerpentine;
  final List<Assessment>? assessments;
  final int? startPlotIndex;

  /// True when the **last plot in the current walk order** has at least one
  /// **current** rating in this session (any assessment). This is **walk /
  /// navigation** progress only—not scientific completeness or session close.
  final bool isWalkEndReachedWithAnyRating;
  final String? errorMessage;

  const StartOrContinueRatingResult._({
    required this.success,
    this.trial,
    this.session,
    this.allPlotsSerpentine,
    this.assessments,
    this.startPlotIndex,
    required this.isWalkEndReachedWithAnyRating,
    this.errorMessage,
  });

  factory StartOrContinueRatingResult.success({
    required Trial trial,
    required Session session,
    required List<Plot> allPlotsSerpentine,
    required List<Assessment> assessments,
    required int startPlotIndex,
    required bool isWalkEndReachedWithAnyRating,
  }) {
    return StartOrContinueRatingResult._(
      success: true,
      trial: trial,
      session: session,
      allPlotsSerpentine: allPlotsSerpentine,
      assessments: assessments,
      startPlotIndex: startPlotIndex,
      isWalkEndReachedWithAnyRating: isWalkEndReachedWithAnyRating,
    );
  }

  factory StartOrContinueRatingResult.failure(String message) {
    return StartOrContinueRatingResult._(
      success: false,
      isWalkEndReachedWithAnyRating: false,
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
/// - If the last plot in walk order has any current rating, set
///   [StartOrContinueRatingResult.isWalkEndReachedWithAnyRating] and point
///   [StartOrContinueRatingResult.startPlotIndex] at the last plot (so UI can
///   still open a review view). This is not scientific/session completeness.
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
      final session = await _sessionRepository.getSessionById(input.sessionId);
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

      final mode = input.walkOrderMode ?? WalkOrderMode.serpentine;
      final orderedPlots = sortPlotsByWalkOrder(
        plots,
        mode,
        customPlotIds: input.customPlotIds,
      );

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

      // Find the last-rated plot in walk order, if any.
      var lastRatedIndex = -1;
      for (var i = 0; i < orderedPlots.length; i++) {
        if (ratedPlotPks.contains(orderedPlots[i].id)) {
          lastRatedIndex = i;
        }
      }

      final bool walkEndReachedWithAnyRating;
      final int startIndex;

      if (lastRatedIndex == -1) {
        walkEndReachedWithAnyRating = false;
        startIndex = 0;
      } else if (lastRatedIndex >= orderedPlots.length - 1) {
        walkEndReachedWithAnyRating = true;
        startIndex = orderedPlots.length - 1;
      } else {
        walkEndReachedWithAnyRating = false;
        startIndex = lastRatedIndex + 1;
      }

      return StartOrContinueRatingResult.success(
        trial: trial,
        session: session,
        allPlotsSerpentine: orderedPlots,
        assessments: assessments,
        startPlotIndex: startIndex,
        isWalkEndReachedWithAnyRating: walkEndReachedWithAnyRating,
      );
    } catch (e) {
      return StartOrContinueRatingResult.failure(
          'Failed to resolve rating entry: $e');
    }
  }
}
