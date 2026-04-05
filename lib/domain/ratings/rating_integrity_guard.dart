import '../../features/plots/plot_repository.dart';
import '../../features/sessions/session_repository.dart';
import 'rating_integrity_exception.dart';

/// Contract for referential checks before rating persistence.
abstract interface class RatingReferentialIntegrity {
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  });

  Future<void> assertSessionBelongsToTrial({
    required int sessionId,
    required int trialId,
  });

  Future<void> assertAssessmentInSession({
    required int assessmentId,
    required int sessionId,
  });
}

/// App-layer referential integrity for rating writes (SQLite FKs + soft-delete gaps).
class RatingIntegrityGuard implements RatingReferentialIntegrity {
  RatingIntegrityGuard(this._plotRepository, this._sessionRepository);

  final PlotRepository _plotRepository;
  final SessionRepository _sessionRepository;

  @override
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  }) async {
    final plot = await _plotRepository.getPlotByPk(plotPk);
    if (plot == null) {
      throw RatingIntegrityException(
        'Plot $plotPk does not exist or has been deleted.',
        code: 'plot_not_found_or_deleted',
      );
    }
    if (plot.trialId != trialId) {
      throw RatingIntegrityException(
        'Plot $plotPk belongs to trial ${plot.trialId}, not trial $trialId.',
        code: 'plot_wrong_trial',
      );
    }
  }

  @override
  Future<void> assertSessionBelongsToTrial({
    required int sessionId,
    required int trialId,
  }) async {
    final session = await _sessionRepository.getSessionById(sessionId);
    if (session == null) {
      throw RatingIntegrityException(
        'Session $sessionId does not exist or has been deleted.',
        code: 'session_not_found_or_deleted',
      );
    }
    if (session.trialId != trialId) {
      throw RatingIntegrityException(
        'Session $sessionId belongs to trial ${session.trialId}, not trial $trialId.',
        code: 'session_wrong_trial',
      );
    }
  }

  @override
  Future<void> assertAssessmentInSession({
    required int assessmentId,
    required int sessionId,
  }) async {
    final ok = await _sessionRepository.isAssessmentInSession(
      assessmentId,
      sessionId,
    );
    if (!ok) {
      throw RatingIntegrityException(
        'Assessment $assessmentId is not part of session $sessionId.',
        code: 'assessment_not_in_session',
      );
    }
  }
}
