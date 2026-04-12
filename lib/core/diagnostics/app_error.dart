/// Single recorded error for diagnostics / support.
class AppError {
  final String message;
  final String? stackTrace;
  final DateTime timestamp;
  final String? code;

  const AppError({
    required this.message,
    this.stackTrace,
    required this.timestamp,
    this.code,
  });

  String toCopyableReport() {
    final buffer = StringBuffer();
    buffer.writeln('[$timestamp] ${code ?? 'error'}');
    buffer.writeln(message);
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer.writeln(stackTrace);
    }
    return buffer.toString();
  }
}
