import 'package:shared_preferences/shared_preferences.dart';

/// Persists last (plot index, assessment index) per session for session resume (field speed).
class SessionResumeStore {
  SessionResumeStore(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'session_resume_';

  void savePosition(int sessionId, int plotIndex, int assessmentIndex) {
    _prefs.setString('$_prefix$sessionId', '$plotIndex,$assessmentIndex');
  }

  /// Returns (plotIndex, assessmentIndex) or null if none saved.
  (int, int)? getPosition(int sessionId) {
    final s = _prefs.getString('$_prefix$sessionId');
    if (s == null) return null;
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final plotIndex = int.tryParse(parts[0]);
    final assessmentIndex = int.tryParse(parts[1]);
    if (plotIndex == null || assessmentIndex == null) return null;
    return (plotIndex, assessmentIndex);
  }
}
