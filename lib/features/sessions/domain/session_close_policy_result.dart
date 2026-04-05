import 'session_close_attention_summary.dart';
import 'session_completeness_report.dart';

/// Outcome of [EvaluateSessionClosePolicyUseCase] for session close orchestration.
enum SessionClosePolicyDecision {
  /// Completeness blockers present — do not offer close.
  blocked,

  /// Completeness warnings or legacy attention present
  /// — offer close with acknowledgment.
  warnBeforeClose,

  /// No issues — proceed directly to close.
  proceedToClose,
}

class SessionClosePolicyResult {
  const SessionClosePolicyResult({
    required this.decision,
    required this.completenessReport,
    required this.attentionSummary,
  });

  final SessionClosePolicyDecision decision;
  final SessionCompletenessReport completenessReport;
  final SessionCloseAttentionSummary attentionSummary;
}
