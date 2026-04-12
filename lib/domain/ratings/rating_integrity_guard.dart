import '../../data/repositories/treatment_repository.dart';
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

/// Referential checks for plot assignment writes (plot and treatment must match trial).
abstract interface class AssignmentIntegrityChecks {
  Future<void> assertPlotBelongsToTrial({
    required int plotPk,
    required int trialId,
  });

  Future<void> assertTreatmentBelongsToTrial({
    required int treatmentId,
    required int trialId,
  });
}

/// App-layer referential integrity for rating writes (SQLite FKs + soft-delete gaps).
class RatingIntegrityGuard
    implements RatingReferentialIntegrity, AssignmentIntegrityChecks {
  RatingIntegrityGuard(
    this._plotRepository,
    this._sessionRepository,
    this._treatmentRepository,
  );

  final PlotRepository _plotRepository;
  final SessionRepository _sessionRepository;
  final TreatmentRepository _treatmentRepository;

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

  @override
  Future<void> assertTreatmentBelongsToTrial({
    required int treatmentId,
    required int trialId,
  }) async {
    final t =
        await _treatmentRepository.getTreatmentForTrial(treatmentId, trialId);
    if (t == null) {
      throw RatingIntegrityException(
        'Treatment $treatmentId does not exist, has been deleted, or does not belong to trial $trialId.',
        code: 'treatment_not_found_wrong_trial_or_deleted',
      );
    }
  }
}
