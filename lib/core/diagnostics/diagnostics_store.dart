import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_error.dart';

/// Persistent store of recent errors for diagnostics/support.
/// Keeps last [maxErrors] entries. Writes to disk on each new error
/// so the log survives app restarts and crash recovery.
class DiagnosticsStore {
  DiagnosticsStore({this.maxErrors = 50});

  final int maxErrors;
  final List<AppError> _errors = [];
  bool _loaded = false;

  List<AppError> get recentErrors => List.unmodifiable(_errors);

  void addError(AppError error) {
    _errors.insert(0, error);
    while (_errors.length > maxErrors) {
      _errors.removeLast();
    }
    _persistAsync();
  }

  void recordError(String message, {String? stackTrace, String? code}) {
    addError(AppError(
      message: message,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      code: code,
    ));
  }

  void clear() {
    _errors.clear();
    _persistAsync();
  }

  /// Load persisted errors from disk. Call once at app startup.
  Future<void> loadFromDisk() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _logFile();
      if (!await file.exists()) return;
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          _errors.add(AppError(
            message: item['message'] as String? ?? '',
            stackTrace: item['stackTrace'] as String?,
            timestamp: DateTime.tryParse(item['timestamp'] as String? ?? '') ??
                DateTime.now(),
            code: item['code'] as String?,
          ));
        }
      }
    } catch (_) {
      // Corrupt log file — start fresh.
    }
  }

  void _persistAsync() {
    _logFile().then((file) {
      final list = _errors
          .map((e) => {
                'message': e.message,
                'stackTrace': e.stackTrace,
                'timestamp': e.timestamp.toIso8601String(),
                'code': e.code,
              })
          .toList();
      file.writeAsString(jsonEncode(list)).ignore();
    }).ignore();
  }

  Future<File> _logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/diagnostics_log.json');
  }
}
