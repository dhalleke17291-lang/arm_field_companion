import 'unknown_pattern_flag.dart';

class ParsedRowCheckResult {
  final List<Map<String, String?>> parsedRows;
  final List<UnknownPatternFlag> flags;
  final int rowCount;

  const ParsedRowCheckResult({
    required this.parsedRows,
    required this.flags,
    required this.rowCount,
  });
}
