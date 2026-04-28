import '../relationships/protocol_divergence.dart';

/// Human-readable copy for a single [ProtocolDivergence] (mapping only — no
/// severity, recommendations, or cross-record reasoning).
class DivergenceMessage {
  final String title;
  final String description;

  const DivergenceMessage({
    required this.title,
    required this.description,
  });
}

/// Maps one divergence record to UI copy. Branch order follows [DivergenceType].
DivergenceMessage interpretProtocolDivergence(ProtocolDivergence divergence) {
  switch (divergence.type) {
    case DivergenceType.missing:
      return const DivergenceMessage(
        title: 'No Ratings Recorded',
        description: 'Planned session has no recorded ratings',
      );
    case DivergenceType.unexpected:
      return const DivergenceMessage(
        title: 'Unplanned Session',
        description: 'Session was not part of the protocol',
      );
    case DivergenceType.timing:
      final delta = divergence.deltaDays;
      if (delta == null) {
        return const DivergenceMessage(
          title: 'Timing Unknown',
          description: 'Session dates could not be compared',
        );
      }
      if (delta == 0) {
        return const DivergenceMessage(
          title: 'On Plan',
          description: 'Rated on the planned date',
        );
      }
      if (delta > 0) {
        return DivergenceMessage(
          title: 'Rated Late',
          description: '${_daysWord(delta)} later than planned',
        );
      }
      return DivergenceMessage(
        title: 'Rated Early',
        description: '${_daysWord(delta)} earlier than planned',
      );
  }
}

String _daysWord(int signedDelta) {
  final n = signedDelta.abs();
  if (n == 1) return '1 day';
  return '$n days';
}
