import '../relationships/causal_context_provider.dart';

class CausalEventMessage {
  final String title;
  final String description;

  const CausalEventMessage({required this.title, required this.description});
}

CausalEventMessage interpretCausalEvent(CausalEvent event) {
  switch (event.type) {
    case CausalEventType.application:
      final days = event.daysBefore;
      final String description;
      if (days == null) {
        description = 'Application timing could not be compared';
      } else if (days < 0) {
        description = 'Application date is after this rating date';
      } else if (days == 0) {
        description = 'Application occurred on the same day as this rating';
      } else if (days == 1) {
        description = 'Application occurred 1 day before this rating';
      } else {
        description = 'Application occurred $days days before this rating';
      }
      return CausalEventMessage(title: 'Prior Application', description: description);

    case CausalEventType.weather:
      return const CausalEventMessage(
        title: 'Session Weather',
        description: 'Weather conditions were recorded for this rating session',
      );
  }
}
