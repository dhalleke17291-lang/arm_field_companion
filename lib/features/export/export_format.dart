import 'package:flutter/material.dart';

/// Returns execution-layer export formats allowed for a trial's workspace type.
/// Conservative mapping based on currently working execution paths only.
List<ExportFormat> allowedExportFormatsForWorkspace(String workspaceType) {
  switch (workspaceType.toLowerCase()) {
    case 'efficacy':
      return [
        ExportFormat.flatCsv,
        ExportFormat.armHandoff,
        ExportFormat.zipBundle,
        ExportFormat.pdfReport,
      ];
    case 'variety':
      return [
        ExportFormat.flatCsv,
        ExportFormat.armHandoff,
        ExportFormat.zipBundle,
        ExportFormat.pdfReport,
      ];
    case 'glp':
      return [
        ExportFormat.flatCsv,
        ExportFormat.armHandoff,
        ExportFormat.zipBundle,
        ExportFormat.pdfReport,
      ];
    case 'standalone':
      return [
        ExportFormat.pdfReport,
        ExportFormat.flatCsv,
      ];
    default:
      return [
        ExportFormat.flatCsv,
        ExportFormat.armHandoff,
        ExportFormat.zipBundle,
        ExportFormat.pdfReport,
      ];
  }
}

enum ExportFormat {
  flatCsv,
  armHandoff,
  zipBundle,
  pdfReport,
}

extension ExportFormatDetails on ExportFormat {
  String get label {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Trial CSV bundle';
      case ExportFormat.armHandoff:
        return 'ARM Import Assistant';
      case ExportFormat.zipBundle:
        return 'ZIP bundle with photos';
      case ExportFormat.pdfReport:
        return 'PDF field report';
    }
  }

  String get description {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Multiple CSV files per trial—observations, manual-transfer sheet, and more. Open data_dictionary.csv for column help.';
      case ExportFormat.armHandoff:
        return 'ZIP with observations, manual-transfer sheet, arm_mapping, import_guide (file roles), validation report, and photos if any.';
      case ExportFormat.zipBundle:
        return 'All CSV files plus photos packaged in one ZIP file';
      case ExportFormat.pdfReport:
        return 'Plot-by-plot report with embedded photos for sponsor or GLP submission';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.flatCsv:
        return Icons.table_chart_outlined;
      case ExportFormat.armHandoff:
        return Icons.science_outlined;
      case ExportFormat.zipBundle:
        return Icons.folder_zip_outlined;
      case ExportFormat.pdfReport:
        return Icons.picture_as_pdf_outlined;
    }
  }

  String get badge {
    switch (this) {
      case ExportFormat.armHandoff:
        return 'Recommended';
      default:
        return '';
    }
  }
}
