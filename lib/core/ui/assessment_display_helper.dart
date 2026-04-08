import 'package:intl/intl.dart';

import '../database/app_database.dart';

/// Display strings for [TrialAssessment] shell-linked metadata (and definition fallback).
class AssessmentDisplayHelper {
  /// Compact: "CONTRO (W003)" — for chips, pills, list tiles
  static String compactName(TrialAssessment ta, {AssessmentDefinition? def}) {
    final primary = _primary(ta, def);
    final seName = ta.seName;
    if (seName != null && seName.isNotEmpty && seName != primary) {
      return '$primary ($seName)';
    }
    return primary;
  }

  /// Full: "CONTRO — W003 · % weed control" — for detail views
  static String fullName(TrialAssessment ta, {AssessmentDefinition? def}) {
    final primary = _primary(ta, def);
    final parts = <String>[primary];
    final seName = ta.seName;
    if (seName != null && seName.isNotEmpty && seName != primary) {
      parts.add(seName);
    }
    final desc = ta.seDescription;
    if (desc != null && desc.isNotEmpty) {
      return '${parts.join(' — ')} · $desc';
    }
    return parts.join(' — ');
  }

  /// Minimal: "CONTRO" — for tight spaces
  static String minimalName(TrialAssessment ta, {AssessmentDefinition? def}) {
    return _primary(ta, def);
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

  static String _primary(TrialAssessment ta, AssessmentDefinition? def) {
    if (ta.armRatingType != null && ta.armRatingType!.isNotEmpty) {
      return ta.armRatingType!;
    }
    if (ta.pestCode != null && ta.pestCode!.isNotEmpty) {
      return ta.pestCode!;
    }
    if (def != null && def.name.isNotEmpty) {
      return def.name;
    }
    return 'Assessment ${ta.id}';
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
