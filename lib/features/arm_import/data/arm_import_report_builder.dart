import '../domain/enums/import_confidence.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/arm_import_report.dart';
import '../domain/models/parsed_arm_csv.dart';
import '../domain/models/unknown_pattern_flag.dart';

/// Pure builder: [ParsedArmCsv] → user-facing [ArmImportReport] (no UI).
class ArmImportReportBuilder {
  ArmImportReport build(ParsedArmCsv parsed) {
    final plotsDetected = _countUniqueIntegers(
      parsed.dataRows,
      parsed.columns,
      'plotNumber',
    );
    final treatmentsDetected = _countUniqueIntegers(
      parsed.dataRows,
      parsed.columns,
      'treatmentNumber',
    );

    final warnings = <String>[];
    if (parsed.hasSparseData) {
      warnings.add(
        'Some assessment values are blank and were imported as null.',
      );
    }
    if (parsed.hasRepeatedCodes) {
      if (parsed.importConfidence == ImportConfidence.blocked) {
        warnings.add(
          'Repeated assessment keys were detected. ARM round-trip export '
          'cannot run safely until this is resolved.',
        );
      } else {
        warnings.add(
          'Repeated assessment keys were detected. Review before ARM export.',
        );
      }
    }
    for (final f in parsed.unknownPatterns) {
      if (f.severity == PatternSeverity.medium && f.affectsExport) {
        warnings.add('Unvalidated structure detected: ${f.type}.');
      }
    }

    return ArmImportReport(
      confidence: parsed.importConfidence,
      plotsDetected: plotsDetected,
      treatmentsDetected: treatmentsDetected,
      assessmentsDetected: parsed.assessments.length,
      sourceRoute: parsed.sourceRoute,
      armVersionHint: parsed.armVersionHint,
      warnings: warnings,
      unknownPatterns: parsed.unknownPatterns,
      exportStatus: _exportStatusForConfidence(parsed.importConfidence),
    );
  }

  int _countUniqueIntegers(
    List<Map<String, String?>> dataRows,
    List<ArmColumnClassification> columns,
    String identityRole,
  ) {
    final header = _headerForRole(columns, identityRole);
    if (header == null) return 0;
    final seen = <int>{};
    for (final row in dataRows) {
      final raw = row[header];
      if (raw == null) continue;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final n = int.tryParse(trimmed);
      if (n != null) seen.add(n);
    }
    return seen.length;
  }

  String? _headerForRole(
    List<ArmColumnClassification> columns,
    String role,
  ) {
    for (final c in columns) {
      if (c.identityRole == role) return c.header;
    }
    return null;
  }

  String _exportStatusForConfidence(ImportConfidence c) {
    switch (c) {
      case ImportConfidence.high:
        return 'Ready';
      case ImportConfidence.medium:
      case ImportConfidence.low:
        return 'Needs review';
      case ImportConfidence.blocked:
        return 'Blocked';
    }
  }
}
