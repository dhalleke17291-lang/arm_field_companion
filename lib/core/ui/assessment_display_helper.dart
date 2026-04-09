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
  /// - Description + SE code: `% weed control (W003)`
  /// - Description only: `% weed control`
  /// - SE code only: `W003`
  /// - Else: [pestCode] → [def.name] → `"Assessment {id}"` ([armRatingType] is never used here).
  static String compactName(TrialAssessment ta, {AssessmentDefinition? def}) {
    final d = _nonEmpty(ta.seDescription);
    final sn = _nonEmpty(ta.seName);

    if (d != null && sn != null) {
      return '$d ($sn)';
    }
    if (d != null) {
      return d;
    }
    if (sn != null) {
      return sn;
    }
    return _nonShellFallback(ta, def);
  }

  /// Protocol / detail line: SE code first, then description; [armRatingType] only as tertiary.
  ///
  /// - `W003 — % weed control · CONTRO` when all three exist
  /// - `W003 — % weed control` when description + SE code
  /// - Simpler combinations use ` — ` or ` · ` without empty segments.
  static String fullName(TrialAssessment ta, {AssessmentDefinition? def}) {
    final d = _nonEmpty(ta.seDescription);
    final sn = _nonEmpty(ta.seName);
    final rt = _nonEmpty(ta.armRatingType);

    if (d != null && sn != null && rt != null) {
      return '$sn — $d · $rt';
    }
    if (d != null && sn != null) {
      return '$sn — $d';
    }
    if (d != null && rt != null) {
      return '$d · $rt';
    }
    if (sn != null && rt != null) {
      return '$sn · $rt';
    }
    if (d != null) {
      return d;
    }
    if (sn != null) {
      return sn;
    }
    if (rt != null) {
      return rt;
    }
    return _primary(ta, def);
  }

  /// Tight spaces: SE code, else non-shell fallback (no [armRatingType] / description here).
  static String minimalName(TrialAssessment ta, {AssessmentDefinition? def}) {
    final sn = _nonEmpty(ta.seName);
    if (sn != null) {
      return sn;
    }
    return _nonShellFallback(ta, def);
  }

  /// Rating date: "Apr 2" format, or null
  static String? ratingDateShort(TrialAssessment ta) {
    final raw = ta.armShellRatingDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    final dt = _parseShellRatingDate(raw);
    if (dt == null) return null;
    return DateFormat('MMM d').format(dt);
  }

  /// SE description or null
  static String? description(TrialAssessment ta) {
    final d = ta.seDescription;
    return (d != null && d.isNotEmpty) ? d : null;
  }

  /// Single-string priority: seDescription → seName → armRatingType → pestCode → def.name → id.
  static String _primary(TrialAssessment ta, AssessmentDefinition? def) {
    final d = _nonEmpty(ta.seDescription);
    if (d != null) {
      return d;
    }
    final sn = _nonEmpty(ta.seName);
    if (sn != null) {
      return sn;
    }
    final rt = _nonEmpty(ta.armRatingType);
    if (rt != null) {
      return rt;
    }
    return _nonShellFallback(ta, def);
  }

  /// [pestCode] → [AssessmentDefinition.name] → `"Assessment {id}"`.
  static String _nonShellFallback(TrialAssessment ta, AssessmentDefinition? def) {
    final pc = _nonEmpty(ta.pestCode);
    if (pc != null) {
      return pc;
    }
    if (def != null && def.name.trim().isNotEmpty) {
      return def.name.trim();
    }
    return 'Assessment ${ta.id}';
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
