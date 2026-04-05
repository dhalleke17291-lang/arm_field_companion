import '../../core/database/app_database.dart';

/// Canonical ARM assessment identity shared by CSV import, profile export gate,
/// and Rating Shell column matching.
class ArmAssessmentIdentity {
  const ArmAssessmentIdentity({
    required this.code,
    this.unit,
    this.timingCode,
    this.seName,
  });

  /// Primary code (EPPO / armCode / pestCode), stored uppercase where applicable.
  final String code;

  final String? unit;

  final String? timingCode;

  /// SE Name from shell metadata; null on CSV import side.
  final String? seName;

  /// Normalized key for exact comparisons (aligned with [AssessmentToken.assessmentKey]
  /// pipe segments, plus an optional `|SENAME` suffix when [seName] is set).
  String get canonicalKey {
    final normalizedUnit =
        (unit ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final tc = (timingCode ?? '').trim();
    final base = '${code.toUpperCase()}|$tc|$normalizedUnit';
    final se = seName?.trim();
    if (se == null || se.isEmpty) return base;
    return '$base|${se.toUpperCase()}';
  }

  /// Identity for export/profile from trial protocol + definition.
  factory ArmAssessmentIdentity.fromTrialAssessment(
    TrialAssessment ta,
    AssessmentDefinition? def,
  ) {
    final pc = ta.pestCode?.trim();
    final rawCode = (pc != null && pc.isNotEmpty)
        ? pc
        : (def?.code.trim() ?? '');
    final u = def?.unit?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final tc = def?.timingCode?.trim();
    return ArmAssessmentIdentity(
      code: rawCode.toUpperCase(),
      unit: u == null || u.isEmpty ? null : u,
      timingCode: tc == null || tc.isEmpty ? null : tc,
      seName: null,
    );
  }
}
