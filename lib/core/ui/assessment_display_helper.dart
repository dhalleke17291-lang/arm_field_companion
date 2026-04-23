import 'package:intl/intl.dart';

import '../database/app_database.dart';

/// Display strings for [TrialAssessment] shell-linked metadata (and definition fallback).
class AssessmentDisplayHelper {
  /// Removes internal legacy row suffix ` — TA{id}` from [Assessment.name] for UI.
  ///
  /// Also removes trailing empty parentheses (` ()` or `()`) left after shell
  /// metadata formatting (e.g. `"CONTRO () — TA25"` → `"CONTRO"`).
  static String legacyAssessmentDisplayName(String name) {
    var s = name.replaceFirst(RegExp(r' — TA\d+$'), '').trim();
    final trailingEmptyParens = RegExp(r'(?: \(\)|\(\))\s*$');
    while (trailingEmptyParens.hasMatch(s)) {
      s = s.replaceFirst(trailingEmptyParens, '').trim();
    }
    return s.isEmpty ? name.trim() : s;
  }

  /// Researcher-facing line for chips, pills, list tiles.
  ///
  /// - User rename (`displayNameOverride`) always wins when present.
  /// - Description + SE code: `% weed control (W003)`
  /// - Description only: `% weed control`
  /// - SE code only: `W003`
  /// - Else: [pestCode] → [def.name] → [fallback] → `"Assessment {id}"`
  ///   ([armRatingType] is never used here.)
  ///
  /// Unit 5c: per-column ARM duplicate fields (seDescription / seName /
  /// armRatingType / pestCode) are read from [ArmAssessmentMetadata] when
  /// [aam] is provided, falling back to the matching [TrialAssessment]
  /// columns for trials that have not yet been re-imported. See
  /// docs/ARM_SEPARATION.md.
  static String compactName(
    TrialAssessment ta, {
    AssessmentDefinition? def,
    String? fallback,
    ArmAssessmentMetadataData? aam,
  }) {
    final override = _nonEmpty(ta.displayNameOverride);
    if (override != null) {
      return _cleanEmptyParens(override);
    }

    final d = _seDescriptionOf(ta, aam);
    final sn = _seNameOf(ta, aam);

    String raw;
    if (d != null && sn != null) {
      raw = '$d ($sn)';
    } else if (d != null) {
      raw = d;
    } else if (sn != null) {
      raw = sn;
    } else {
      raw = _nonShellFallback(ta, def, fallback: fallback, aam: aam);
    }
    return _cleanEmptyParens(raw);
  }

  /// Protocol / detail line: SE code first, then description; [armRatingType] only as tertiary.
  ///
  /// - User rename (`displayNameOverride`) always wins when present.
  /// - `W003 — % weed control · Continuous` when all three exist
  /// - `W003 — % weed control` when description + SE code
  /// - Simpler combinations use ` — ` or ` · ` without empty segments.
  static String fullName(
    TrialAssessment ta, {
    AssessmentDefinition? def,
    String? fallback,
    ArmAssessmentMetadataData? aam,
  }) {
    final override = _nonEmpty(ta.displayNameOverride);
    if (override != null) {
      return _cleanEmptyParens(override);
    }

    final d = _seDescriptionOf(ta, aam);
    final sn = _seNameOf(ta, aam);
    final rtRaw = _armRatingTypeOf(ta, aam);
    final rt = rtRaw != null ? _friendlyRatingType(rtRaw) : null;

    String raw;
    if (d != null && sn != null && rt != null) {
      raw = '$sn — $d · $rt';
    } else if (d != null && sn != null) {
      raw = '$sn — $d';
    } else if (d != null && rt != null) {
      raw = '$d · $rt';
    } else if (sn != null && rt != null) {
      raw = '$sn · $rt';
    } else if (d != null) {
      raw = d;
    } else if (sn != null) {
      raw = sn;
    } else if (rt != null) {
      raw = rt;
    } else {
      raw = _primary(ta, def, fallback: fallback, aam: aam);
    }
    return _cleanEmptyParens(raw);
  }

  /// Tight spaces: SE code, else non-shell fallback (no [armRatingType] / description here).
  static String minimalName(
    TrialAssessment ta, {
    AssessmentDefinition? def,
    String? fallback,
    ArmAssessmentMetadataData? aam,
  }) {
    final override = _nonEmpty(ta.displayNameOverride);
    if (override != null) {
      return override;
    }
    final sn = _seNameOf(ta, aam);
    if (sn != null) {
      return sn;
    }
    return _nonShellFallback(ta, def, fallback: fallback, aam: aam);
  }

  /// Rating date: "Apr 2" format, or null.
  ///
  /// v60 moved `armShellRatingDate` to [ArmAssessmentMetadata]; callers pass
  /// the AAM row for the trial-assessment when available.
  static String? ratingDateShort(
    TrialAssessment ta, {
    ArmAssessmentMetadataData? aam,
  }) {
    final raw = aam?.armShellRatingDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    final dt = _parseShellRatingDate(raw);
    if (dt == null) return null;
    return DateFormat('MMM d').format(dt);
  }

  /// SE description or null. Prefers [ArmAssessmentMetadata.seDescription]
  /// when [aam] is provided, else falls back to [TrialAssessment.seDescription].
  static String? description(
    TrialAssessment ta, {
    ArmAssessmentMetadataData? aam,
  }) {
    return _seDescriptionOf(ta, aam);
  }

  /// Single-string priority: seDescription → seName → armRatingType → pestCode → def.name → fallback → id.
  static String _primary(
    TrialAssessment ta,
    AssessmentDefinition? def, {
    String? fallback,
    ArmAssessmentMetadataData? aam,
  }) {
    final d = _seDescriptionOf(ta, aam);
    if (d != null) {
      return d;
    }
    final sn = _seNameOf(ta, aam);
    if (sn != null) {
      return sn;
    }
    final rtRaw = _armRatingTypeOf(ta, aam);
    final rt = rtRaw != null ? _friendlyRatingType(rtRaw) : null;
    if (rt != null) {
      return rt;
    }
    return _nonShellFallback(ta, def, fallback: fallback, aam: aam);
  }

  /// [pestCode] → [AssessmentDefinition.name] → [fallback] → `"Assessment {id}"`.
  static String _nonShellFallback(
    TrialAssessment ta,
    AssessmentDefinition? def, {
    String? fallback,
    ArmAssessmentMetadataData? aam,
  }) {
    final pc = _pestCodeOf(ta, aam);
    if (pc != null) {
      return pc;
    }
    if (def != null && def.name.trim().isNotEmpty) {
      return def.name.trim();
    }
    final fb = _nonEmpty(fallback);
    if (fb != null) {
      return fb;
    }
    return 'Assessment ${ta.id}';
  }

  // AAM-first, TA-fallback accessors for the four duplicate ARM fields
  // (Unit 5c). When the duplicate columns are dropped from TrialAssessments
  // in Unit 5d / schema v61, the fallback arms become unreachable and can
  // be removed together with the corresponding columns.
  static String? _seDescriptionOf(
      TrialAssessment ta, ArmAssessmentMetadataData? aam) {
    return _nonEmpty(aam?.seDescription) ?? _nonEmpty(ta.seDescription);
  }

  static String? _seNameOf(
      TrialAssessment ta, ArmAssessmentMetadataData? aam) {
    return _nonEmpty(aam?.seName) ?? _nonEmpty(ta.seName);
  }

  static String? _armRatingTypeOf(
      TrialAssessment ta, ArmAssessmentMetadataData? aam) {
    return _nonEmpty(aam?.ratingType) ?? _nonEmpty(ta.armRatingType);
  }

  static String? _pestCodeOf(
      TrialAssessment ta, ArmAssessmentMetadataData? aam) {
    return _nonEmpty(aam?.pestCode) ?? _nonEmpty(ta.pestCode);
  }

  /// Translates ARM rating-type codes to user-friendly labels.
  /// Returns null for unrecognised codes (suppresses them from display).
  static String? _friendlyRatingType(String code) {
    switch (code.toUpperCase()) {
      case 'CONTRO':
        return 'Continuous';
      case 'DISC':
        return 'Discrete';
      case 'ORDINAL':
        return 'Ordinal';
      default:
        return null;
    }
  }

  /// Formats an optional parenthetical suffix. Returns empty string
  /// when value is null, empty, or whitespace-only.
  static String formatParenthetical(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '' : ' ($trimmed)';
  }

  /// Strips empty parentheticals like ` ()` or `()` from display strings.
  static String _cleanEmptyParens(String s) {
    return s.replaceAll(RegExp(r'\s*\(\s*\)'), '').trim();
  }

  static String? _nonEmpty(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) {
      return null;
    }
    return t;
  }

  static DateTime? _parseShellRatingDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    const patterns = <String>[
      'd-MMM-yy',
      'dd-MMM-yy',
      'd-MMM-yyyy',
      'dd-MMM-yyyy',
      'MMM d, yyyy',
      'MMM d yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
      'd/M/yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'yyyy-MM-dd',
    ];
    for (final p in patterns) {
      try {
        return DateFormat(p, 'en_US').parse(s);
      } catch (_) {}
    }
    return null;
  }
}
