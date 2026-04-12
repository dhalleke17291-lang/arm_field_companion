import 'package:shared_preferences/shared_preferences.dart';

/// Persists last (trialId, sessionId) for "Continue Last Session" home card (survives restarts).
class LastSessionStore {
  LastSessionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _keyTrialId = 'last_session_trial_id';
  static const _keySessionId = 'last_session_session_id';

  void save(int trialId, int sessionId) {
    _prefs.setInt(_keyTrialId, trialId);
    _prefs.setInt(_keySessionId, sessionId);
  }

  /// Returns (trialId, sessionId) or null if none saved.
  (int, int)? get() {
    final trialId = _prefs.getInt(_keyTrialId);
    final sessionId = _prefs.getInt(_keySessionId);
    if (trialId == null || sessionId == null) return null;
    return (trialId, sessionId);
  }
}
