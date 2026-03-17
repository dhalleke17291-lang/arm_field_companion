import 'package:flutter/material.dart';

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
        return 'Flat summary CSV';
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
        return 'Human-readable, Excel-friendly format';
      case ExportFormat.armHandoff:
        return 'Complete ARM handoff package — observations, mapping sheet, import guide, validation report';
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
