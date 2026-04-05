import '../domain/session_close_policy_result.dart';
import '../domain/session_completeness_report.dart';
import '../session_repository.dart';
import 'evaluate_session_close_policy_usecase.dart';

class CloseSessionUseCase {
  CloseSessionUseCase(
    this._sessionRepository,
    this._evaluateClosePolicy,
  );

  final SessionRepository _sessionRepository;
  final EvaluateSessionClosePolicyUseCase _evaluateClosePolicy;

  Future<CloseSessionResult> execute({
    required int sessionId,
    required int trialId,
    String? raterName,
    int? closedByUserId,
    bool forceClose = false,
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

      final policy = await _evaluateClosePolicy.execute(
        sessionId: sessionId,
        trialId: trialId,
      );

      switch (policy.decision) {
        case SessionClosePolicyDecision.blocked:
          final blockers = policy.completenessReport.issues
              .where(
                (i) => i.severity == SessionCompletenessIssueSeverity.blocker,
              )
              .map(
                (i) => i
                    .toDiagnosticFinding(
                      trialId: trialId,
                      sessionId: sessionId,
                    )
                    .message,
              )
              .toList();
          final detail = blockers.isEmpty
              ? 'Resolve completeness blockers before closing.'
              : blockers.join('; ');
          return CloseSessionResult.failure(
            'Cannot close session: $detail',
          );
        case SessionClosePolicyDecision.warnBeforeClose:
          if (!forceClose) {
            final warningLines = policy.completenessReport.issues
                .where(
                  (i) => i.severity == SessionCompletenessIssueSeverity.warning,
                )
                .map(
                  (i) => i
                      .toDiagnosticFinding(
                        trialId: trialId,
                        sessionId: sessionId,
                      )
                      .message,
                )
                .toList();
            final attentionParts = <String>[];
            if (policy.attentionSummary.needsAttention) {
              final s = policy.attentionSummary;
              if (s.unratedPlots > 0) {
                attentionParts.add('${s.unratedPlots} plot(s) without ratings');
              }
              if (s.flaggedPlots > 0) {
                attentionParts.add('${s.flaggedPlots} flagged plot(s)');
              }
              if (s.issuesPlots > 0) {
                attentionParts.add(
                  '${s.issuesPlots} plot(s) with non-recorded statuses',
                );
              }
              if (s.editedPlots > 0) {
                attentionParts.add(
                  '${s.editedPlots} plot(s) with edits or corrections',
                );
              }
            }
            final parts = <String>[
              ...warningLines,
              ...attentionParts,
            ];
            final tail = parts.isEmpty
                ? 'Review the pre-close dialog or confirm Close anyway.'
                : parts.join('; ');
            return CloseSessionResult.failure(
              'Session has warnings or items needing attention. $tail',
            );
          }
          break;
        case SessionClosePolicyDecision.proceedToClose:
          break;
      }

      await _sessionRepository.closeSession(
        sessionId,
        raterName: raterName,
        closedByUserId: closedByUserId,
      );

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
