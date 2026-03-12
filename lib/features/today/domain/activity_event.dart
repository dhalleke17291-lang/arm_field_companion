/// Wall-clock time for ordering (same day). Opaque for sorting.
typedef ActivityTime = DateTime;

/// One entry in the "Today" / day-summary timeline. Sealed-style variants.
sealed class ActivityEvent {
  const ActivityEvent({required this.at});

  final ActivityTime at;
}

final class SessionStartedEvent extends ActivityEvent {
  const SessionStartedEvent({
    required super.at,
    required this.sessionName,
    required this.trialName,
  });

  final String sessionName;
  final String trialName;
}

final class SessionClosedEvent extends ActivityEvent {
  const SessionClosedEvent({
    required super.at,
    required this.sessionName,
    required this.trialName,
  });

  final String sessionName;
  final String trialName;
}

final class RatingsBatchEvent extends ActivityEvent {
  const RatingsBatchEvent({
    required super.at,
    required this.count,
    required this.sessionName,
    required this.trialName,
  });

  final int count;
  final String sessionName;
  final String trialName;
}

final class FlagsBatchEvent extends ActivityEvent {
  const FlagsBatchEvent({
    required super.at,
    required this.count,
    required this.sessionName,
    required this.trialName,
  });

  final int count;
  final String sessionName;
  final String trialName;
}

final class PhotosBatchEvent extends ActivityEvent {
  const PhotosBatchEvent({
    required super.at,
    required this.count,
    required this.sessionName,
    required this.trialName,
  });

  final int count;
  final String sessionName;
  final String trialName;
}

final class PlotsAssignedEvent extends ActivityEvent {
  const PlotsAssignedEvent({
    required super.at,
    required this.count,
    required this.trialName,
  });

  final int count;
  final String trialName;
}

final class ExportDoneEvent extends ActivityEvent {
  const ExportDoneEvent({
    required super.at,
    required this.trialName,
    required this.format,
  });

  final String trialName;
  final String format;
}
