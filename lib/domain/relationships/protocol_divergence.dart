// ---------------------------------------------------------------------------
// Model — protocol / session divergence (relationship layer, provider-free)
// ---------------------------------------------------------------------------

enum EventKind { assessment, application }

enum DivergenceType { timing, missing, unexpected }

class ProtocolDivergence {
  final String entityId;
  final EventKind eventKind;
  final DivergenceType type;
  final int? plannedDat;
  final int? actualDat;
  final int? deltaDays;
  final bool isMissing;
  final bool isUnexpected;

  const ProtocolDivergence({
    required this.entityId,
    required this.eventKind,
    required this.type,
    required this.isMissing,
    required this.isUnexpected,
    this.plannedDat,
    this.actualDat,
    this.deltaDays,
  });
}
