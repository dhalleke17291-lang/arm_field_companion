import '../../../core/database/app_database.dart';
import '../../../core/protocol_edit_blocked_exception.dart';
import '../../../core/trial_state.dart';
import '../../../data/repositories/treatment_repository.dart';

/// Updates treatment code/name/description. Respects protocol lock.
class UpdateTreatmentUseCase {
  final TreatmentRepository _repository;

  UpdateTreatmentUseCase(this._repository);

  Future<UpdateTreatmentResult> execute({
    required Trial trial,
    required int treatmentId,
    required String code,
    required String name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
    int? performedByUserId,
  }) async {
    if (!canEditProtocol(trial)) {
      return UpdateTreatmentResult.failure(protocolEditBlockedMessage(trial));
    }
    final trimmedCode = code.trim();
    final trimmedName = name.trim();
    if (trimmedCode.isEmpty) {
      return UpdateTreatmentResult.failure('Code is required.');
    }
    if (trimmedName.isEmpty) {
      return UpdateTreatmentResult.failure('Name is required.');
    }
    try {
      await _repository.updateTreatment(
        treatmentId,
        code: trimmedCode,
        name: trimmedName,
        description: description?.trim(),
        treatmentType: treatmentType?.trim(),
        timingCode: timingCode?.trim(),
        eppoCode: eppoCode?.trim(),
        performedByUserId: performedByUserId,
      );
      return UpdateTreatmentResult.success();
    } on TreatmentNotFoundException {
      return UpdateTreatmentResult.failure('Treatment not found.');
    } on ProtocolEditBlockedException catch (e) {
      return UpdateTreatmentResult.failure(e.message);
    } catch (e) {
      return UpdateTreatmentResult.failure('Update failed: $e');
    }
  }
}

class UpdateTreatmentResult {
  final bool success;
  final String? errorMessage;

  const UpdateTreatmentResult._({required this.success, this.errorMessage});

  factory UpdateTreatmentResult.success() =>
      const UpdateTreatmentResult._(success: true);

  factory UpdateTreatmentResult.failure(String message) =>
      UpdateTreatmentResult._(success: false, errorMessage: message);
}
