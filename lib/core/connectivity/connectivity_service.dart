import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Shared connectivity infrastructure for all online features.
///
/// Features register queued tasks that execute when connectivity returns.
/// The service handles: network status checks, offline queueing,
/// retry on reconnect, and a connectivity state stream for UI.
///
/// Hard rule: every feature using this service MUST work without internet.
/// Internet is an enhancement layer, never a requirement.
class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _stateController = StreamController<ConnectivityState>.broadcast();
  final _queue = Queue<_QueuedTask>();
  bool _processing = false;

  ConnectivityState _currentState = ConnectivityState.unknown;

  /// Current connectivity state.
  ConnectivityState get currentState => _currentState;

  /// Stream of connectivity state changes.
  Stream<ConnectivityState> get stateStream => _stateController.stream;

  /// True when any network (wifi, mobile, ethernet) is available.
  bool get isOnline => _currentState == ConnectivityState.online;

  /// Check connectivity right now (one-shot).
  Future<bool> checkNow() async {
    final results = await Connectivity().checkConnectivity();
    final online = _resultsToState(results) == ConnectivityState.online;
    _updateState(online
        ? ConnectivityState.online
        : ConnectivityState.offline);
    return online;
  }

  /// Queue a task to execute when online. If already online, executes
  /// immediately. If offline, queues and retries when connectivity returns.
  ///
  /// [tag] identifies the task type for deduplication. If a task with the
  /// same tag is already queued, the old one is replaced.
  ///
  /// Returns true if the task executed successfully, false if queued.
  Future<bool> executeWhenOnline({
    required String tag,
    required Future<void> Function() task,
  }) async {
    if (isOnline) {
      try {
        await task();
        return true;
      } catch (e) {
        debugPrint('ConnectivityService: task "$tag" failed online: $e');
        return false;
      }
    }

    // Remove existing task with same tag (dedup)
    _queue.removeWhere((t) => t.tag == tag);
    _queue.add(_QueuedTask(tag: tag, task: task));
    debugPrint('ConnectivityService: queued "$tag" (offline, ${_queue.length} in queue)');
    return false;
  }

  /// Number of tasks waiting for connectivity.
  int get queuedTaskCount => _queue.length;

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final state = _resultsToState(results);
    _updateState(state);
  }

  void _updateState(ConnectivityState state) {
    if (state == _currentState) return;
    _currentState = state;
    _stateController.add(state);

    if (state == ConnectivityState.online) {
      _drainQueue();
    }
  }

  Future<void> _drainQueue() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final task = _queue.removeFirst();
      try {
        await task.task();
        debugPrint('ConnectivityService: completed "${task.tag}"');
      } catch (e) {
        debugPrint('ConnectivityService: task "${task.tag}" failed: $e');
        // Don't re-queue failed tasks — they had their chance.
      }
    }

    _processing = false;
  }

  ConnectivityState _resultsToState(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      return ConnectivityState.offline;
    }
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet)) {
      return ConnectivityState.online;
    }
    return ConnectivityState.offline;
  }

  /// Call when the app is shutting down.
  void dispose() {
    _subscription?.cancel();
    _stateController.close();
  }
}

enum ConnectivityState {
  online,
  offline,
  unknown,
}

class _QueuedTask {
  const _QueuedTask({required this.tag, required this.task});
  final String tag;
  final Future<void> Function() task;
}
