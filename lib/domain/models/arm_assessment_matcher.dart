import 'arm_assessment_identity.dart';
import 'arm_column_map.dart';

/// How [ArmAssessmentMatcher] chose a shell column.
enum ArmAssessmentMatchConfidence {
  exact,
  semantic,
  timing,
  loose,
  positional,
}

/// Result of matching a trial assessment identity to an [ArmColumnMap].
class ArmAssessmentColumnMatch {
  const ArmAssessmentColumnMatch({
    this.column,
    required this.matchConfidence,
    required this.wasPositionalFallback,
  });

  final ArmColumnMap? column;
  final ArmAssessmentMatchConfidence matchConfidence;
  final bool wasPositionalFallback;
}

String? _normalizeArmShellMatchString(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  return t.toUpperCase();
}

bool _armShellUnitMatchesDefinition(String? defUnitTrimmed, ArmColumnMap c) {
  if (defUnitTrimmed == null || defUnitTrimmed.isEmpty) return true;
  return c.ratingUnit?.trim() == defUnitTrimmed;
}

/// Loose timing alignment when [ArmColumnMap.seName] + unit match multiple columns.
bool shellColumnTimingCompatibleWithDefinition(
  ArmColumnMap c,
  String timingNormUpper,
) {
  if (timingNormUpper.isEmpty) return false;
  bool aligns(String? shellPart) {
    final v = _normalizeArmShellMatchString(shellPart);
    if (v == null) return false;
    if (v == timingNormUpper) return true;
    if (timingNormUpper.length >= 4 && v.length >= 4) {
      if (v.contains(timingNormUpper) || timingNormUpper.contains(v)) {
        return true;
      }
    }
    return false;
  }
  return aligns(c.ratingTiming) || aligns(c.ratingDate);
}

/// Shared ARM assessment ↔ Rating Shell column matching (export path).
class ArmAssessmentMatcher {
  const ArmAssessmentMatcher();

  /// Prioritized chain — must stay aligned with legacy export behavior.
  ArmAssessmentColumnMatch findMatchingColumn({
    required ArmAssessmentIdentity assessment,
    required List<ArmColumnMap> columns,
    int? armImportColumnIndex,
    int? armColumnIdInteger,
    required int positionalIndex,
    void Function(String message)? logDebug,
  }) {
    void log(String m) => logDebug?.call(m);

    if (columns.isEmpty) {
      return const ArmAssessmentColumnMatch(
        column: null,
        matchConfidence: ArmAssessmentMatchConfidence.exact,
        wasPositionalFallback: false,
      );
    }

    // Step 0: ARM Column ID integer match (primary anchor for shell-imported trials).
    if (armColumnIdInteger != null) {
      final byId = columns
          .where((c) => c.armColumnIdInteger == armColumnIdInteger)
          .toList();
      if (byId.length == 1) {
        return ArmAssessmentColumnMatch(
          column: byId.single,
          matchConfidence: ArmAssessmentMatchConfidence.exact,
          wasPositionalFallback: false,
        );
      }
    }

    // Step 1: CSV-derived column index pin (legacy anchor for CSV-imported trials).
    final pinnedIdx = armImportColumnIndex;
    if (pinnedIdx != null) {
      final byIdx =
          columns.where((c) => c.columnIndex == pinnedIdx).toList();
      if (byIdx.length == 1) {
        return ArmAssessmentColumnMatch(
          column: byIdx.single,
          matchConfidence: ArmAssessmentMatchConfidence.exact,
          wasPositionalFallback: false,
        );
      }
    }

    final pestCodeNorm = _normalizeArmShellMatchString(assessment.code);
    final unitTrimmed = assessment.unit?.trim() ?? '';

    if (pestCodeNorm != null) {
      final seMatches = columns.where((c) {
        if (_normalizeArmShellMatchString(c.seName) != pestCodeNorm) {
          return false;
        }
        return _armShellUnitMatchesDefinition(
          unitTrimmed.isEmpty ? null : unitTrimmed,
          c,
        );
      }).toList();

      if (seMatches.length == 1) {
        return ArmAssessmentColumnMatch(
          column: seMatches.single,
          matchConfidence: ArmAssessmentMatchConfidence.semantic,
          wasPositionalFallback: false,
        );
      }
      if (seMatches.length > 1) {
        final timingNorm =
            _normalizeArmShellMatchString(assessment.timingCode);
        if (timingNorm != null && timingNorm.isNotEmpty) {
          final byTiming = seMatches
              .where(
                (c) =>
                    shellColumnTimingCompatibleWithDefinition(c, timingNorm),
              )
              .toList();
          if (byTiming.length == 1) {
            return ArmAssessmentColumnMatch(
              column: byTiming.single,
              matchConfidence: ArmAssessmentMatchConfidence.timing,
              wasPositionalFallback: false,
            );
          }
        }
      }
    }

    if (pestCodeNorm != null) {
      final matches = columns.where((c) {
        final typeMatch =
            _normalizeArmShellMatchString(c.ratingType) == pestCodeNorm;
        final unitMatch = unitTrimmed.isEmpty ||
            c.ratingUnit?.trim() == unitTrimmed;
        return typeMatch && unitMatch;
      }).toList();
      if (matches.length == 1) {
        return ArmAssessmentColumnMatch(
          column: matches.first,
          matchConfidence: ArmAssessmentMatchConfidence.loose,
          wasPositionalFallback: false,
        );
      }
      if (matches.length > 1) {
        log(
          'ExportArmRatingShell: ambiguous ratingType match for '
          'pestCode="$pestCodeNorm" unit="$unitTrimmed" — '
          '${matches.length} columns match, using positional.',
        );
      }
    }

    if (positionalIndex < columns.length) {
      return ArmAssessmentColumnMatch(
        column: columns[positionalIndex],
        matchConfidence: ArmAssessmentMatchConfidence.positional,
        wasPositionalFallback: true,
      );
    }
    log(
      'ExportArmRatingShell: no column found for assessment '
      'index=$positionalIndex pestCode=${assessment.code}',
    );
    return const ArmAssessmentColumnMatch(
      column: null,
      matchConfidence: ArmAssessmentMatchConfidence.positional,
      wasPositionalFallback: false,
    );
  }
}
