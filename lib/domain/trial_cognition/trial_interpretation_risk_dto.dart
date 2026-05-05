// EPPO PP1/152(4) thresholds for trial CV.
const double kCvReviewThreshold = 25.0;
const double kCvHighThreshold = 35.0;

class TrialInterpretationRiskDto {
  const TrialInterpretationRiskDto({
    required this.riskLevel,
    required this.factors,
    required this.computedAt,
  });

  final String riskLevel; // 'low' | 'moderate' | 'high' | 'cannot_evaluate'
  final List<TrialRiskFactorDto> factors;
  final DateTime computedAt;
}

class TrialRiskFactorDto {
  const TrialRiskFactorDto({
    required this.factorKey,
    required this.label,
    required this.severity,
    required this.reason,
    required this.sourceFields,
  });

  final String factorKey;
  final String label;
  final String severity; // 'none' | 'moderate' | 'high' | 'cannot_evaluate'
  final String reason;
  final List<String> sourceFields;
}
