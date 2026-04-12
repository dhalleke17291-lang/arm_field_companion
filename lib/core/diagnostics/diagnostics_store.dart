import 'app_error.dart';

/// In-memory store of recent errors for diagnostics/support.
/// Keeps last [maxErrors] entries.
class DiagnosticsStore {
  DiagnosticsStore({this.maxErrors = 50});

  final int maxErrors;
  final List<AppError> _errors = [];

  List<AppError> get recentErrors => List.unmodifiable(_errors);

  void addError(AppError error) {
    _errors.insert(0, error);
    while (_errors.length > maxErrors) {
      _errors.removeLast();
    }
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
  }
}
