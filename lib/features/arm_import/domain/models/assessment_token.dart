/// Parsed metadata for an ARM-style assessment column header.
class AssessmentToken {
  const AssessmentToken({
    required this.rawHeader,
    required this.armCode,
    required this.timingCode,
    required this.unit,
    this.ratingDate,
  });

  final String rawHeader;
  final String armCode;
  final String timingCode;
  final String unit;
  final DateTime? ratingDate;

  /// Stable key for matching assessment columns (ARM code uppercased, pipe-separated).
  String get assessmentKey {
    final normalizedUnit = unit.replaceAll(RegExp(r'\s+'), ' ').trim();
    return '${armCode.toUpperCase()}|${timingCode.trim()}|$normalizedUnit';
  }
}
