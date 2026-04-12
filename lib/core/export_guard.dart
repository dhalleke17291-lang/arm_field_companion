/// Lightweight shared guard to prevent overlapping export starts across screens.
/// Boolean busy state only; no queue, no background worker, no heavy locking.
class ExportGuard {
  /// Message shown when a second export is attempted while one is active.
  static const String busyMessage = 'Another export is already in progress.';
  ExportGuard();

  bool _busy = false;

  /// Runs [fn] exclusively. Returns true if run, false if another export is active.
  /// Always releases the guard in finally.
  Future<bool> runExclusive(Future<void> Function() fn) async {
    if (_busy) return false;
    _busy = true;
    try {
      await fn();
      return true;
    } finally {
      _busy = false;
    }
  }
}
