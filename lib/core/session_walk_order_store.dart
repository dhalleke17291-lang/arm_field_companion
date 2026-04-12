import 'package:shared_preferences/shared_preferences.dart';

import 'plot_sort.dart';

/// Persists walk order mode per session (numeric, serpentine, custom).
/// Default when unset: [WalkOrderMode.serpentine].
class SessionWalkOrderStore {
  SessionWalkOrderStore(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'session_walk_order_';

  static const String _keyNumeric = 'numeric';
  static const String _keySerpentine = 'serpentine';
  static const String _keyCustom = 'custom';

  WalkOrderMode getMode(int sessionId) {
    final s = _prefs.getString('$_prefix$sessionId');
    if (s == null) return WalkOrderMode.serpentine;
    switch (s) {
      case _keyNumeric:
        return WalkOrderMode.numeric;
      case _keySerpentine:
        return WalkOrderMode.serpentine;
      case _keyCustom:
        return WalkOrderMode.custom;
      default:
        return WalkOrderMode.serpentine;
    }
  }

  Future<void> setMode(int sessionId, WalkOrderMode mode) async {
    final value = switch (mode) {
      WalkOrderMode.numeric => _keyNumeric,
      WalkOrderMode.serpentine => _keySerpentine,
      WalkOrderMode.custom => _keyCustom,
    };
    await _prefs.setString('$_prefix$sessionId', value);
  }

  static String labelForMode(WalkOrderMode mode) {
    return switch (mode) {
      WalkOrderMode.numeric => 'Numeric',
      WalkOrderMode.serpentine => 'Serpentine',
      WalkOrderMode.custom => 'Custom',
    };
  }

  static const _customOrderPrefix = 'session_custom_order_';

  /// Returns the saved custom plot order (plot PKs) for this session, or null if none.
  List<int>? getCustomOrder(int sessionId) {
    final s = _prefs.getString('$_customOrderPrefix$sessionId');
    if (s == null || s.isEmpty) return null;
    final ids = s.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
    return ids.isEmpty ? null : ids;
  }

  /// Saves the custom plot order (plot PKs) for this session.
  Future<void> setCustomOrder(int sessionId, List<int> plotIds) async {
    await _prefs.setString(
      '$_customOrderPrefix$sessionId',
      plotIds.join(','),
    );
  }
}
