import '../session_repository.dart';

class CloseSessionUseCase {
  final SessionRepository _sessionRepository;

  CloseSessionUseCase(this._sessionRepository);

  Future<CloseSessionResult> execute({
    required int sessionId,
    required int trialId,
    String? raterName,
  }) async {
    try {
      // Verify session exists and is open
      final session = await _sessionRepository.getSessionById(sessionId);
      if (session == null) {
        return CloseSessionResult.failure('Session not found');
      }

      if (session.endedAt != null) {
        return CloseSessionResult.failure('Session is already closed');
      }

      if (session.trialId != trialId) {
        return CloseSessionResult.failure(
            'Session does not belong to this trial');
      }

      await _sessionRepository.closeSession(sessionId, raterName);

      return CloseSessionResult.success();
    } catch (e) {
      return CloseSessionResult.failure('Failed to close session: $e');
    }
  }
}

class CloseSessionResult {
  final bool success;
  final String? errorMessage;

  const CloseSessionResult._({required this.success, this.errorMessage});

  factory CloseSessionResult.success() =>
      const CloseSessionResult._(success: true);

  factory CloseSessionResult.failure(String message) =>
      CloseSessionResult._(success: false, errorMessage: message);
}
