import '../../../core/database/app_database.dart';
import '../../../core/trial_state.dart';
import '../../../data/repositories/treatment_repository.dart';

/// Deletes a treatment and its components; clears plot/assignment references.
/// Respects protocol lock.
class DeleteTreatmentUseCase {
  final TreatmentRepository _repository;

  DeleteTreatmentUseCase(this._repository);

  Future<DeleteTreatmentResult> execute({
    required Trial trial,
    required int treatmentId,
  }) async {
    if (isProtocolLocked(trial.status)) {
      return DeleteTreatmentResult.failure(getProtocolLockMessage(trial.status));
    }
    try {
      await _repository.deleteTreatment(treatmentId);
      return DeleteTreatmentResult.success();
    } on TreatmentNotFoundException {
      return DeleteTreatmentResult.failure('Treatment not found.');
    } catch (e) {
      return DeleteTreatmentResult.failure('Delete failed: $e');
    }
  }
}

class DeleteTreatmentResult {
  final bool success;
  final String? errorMessage;

  const DeleteTreatmentResult._({required this.success, this.errorMessage});

  factory DeleteTreatmentResult.success() =>
      const DeleteTreatmentResult._(success: true);

  factory DeleteTreatmentResult.failure(String message) =>
      DeleteTreatmentResult._(success: false, errorMessage: message);
}
