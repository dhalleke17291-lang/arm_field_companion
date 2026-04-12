enum PatternSeverity {
  high,
  medium,
  low,
}

class UnknownPatternFlag {
  const UnknownPatternFlag({
    required this.type,
    required this.severity,
    required this.affectsExport,
    required this.rawValue,
  });

  final String type;
  final PatternSeverity severity;
  final bool affectsExport;
  final String rawValue;
}
