// ---------------------------------------------------------------------------
// Sub-summaries
// ---------------------------------------------------------------------------

/// Summary of open (active) signals attached to a session.
///
/// Named "active" to make clear these are current-state signals only —
/// resolved, expired, and suppressed signals are excluded by
/// openSignalsForTrialProvider.
class ActiveSignalSummary {
  final int count;
  final bool hasCritical;
  final List<String> consequenceTexts;

  const ActiveSignalSummary({
    required this.count,
    required this.hasCritical,
    required this.consequenceTexts,
  });
}

class DivergenceSummary {
  final int count;
  final bool hasMissing;
  final bool hasUnexpected;
  final bool hasTiming;

  const DivergenceSummary({
    required this.count,
    required this.hasMissing,
    required this.hasUnexpected,
    required this.hasTiming,
  });
}

class EvidenceSummary {
  final bool hasGps;
  final bool hasWeather;
  final bool hasTimestamp;
  final int photoCount;

  const EvidenceSummary({
    required this.hasGps,
    required this.hasWeather,
    required this.hasTimestamp,
    required this.photoCount,
  });
}

class ApplicationSummary {
  final String? productName;
  final double? rate;
  final String? rateUnit;
  final String status;

  const ApplicationSummary({
    this.productName,
    this.rate,
    this.rateUnit,
    required this.status,
  });
}

class SeedingSummary {
  final String? variety;
  final String? seedLotNumber;
  final double? seedingRate;
  final String? seedingRateUnit;

  const SeedingSummary({
    this.variety,
    this.seedLotNumber,
    this.seedingRate,
    this.seedingRateUnit,
  });
}

// ---------------------------------------------------------------------------
// Event type
// ---------------------------------------------------------------------------

enum TrialStoryEventType { seeding, application, session }

// ---------------------------------------------------------------------------
// Main model
// ---------------------------------------------------------------------------

class TrialStoryEvent {
  final String id;
  final TrialStoryEventType type;
  final DateTime occurredAt;
  final String title;
  final String subtitle;

  /// Active (open/deferred/investigating) signals for this session event.
  /// Null for seeding and application events.
  final ActiveSignalSummary? activeSignalSummary;

  /// Protocol divergences matched to this session.
  /// Null for seeding and application events.
  final DivergenceSummary? divergenceSummary;

  /// Evidence state (GPS, weather, photos, timestamp) for this event.
  /// Populated for sessions. Null for seeding events.
  final EvidenceSummary? evidenceSummary;

  /// Application-specific payload. Non-null only for application events.
  final ApplicationSummary? applicationSummary;

  /// Seeding-specific payload. Non-null only for seeding events.
  final SeedingSummary? seedingSummary;

  const TrialStoryEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.title,
    required this.subtitle,
    this.activeSignalSummary,
    this.divergenceSummary,
    this.evidenceSummary,
    this.applicationSummary,
    this.seedingSummary,
  });
}
