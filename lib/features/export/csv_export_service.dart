import 'arm_field_mapping.dart';
import 'export_validation_service.dart';

/// Pure CSV formatting utility. No Flutter or provider dependencies.
class CsvExportService {
  CsvExportService._();

  /// Builds a CSV string from headers and rows.
  /// When [headerMapping] is non-null, the first row uses ARM-aligned header
  /// names via [ArmFieldMapping.map]; unmapped headers pass through unchanged.
  /// Joins with commas, wraps values containing any of `,`, `"`, or `\n` in
  /// double quotes, escapes internal double quotes by doubling, terminates lines with \n.
  static String buildCsv(
    List<String> headers,
    List<List<String>> rows, {
    bool armAligned = false,
    Map<String, String>? headerMapping,
  }) {
    final buffer = StringBuffer();
    final effectiveHeaders = (armAligned && headerMapping != null)
        ? headers.map((h) => ArmFieldMapping.map(h, headerMapping)).toList()
        : headers;
    buffer.writeln(_rowToCsv(effectiveHeaders));
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
    if (safe.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"$safe"';
    }
    return safe;
  }

  /// Generates arm_mapping.csv from [ArmFieldMapping.mappingGuide].
  static String buildArmMappingCsv() {
    final sb = StringBuffer();
    sb.writeln('app_column,arm_field,arm_meaning,units,notes');
    for (final row in ArmFieldMapping.mappingGuide) {
      sb.writeln(
        row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      );
    }
    return sb.toString();
  }

  /// Generates a plain-text import guide as CSV-safe content for the handoff package.
  static String buildImportGuideCsv(
    String trialName,
    String exportDate,
    ExportValidationReport validation,
  ) {
    final sb = StringBuffer();
    sb.writeln('section,content');
    sb.writeln('"Target","${ArmFieldMapping.targetVersion}"');
    sb.writeln('"Trial","$trialName"');
    sb.writeln('"Export date","$exportDate"');
    sb.writeln('"","" ');
    sb.writeln('"FILE GUIDE",""');
    sb.writeln(
      '"observations.csv","Primary observations table in this package—for analysis and CSV-oriented import (see arm_mapping.csv for field names)."',
    );
    sb.writeln(
      '"observations_arm_transfer.csv","Manual-transfer-friendly observations with explicit IDs and result status when typing into an external system by hand."',
    );
    sb.writeln(
      '"data_dictionary.csv","Column reference for every CSV file in this bundle."',
    );
    sb.writeln('"","" ');
    sb.writeln('"RECOMMENDED IMPORT ORDER",""');
    sb.writeln(
      '"Step 1","Confirm trial structure exists in your target system with matching plot/rep/treatment layout"',
    );
    sb.writeln(
      '"Step 2","Import observations.csv using PLOTNO / REPNO / TRTNO as keys"',
    );
    sb.writeln(
      '"Manual transfer","For manual entry without automated import, use observations_arm_transfer.csv"',
    );
    sb.writeln('"Step 3","Use OBSDATE as the observation date for each session"');
    sb.writeln(
      '"Step 4","Review validation_report.csv for any errors or warnings before import"',
    );
    sb.writeln(
      '"Step 5","Verify TRAIT names match trait codes in your trial protocol"',
    );
    sb.writeln(
      '"Step 6","After import, cross-check rated plot count in your target system against sessions.csv"',
    );
    sb.writeln('"","" ');
    sb.writeln('"VALIDATION SUMMARY",""');
    sb.writeln('"Errors","${validation.errorCount}"');
    sb.writeln('"Warnings","${validation.warningCount}"');
    sb.writeln(
      '"Status","${validation.isClean ? 'Clean — ready for import' : 'Review errors before import'}"',
    );
    sb.writeln('"","" ');
    sb.writeln('"NOTES",""');
    sb.writeln(
      '"Photo files","Photos are named with trial/plot/session/date/time/sequence"',
    );
    sb.writeln(
      '"Photo reference","See photos_manifest.csv for full photo index"',
    );
    sb.writeln('"Target format version","${ArmFieldMapping.targetVersion}"');
    sb.writeln('"Generator","Ag-Quest Field Companion"');
    return sb.toString();
  }
}
