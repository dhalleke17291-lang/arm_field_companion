/// Parsed metadata for an ARM-style assessment column header.
///
/// **Two identities (do not conflate):**
/// - [assessmentKey] — semantic grouping (`armCode|timing|unit`) for diagnostics and definition reuse.
/// - [columnInstanceKey] — physical CSV column (`assessmentKey|col{index}`) for [TrialAssessment]
///   rows, [TrialAssessments.armImportColumnIndex], and rating import.
/// Trials imported before per-column anchoring must be **re-imported** to fix collapsed assessments.
class AssessmentToken {
  const AssessmentToken({
    required this.rawHeader,
    required this.armCode,
    required this.timingCode,
    required this.unit,
    required this.columnIndex,
    this.ratingDate,
  });

  final String rawHeader;
  final String armCode;
  final String timingCode;
  final String unit;

  /// 0-based CSV column index (same as [ArmColumnClassification.index]).
  final int columnIndex;

  final DateTime? ratingDate;

  /// Stable key for matching assessment columns (ARM code uppercased, pipe-separated).
  String get assessmentKey {
    final normalizedUnit = unit.replaceAll(RegExp(r'\s+'), ' ').trim();
    return '${armCode.toUpperCase()}|${timingCode.trim()}|$normalizedUnit';
  }

  /// Physical-column identity for import/export anchoring (distinct per [columnIndex]).
  String get columnInstanceKey => '$assessmentKey|col$columnIndex';
}
