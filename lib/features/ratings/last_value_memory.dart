import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory last entered numeric value per (sessionId, assessmentId).
/// Used to pre-fill the rating field when moving to the next plot (technician convenience).
String _key(int sessionId, int assessmentId) => '${sessionId}_$assessmentId';

class LastValueMemoryNotifier extends StateNotifier<Map<String, double>> {
  LastValueMemoryNotifier() : super({});

  void set(int sessionId, int assessmentId, double value) {
    state = {...state, _key(sessionId, assessmentId): value};
  }

  double? get(int sessionId, int assessmentId) =>
      state[_key(sessionId, assessmentId)];
}

final lastValueMemoryProvider =
    StateNotifierProvider<LastValueMemoryNotifier, Map<String, double>>((ref) {
  return LastValueMemoryNotifier();
});
