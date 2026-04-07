import 'enums/import_confidence.dart';
import 'models/parsed_arm_csv.dart';
import 'models/unknown_pattern_flag.dart';

/// User-facing explanation when [ImportConfidence.blocked] prevents ARM
/// round-trip export. Derived from high-severity export-affecting flags, not
/// from the enum label alone.
String? buildExportBlockReasonFromParsed(ParsedArmCsv parsed) {
  if (parsed.importConfidence != ImportConfidence.blocked) return null;

  final seen = <String>{};
  final ordered = <String>[];

  for (final f in parsed.unknownPatterns) {
    if (!f.affectsExport || f.severity != PatternSeverity.high) continue;
    final s = _sentenceForHighExportBlockingFlag(f);
    if (seen.add(s)) ordered.add(s);
  }

  if (ordered.isEmpty) {
    ordered.add(
      'Required plot, treatment, or rep columns are missing or could not be '
      'read reliably, so ARM round-trip export is not safe.',
    );
  }

  return ordered.join(' ');
}

String _sentenceForHighExportBlockingFlag(UnknownPatternFlag f) {
  switch (f.type) {
    case 'duplicate-assessment-column-instance':
      final key = f.rawValue.trim();
      if (key.isEmpty) {
        return 'Duplicate assessment column anchors were detected; ARM '
            'round-trip export is not safe.';
      }
      return 'Ambiguous duplicate assessment column instance "$key" prevents '
          'safe ARM round-trip export.';
    case 'repeated-assessment-key':
      // Legacy flag type; treat like unsafe column layout.
      final key = f.rawValue.trim();
      if (key.isEmpty) {
        return 'Some imported assessment occurrences cannot yet be mapped '
            'safely back to ARM.';
      }
      return 'Repeated assessment columns for "$key" cannot yet be mapped '
          'safely back to ARM.';
    case 'missing-or-invalid-plot-number':
      return 'One or more rows have invalid or missing plot numbers, which '
          'makes ARM round-trip export unsafe.';
    case 'duplicate-plot-number':
      return 'Duplicate plot numbers were found, which makes ARM round-trip '
          'export unsafe.';
    case 'missing-treatment-number':
      return 'One or more rows are missing treatment numbers, which makes '
          'ARM round-trip export unsafe.';
    case 'assessment_definition':
      final v = f.rawValue.trim();
      if (v.isEmpty) {
        return 'One or more assessment columns could not be aligned with '
            'definitions; ARM round-trip export is not safe.';
      }
      return 'Assessment column "$v" could not be aligned with definitions; '
          'ARM round-trip export is not safe.';
    default:
      return 'A structural issue in the imported file prevents safe ARM '
          'round-trip export.';
  }
}
