/// Coherence state: 'aligned' | 'review_needed' | 'cannot_evaluate'
/// Check status: 'aligned' | 'review_needed' | 'cannot_evaluate' | 'acknowledged'
class TrialCoherenceDto {
  const TrialCoherenceDto({
    required this.coherenceState,
    required this.checks,
    required this.computedAt,
  });

  final String coherenceState;
  final List<TrialCoherenceCheckDto> checks;
  final DateTime computedAt;
}

class TrialCoherenceCheckDto {
  const TrialCoherenceCheckDto({
    required this.checkKey,
    required this.label,
    required this.status,
    required this.reason,
    required this.sourceFields,
  });

  final String checkKey;
  final String label;
  final String status;
  final String reason;
  final List<String> sourceFields;
}
