import 'package:flutter/material.dart';

enum ExportFormat {
  flatCsv,
  armHandoff,
  zipBundle,
  pdfReport,
  /// Field Evidence Report — provenance document with timestamps, amendments,
  /// outliers, device/rater certification, and completeness scoring.
  evidenceReport,
  /// Trial Report PDF — structured document for the regulatory binder.
  /// Site summary, treatments, design, applications, assessment data tables.
  trialReport,
  /// Excel rating shell for imported protocol trials; handled by [ExportArmRatingShellUseCase].
  /// Listed on the trial export sheet only when the trial is ARM-linked.
  armRatingShell,
  /// Full trial as structured JSON — all data, insights, and completeness.
  jsonExport,
}

extension ExportFormatDetails on ExportFormat {
  String get label {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Raw Data (CSV)';
      case ExportFormat.armHandoff:
        return 'Complete Data Package';
      case ExportFormat.zipBundle:
        return 'Data + Photos (ZIP)';
      case ExportFormat.pdfReport:
        return 'Field Report (PDF)';
      case ExportFormat.evidenceReport:
        return 'Evidence Report (PDF)';
      case ExportFormat.trialReport:
        return 'Trial Report (PDF)';
      case ExportFormat.armRatingShell:
        return 'Rating Sheet (Excel)';
      case ExportFormat.jsonExport:
        return 'Trial Data (JSON)';
    }
  }

  String get description {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Individual CSV files — observations, treatments, plots, applications, seeding, sessions, notes, and data dictionary';
      case ExportFormat.armHandoff:
        return 'Complete ZIP with all data files, column mapping guide, validation report, and photos — ready for import into external systems';
      case ExportFormat.zipBundle:
        return 'All CSV files, photos, and statistical analysis packaged in one ZIP';
      case ExportFormat.pdfReport:
        return 'Formatted report with treatment results, significance analysis, and per-plot detail — share with sponsors or archive';
      case ExportFormat.evidenceReport:
        return 'Provenance document with timestamps, amendments, outliers, device/rater certification, and completeness scoring — GLP-ready evidence';
      case ExportFormat.trialReport:
        return 'Structured trial report with site summary, treatments, applications, and assessment data tables — for the regulatory binder';
      case ExportFormat.armRatingShell:
        return 'Inject collected ratings back into the original protocol spreadsheet';
      case ExportFormat.jsonExport:
        return 'Complete trial data as structured JSON — all sessions, ratings, treatments, applications, insights, and completeness';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.flatCsv:
        return Icons.grid_on_outlined;
      case ExportFormat.armHandoff:
        return Icons.inventory_2_outlined;
      case ExportFormat.zipBundle:
        return Icons.folder_zip_outlined;
      case ExportFormat.pdfReport:
        return Icons.description_outlined;
      case ExportFormat.evidenceReport:
        return Icons.verified_outlined;
      case ExportFormat.trialReport:
        return Icons.article_outlined;
      case ExportFormat.armRatingShell:
        return Icons.table_view_outlined;
      case ExportFormat.jsonExport:
        return Icons.data_object_outlined;
    }
  }

  String get badge {
    switch (this) {
      case ExportFormat.armHandoff:
        return 'Recommended';
      case ExportFormat.evidenceReport:
        return 'GLP';
      case ExportFormat.trialReport:
        return 'Report';
      case ExportFormat.armRatingShell:
        return 'Protocol';
      default:
        return '';
    }
  }
}
