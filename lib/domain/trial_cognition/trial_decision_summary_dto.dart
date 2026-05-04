import '../signals/signal_decision_dto.dart';
import 'ctq_factor_acknowledgment_dto.dart';

class TrialDecisionSummaryDto {
  const TrialDecisionSummaryDto({
    required this.trialId,
    required this.signalDecisions,
    required this.ctqAcknowledgments,
    required this.hasAnyResearcherReasoning,
  });

  final int trialId;
  final List<SignalDecisionDto> signalDecisions;
  final List<CtqFactorAcknowledgmentDto> ctqAcknowledgments;
  final bool hasAnyResearcherReasoning;
}
