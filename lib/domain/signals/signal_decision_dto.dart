class SignalDecisionDto {
  const SignalDecisionDto({
    required this.id,
    required this.signalId,
    required this.eventType,
    required this.occurredAt,
    this.actorName,
    this.note,
    required this.resultingStatus,
  });

  final int id;
  final int signalId;
  final String eventType;
  final int occurredAt;
  final String? actorName;
  final String? note;
  final String resultingStatus;
}
