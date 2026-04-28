import '../relationships/behavioral_signature_provider.dart';

/// Human-readable copy for a single [BehavioralSignal] (mapping only — no
/// severity, recommendations, or cause attribution).
class BehavioralMessage {
  final String title;
  final String description;

  const BehavioralMessage({
    required this.title,
    required this.description,
  });
}

/// Maps one behavioral signal to UI copy. Branch order follows
/// [BehavioralSignalType].
BehavioralMessage interpretBehavioralSignal(BehavioralSignal signal) {
  switch (signal.type) {
    case BehavioralSignalType.paceChange:
      if (signal.value < 0) {
        return const BehavioralMessage(
          title: 'Later Ratings Faster',
          description:
              'Later ratings took less time on average than earlier ones',
        );
      }
      if (signal.value > 0) {
        return const BehavioralMessage(
          title: 'Later Ratings Slower',
          description:
              'Later ratings took more time on average than earlier ones',
        );
      }
      return const BehavioralMessage(
        title: 'Pace Unchanged',
        description:
            'No pace difference was detected between earlier and later ratings',
      );

    case BehavioralSignalType.confidenceTrend:
      if (signal.value > 0) {
        return const BehavioralMessage(
          title: 'Confidence Rising',
          description:
              'Confidence was higher in later ratings than in earlier ones',
        );
      }
      if (signal.value < 0) {
        return const BehavioralMessage(
          title: 'Confidence Falling',
          description:
              'Confidence was lower in later ratings than in earlier ones',
        );
      }
      return const BehavioralMessage(
        title: 'Confidence Stable',
        description:
            'No confidence difference was detected between earlier and later ratings',
      );

    case BehavioralSignalType.editFrequency:
      final n = signal.value.toInt();
      if (n == 0) {
        return const BehavioralMessage(
          title: 'No Edits',
          description: 'No ratings were amended or corrected',
        );
      }
      if (n == 1) {
        return const BehavioralMessage(
          title: '1 Edit',
          description: '1 rating was amended or corrected',
        );
      }
      return BehavioralMessage(
        title: '$n Edits',
        description: '$n ratings were amended or corrected',
      );
  }
}
