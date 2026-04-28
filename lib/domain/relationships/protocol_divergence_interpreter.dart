import 'protocol_divergence.dart';

class DivergenceMessage {
  final String title;
  final String description;

  const DivergenceMessage({
    required this.title,
    required this.description,
  });
}

DivergenceMessage interpretProtocolDivergence(ProtocolDivergence d) {
  switch (d.type) {
    case DivergenceType.timing:
      final delta = d.deltaDays;
      if (delta == null) {
        return const DivergenceMessage(
          title: 'Timing Unknown',
          description: 'Session dates could not be compared',
        );
      }
      final n = delta.abs();
      final dayWord = n == 1 ? 'day' : 'days';
      return delta > 0
          ? DivergenceMessage(
              title: 'Rated Late',
              description: '$n $dayWord later than planned',
            )
          : DivergenceMessage(
              title: 'Rated Early',
              description: '$n $dayWord earlier than planned',
            );

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
  }
}
