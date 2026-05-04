class CtqFactorAcknowledgmentDto {
  const CtqFactorAcknowledgmentDto({
    required this.id,
    required this.factorKey,
    required this.acknowledgedAt,
    required this.actorName,
    required this.reason,
    required this.factorStatusAtAcknowledgment,
  });

  final int id;
  final String factorKey;
  final DateTime acknowledgedAt;
  final String? actorName;
  final String reason;
  final String factorStatusAtAcknowledgment;
}
