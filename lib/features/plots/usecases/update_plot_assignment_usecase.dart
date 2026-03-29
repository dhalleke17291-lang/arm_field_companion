import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../sessions/session_repository.dart';

/// Updates plot treatment assignment(s) via Assignments table.
/// Respects protocol lock and assignments lock (trial has session data).
class UpdatePlotAssignmentUseCase {
  final AssignmentRepository _assignmentRepository;
  final SessionRepository _sessionRepository;

  UpdatePlotAssignmentUseCase(
      this._assignmentRepository, this._sessionRepository);

  /// Update a single plot's treatment assignment (manual).
  /// Sets assignmentSource = manual, assignmentUpdatedAt = now.
  /// Returns [UpdateAssignmentResult.failure] if assignments are locked.
  Future<UpdateAssignmentResult> updateOne({
    required Trial trial,
    required int plotPk,
    required int? treatmentId,
  }) async {
    if (!canEditProtocol(trial)) {
      return UpdateAssignmentResult.failure(protocolEditBlockedMessage(trial));
    }
    final sessions = await _sessionRepository.getSessionsForTrial(trial.id);
    if (isAssignmentsLocked(trial.status, sessions.isNotEmpty)) {
      return UpdateAssignmentResult.failure(
          getAssignmentsLockMessage(trial.status, sessions.isNotEmpty));
    }
    try {
      await _assignmentRepository.upsert(
        trialId: trial.id,
        plotId: plotPk,
        treatmentId: treatmentId,
        assignmentSource: 'manual',
        assignedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
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
    if (!canEditProtocol(trial)) {
      return UpdateAssignmentResult.failure(protocolEditBlockedMessage(trial));
    }
    final sessions = await _sessionRepository.getSessionsForTrial(trial.id);
    if (isAssignmentsLocked(trial.status, sessions.isNotEmpty)) {
      return UpdateAssignmentResult.failure(
          getAssignmentsLockMessage(trial.status, sessions.isNotEmpty));
    }
    if (plotPkToTreatmentId.isEmpty) {
      return UpdateAssignmentResult.success();
    }
    try {
      await _assignmentRepository.upsertBulk(
        trialId: trial.id,
        plotPkToTreatmentId: plotPkToTreatmentId,
        assignmentSource: 'manual',
        assignedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
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
