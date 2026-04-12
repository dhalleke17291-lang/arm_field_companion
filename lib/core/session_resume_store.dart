import 'package:shared_preferences/shared_preferences.dart';

import 'database/app_database.dart';

/// Last rating position per session (field speed).
///
/// **v2** (current): primary key is [plotPk] (plot row id). Persisted as `v2:<plotPk>,<assessmentIndex>`.
///
/// **Legacy**: plot position in the walk-ordered list only. Persisted as `<plotIndex>,<assessmentIndex>`.
class SessionResumePosition {
  const SessionResumePosition({
    required this.assessmentIndex,
    this.plotPk,
    this.legacyPlotIndex,
  }) : assert(plotPk != null || legacyPlotIndex != null);

  final int assessmentIndex;

  /// When set, restore by matching this plot primary key against [Plot.id].
  final int? plotPk;

  /// Legacy: index into the walk-ordered plot list at save time.
  final int? legacyPlotIndex;

  int clampedAssessmentIndex(int assessmentCount) {
    if (assessmentCount <= 0) return 0;
    return assessmentIndex.clamp(0, assessmentCount - 1);
  }

  /// True when opening [RatingScreen] for this plot row (queue: same plot as saved).
  bool isForPlot(int plotPk, int plotIndexInWalk) {
    if (this.plotPk != null) return this.plotPk == plotPk;
    if (legacyPlotIndex != null) return legacyPlotIndex == plotIndexInWalk;
    return false;
  }

  /// Resolves to a start index in [plots] and optional assessment chip index.
  ///
  /// When [plotPk] is set and found in [plots], uses that index and restores assessment.
  /// When [plotPk] is set but not found (deleted plot), uses [fallbackStartIndex] and
  /// does not restore assessment.
  /// Legacy: uses [legacyPlotIndex] when in range; otherwise falls back.
  (int startIndex, int? initialAssessmentIndex) resolveResumeStart({
    required List<Plot> plots,
    required int fallbackStartIndex,
    required int assessmentCount,
  }) {
    if (plots.isEmpty) return (0, null);
    final fb = fallbackStartIndex.clamp(0, plots.length - 1);
    if (plotPk != null) {
      final idx = plots.indexWhere((p) => p.id == plotPk);
      if (idx >= 0) {
        return (idx, clampedAssessmentIndex(assessmentCount));
      }
      return (fb, null);
    }
    if (legacyPlotIndex != null) {
      final li = legacyPlotIndex!;
      if (li >= 0 && li < plots.length) {
        return (li, clampedAssessmentIndex(assessmentCount));
      }
    }
    return (fb, null);
  }
}

/// Persists last (plot identity or index, assessment index) per session for session resume.
class SessionResumeStore {
  SessionResumeStore(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'session_resume_';
  static const _v2Prefix = 'v2:';

  /// Saves [plotPk] (plot row primary key) and [assessmentIndex].
  void savePosition(int sessionId, int plotPk, int assessmentIndex) {
    _prefs.setString('$_prefix$sessionId', '$_v2Prefix$plotPk,$assessmentIndex');
  }

  /// Returns saved position, or null if none / invalid.
  SessionResumePosition? getPosition(int sessionId) {
    final s = _prefs.getString('$_prefix$sessionId');
    if (s == null) return null;
    if (s.startsWith(_v2Prefix)) {
      final rest = s.substring(_v2Prefix.length);
      final parts = rest.split(',');
      if (parts.length != 2) return null;
      final pk = int.tryParse(parts[0]);
      final ai = int.tryParse(parts[1]);
      if (pk == null || ai == null) return null;
      return SessionResumePosition(plotPk: pk, assessmentIndex: ai);
    }
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final plotIndex = int.tryParse(parts[0]);
    final assessmentIndex = int.tryParse(parts[1]);
    if (plotIndex == null || assessmentIndex == null) return null;
    return SessionResumePosition(
      legacyPlotIndex: plotIndex,
      assessmentIndex: assessmentIndex,
    );
  }
}
