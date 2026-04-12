import '../session_repository.dart';
import '../../../core/database/app_database.dart';
import '../session_timing_helper.dart';

class CreateSessionUseCase {
  final SessionRepository _sessionRepository;
  /// When a new open session is created, promotes trial Ready → Active (lifecycle consistency).
  final Future<void> Function(int trialId) _promoteTrialToActiveIfReady;

  CreateSessionUseCase(
    this._sessionRepository, {
    required Future<void> Function(int trialId) promoteTrialToActiveIfReady,
  }) : _promoteTrialToActiveIfReady = promoteTrialToActiveIfReady;

  Future<CreateSessionResult> execute(CreateSessionInput input) async {
    try {
      // Validate assessment list not empty
      if (input.assessmentIds.isEmpty) {
        return CreateSessionResult.failure(
            'At least one assessment must be selected');
      }

      // Validate session name
      if (input.name.trim().isEmpty) {
        return CreateSessionResult.failure('Session name must not be empty');
      }

      if (input.cropStageBbchRaw != null &&
          input.cropStageBbchRaw!.trim().isNotEmpty) {
        final err = validateCropStageBbchInput(input.cropStageBbchRaw!);
        if (err != null) {
          return CreateSessionResult.failure(err);
        }
      }

      int? cropStageBbch;
      if (input.cropStageBbchRaw != null &&
          input.cropStageBbchRaw!.trim().isNotEmpty) {
        cropStageBbch = parseCropStageBbchOrNull(input.cropStageBbchRaw!);
      }

      final session = await _sessionRepository.createSession(
        trialId: input.trialId,
        name: input.name.trim(),
        sessionDateLocal: input.sessionDateLocal,
        assessmentIds: input.assessmentIds,
        raterName: input.raterName,
        createdByUserId: input.createdByUserId,
        cropStageBbch: cropStageBbch,
      );

      try {
        await _promoteTrialToActiveIfReady(input.trialId);
      } catch (_) {
        // Session exists; status promotion is best-effort
      }

      return CreateSessionResult.success(session);
    } on OpenSessionExistsException catch (e) {
      return CreateSessionResult.failure(e.toString());
    } catch (e) {
      return CreateSessionResult.failure('Failed to create session: $e');
    }
  }
}

class CreateSessionInput {
  final int trialId;
  final String name;
  final String sessionDateLocal;
  final List<int> assessmentIds;
  final String? raterName;
  final int? createdByUserId;
  /// Raw text from optional BBCH field; empty means omit.
  final String? cropStageBbchRaw;

  const CreateSessionInput({
    required this.trialId,
    required this.name,
    required this.sessionDateLocal,
    required this.assessmentIds,
    this.raterName,
    this.createdByUserId,
    this.cropStageBbchRaw,
  });
}

class CreateSessionResult {
  final bool success;
  final Session? session;
  final String? errorMessage;

  const CreateSessionResult._({
    required this.success,
    this.session,
    this.errorMessage,
  });

  factory CreateSessionResult.success(Session session) =>
      CreateSessionResult._(success: true, session: session);

  factory CreateSessionResult.failure(String message) =>
      CreateSessionResult._(success: false, errorMessage: message);
}
