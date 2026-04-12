import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../../domain/ratings/rating_integrity_exception.dart';
import '../../../domain/ratings/rating_integrity_guard.dart';
import '../../sessions/session_repository.dart';

/// Updates plot treatment assignment(s) via Assignments table.
/// Respects protocol lock and assignments lock (trial has session data).
class UpdatePlotAssignmentUseCase {
  final AssignmentRepository _assignmentRepository;
  final SessionRepository _sessionRepository;
  final AssignmentIntegrityChecks _assignmentIntegrity;

  UpdatePlotAssignmentUseCase(
    this._assignmentRepository,
    this._sessionRepository,
    this._assignmentIntegrity,
  );

  /// Update a single plot's treatment assignment (manual).
  /// Sets assignmentSource = manual, assignmentUpdatedAt = now.
  /// Returns [UpdateAssignmentResult.failure] if assignments are locked.
  Future<UpdateAssignmentResult> updateOne({
    required Trial trial,
    required int plotPk,
    required int? treatmentId,
  }) async {
    final hasSessionData =
        await _sessionRepository.watchTrialHasSessionData(trial.id).first;
    if (!canEditTrialStructure(trial, hasSessionData: hasSessionData)) {
      return UpdateAssignmentResult.failure(
        structureEditBlockedMessage(trial, hasSessionData: hasSessionData),
      );
    }
    if (!canEditAssignmentsForTrial(trial, hasSessionData: hasSessionData)) {
      return UpdateAssignmentResult.failure(
        getAssignmentsLockMessage(trial.status, hasSessionData),
      );
    }
    try {
      await _assignmentIntegrity.assertPlotBelongsToTrial(
        plotPk: plotPk,
        trialId: trial.id,
      );
      if (treatmentId != null) {
        await _assignmentIntegrity.assertTreatmentBelongsToTrial(
          treatmentId: treatmentId,
          trialId: trial.id,
        );
      }
      await _assignmentRepository.upsert(
        trialId: trial.id,
        plotId: plotPk,
        treatmentId: treatmentId,
        assignmentSource: 'manual',
        assignedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
    } on RatingIntegrityException catch (e) {
      return UpdateAssignmentResult.failure(e.message);
    } on ProtocolEditBlockedException catch (e) {
      return UpdateAssignmentResult.failure(e.message);
    } catch (e) {
      return UpdateAssignmentResult.failure('Update failed: $e');
    }
  }

  /// Update multiple plots' treatment assignments in one transaction (manual).
  /// Sets assignmentSource = manual, assignmentUpdatedAt = now for each.
  Future<UpdateAssignmentResult> updateBulk({
    required Trial trial,
    required Map<int, int?> plotPkToTreatmentId,
  }) async {
    final hasSessionData =
        await _sessionRepository.watchTrialHasSessionData(trial.id).first;
    if (!canEditTrialStructure(trial, hasSessionData: hasSessionData)) {
      return UpdateAssignmentResult.failure(
        structureEditBlockedMessage(trial, hasSessionData: hasSessionData),
      );
    }
    if (!canEditAssignmentsForTrial(trial, hasSessionData: hasSessionData)) {
      return UpdateAssignmentResult.failure(
        getAssignmentsLockMessage(trial.status, hasSessionData),
      );
    }
    if (plotPkToTreatmentId.isEmpty) {
      return UpdateAssignmentResult.success();
    }
    try {
      for (final plotPk in plotPkToTreatmentId.keys) {
        await _assignmentIntegrity.assertPlotBelongsToTrial(
          plotPk: plotPk,
          trialId: trial.id,
        );
      }
      final treatmentIds = plotPkToTreatmentId.values
          .whereType<int>()
          .toSet();
      for (final tid in treatmentIds) {
        await _assignmentIntegrity.assertTreatmentBelongsToTrial(
          treatmentId: tid,
          trialId: trial.id,
        );
      }
      await _assignmentRepository.upsertBulk(
        trialId: trial.id,
        plotPkToTreatmentId: plotPkToTreatmentId,
        assignmentSource: 'manual',
        assignedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
    } on RatingIntegrityException catch (e) {
      return UpdateAssignmentResult.failure(e.message);
    } on ProtocolEditBlockedException catch (e) {
      return UpdateAssignmentResult.failure(e.message);
    } catch (e) {
      return UpdateAssignmentResult.failure('Update failed: $e');
    }
  }
}

class UpdateAssignmentResult {
  final bool success;
  final String? errorMessage;

  const UpdateAssignmentResult._({required this.success, this.errorMessage});

  factory UpdateAssignmentResult.success() =>
      const UpdateAssignmentResult._(success: true);

  factory UpdateAssignmentResult.failure(String message) =>
      UpdateAssignmentResult._(success: false, errorMessage: message);
}
