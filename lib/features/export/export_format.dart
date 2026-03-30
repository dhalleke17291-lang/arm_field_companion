import 'package:flutter/material.dart';

enum ExportFormat {
  flatCsv,
  armHandoff,
  zipBundle,
  pdfReport,
  /// Excel rating shell for ARM data collector; handled by [ExportArmRatingShellUseCase].
  armRatingShell,
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
      case ExportFormat.armRatingShell:
        return 'ARM Rating Shell';
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
      case ExportFormat.armRatingShell:
        return 'Export as Excel file for ARM data collector';
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
      case ExportFormat.armRatingShell:
        return Icons.table_chart_outlined;
    }
  }

  String get badge {
    switch (this) {
      case ExportFormat.armHandoff:
        return 'Recommended';
      case ExportFormat.armRatingShell:
        return '';
      default:
        return '';
    }
  }
}
