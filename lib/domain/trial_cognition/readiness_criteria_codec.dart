import 'dart:convert';

/// Structured readiness criteria captured against a trial.
///
/// Stored as JSON in trial_purposes.readiness_criteria_summary.
/// This sprint stores and parses only — threshold evaluation against CTQ
/// is deferred to a future sprint.
class ReadinessCriteriaDto {
  const ReadinessCriteriaDto({
    this.minEfficacyPercent,
    this.efficacyAt,
    this.phytotoxicityThresholdPercent,
    required this.setBy,
    required this.setAt,
  });

  /// Minimum efficacy % required for the trial to be considered successful.
  final double? minEfficacyPercent;

  /// Which endpoints must meet the efficacy threshold.
  /// Expected values: 'primary_endpoint_only' | 'all_endpoints'
  final String? efficacyAt;

  /// Maximum acceptable phytotoxicity % (null = not specified).
  final double? phytotoxicityThresholdPercent;

  /// Who set these criteria. Expected values: 'researcher' | 'system'
  final String setBy;

  /// When the criteria were set (UTC).
  final DateTime setAt;
}

class ReadinessCriteriaCodec {
  /// Serializes [dto] to a JSON string for storage in
  /// trial_purposes.readiness_criteria_summary.
  ///
  /// Example output:
  /// ```json
  /// {
  ///   "min_efficacy_percent": 80.0,
  ///   "efficacy_at": "primary_endpoint_only",
  ///   "phytotoxicity_threshold_percent": 10.0,
  ///   "set_by": "researcher",
  ///   "set_at": "2026-05-05T12:00:00.000Z"
  /// }
  /// ```
  static String serialize(ReadinessCriteriaDto dto) {
    return jsonEncode({
      if (dto.minEfficacyPercent != null)
        'min_efficacy_percent': dto.minEfficacyPercent,
      if (dto.efficacyAt != null) 'efficacy_at': dto.efficacyAt,
      if (dto.phytotoxicityThresholdPercent != null)
        'phytotoxicity_threshold_percent': dto.phytotoxicityThresholdPercent,
      'set_by': dto.setBy,
      'set_at': dto.setAt.toUtc().toIso8601String(),
    });
  }

  /// Parses [raw] into [ReadinessCriteriaDto].
  ///
  /// Returns null when [raw] is null (criteria not yet set).
  /// Returns null for malformed JSON — never throws.
  static ReadinessCriteriaDto? parse(String? raw) {
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final setBy = map['set_by'];
      final setAtRaw = map['set_at'];
      if (setBy is! String || setAtRaw is! String) return null;
      final setAt = DateTime.tryParse(setAtRaw);
      if (setAt == null) return null;
      return ReadinessCriteriaDto(
        minEfficacyPercent: (map['min_efficacy_percent'] as num?)?.toDouble(),
        efficacyAt: map['efficacy_at'] as String?,
        phytotoxicityThresholdPercent:
            (map['phytotoxicity_threshold_percent'] as num?)?.toDouble(),
        setBy: setBy,
        setAt: setAt,
      );
    } catch (_) {
      return null;
    }
  }
}
