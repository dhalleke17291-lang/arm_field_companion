/// Pure CSV formatting utility. No Flutter or provider dependencies.
class CsvExportService {
  CsvExportService._();

  /// Builds a CSV string from headers and rows.
  /// Joins with commas, wraps values containing commas in double quotes,
  /// escapes internal double quotes by doubling, terminates lines with \n.
  static String buildCsv(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(_rowToCsv(headers));
    for (final row in rows) {
      buffer.writeln(_rowToCsv(row));
    }
    return buffer.toString();
  }

  static String _rowToCsv(List<String> values) {
    return values.map(_escape).join(',');
  }

  static String _escape(String value) {
    final safe = value.replaceAll('"', '""');
    if (safe.contains(',')) {
      return '"$safe"';
    }
    return safe;
  }
}
