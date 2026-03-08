import '../../../core/database/app_database.dart';
import '../../../core/trial_state.dart';
import '../plot_repository.dart';

/// Updates plot treatment assignment(s). Respects protocol lock (no edits when trial is active/closed/archived).
class UpdatePlotAssignmentUseCase {
  final PlotRepository _plotRepository;

  UpdatePlotAssignmentUseCase(this._plotRepository);

  /// Update a single plot's treatment assignment (manual).
  /// Sets assignmentSource = manual, assignmentUpdatedAt = now.
  /// Returns [UpdateAssignmentResult.failure] if protocol is locked.
  Future<UpdateAssignmentResult> updateOne({
    required Trial trial,
    required int plotPk,
    required int? treatmentId,
  }) async {
    if (isProtocolLocked(trial.status)) {
      return UpdateAssignmentResult.failure(getProtocolLockMessage(trial.status));
    }
    try {
      await _plotRepository.updatePlotTreatment(
        plotPk,
        treatmentId,
        assignmentSource: 'manual',
        assignmentUpdatedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
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
    if (isProtocolLocked(trial.status)) {
      return UpdateAssignmentResult.failure(getProtocolLockMessage(trial.status));
    }
    if (plotPkToTreatmentId.isEmpty) {
      return UpdateAssignmentResult.success();
    }
    try {
      await _plotRepository.updatePlotsTreatmentsBulk(
        plotPkToTreatmentId,
        assignmentSource: 'manual',
        assignmentUpdatedAt: DateTime.now().toUtc(),
      );
      return UpdateAssignmentResult.success();
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
