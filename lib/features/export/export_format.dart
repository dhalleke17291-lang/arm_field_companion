import 'package:flutter/material.dart';

enum ExportFormat {
  flatCsv,
  armHandoff,
  // zipBundle removed — produced identical content to armHandoff
  // via the same builder. Mode availability is controlled by
  // armHandoff's existing mode gate.
  pdfReport,

  /// Field Evidence Report — provenance document with timestamps, amendments,
  /// outliers, device/rater certification, and completeness scoring.
  evidenceReport,

  /// Trial Report PDF — structured document for the regulatory binder.
  /// Site summary, treatments, design, applications, assessment data tables.
  trialReport,

  /// Trial Defensibility Summary — quality flags, results, decisions, and audit trail.
  trialDefensibility,

  /// Excel rating shell for imported protocol trials; handled by [ExportArmRatingShellUseCase].
  /// Listed on the trial export sheet only when the trial is ARM-linked.
  armRatingShell,

  // jsonExport removed — was an internal proprietary format with no
  // declared consumer, no external schema, and stale schema version
  // (was at v54, app is now v82). Future interoperability export
  // (ADAPT, John Deere Operations Center, ISOXML) should be built
  // against a real external standard. Tier 1/2 feature, defer.
}

extension ExportFormatDetails on ExportFormat {
  String get label {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Raw Data (CSV)';
      case ExportFormat.armHandoff:
        return 'ARM Handoff Package';
      case ExportFormat.pdfReport:
        return 'Trial Results Summary';
      case ExportFormat.evidenceReport:
        // Trial Evidence Record is not the Trial Field Execution Report.
        // It is a provenance/audit appendix. Cognition layer content
        // (Evidence Arc, CTQ readiness, open signals, ARM divergence,
        // Interpretation Boundary) belongs in Session FER only.
        // If a Trial-scope FER is added later, it should aggregate those
        // cognition providers at trial scope — do not repurpose this document.
        return 'Trial Evidence Record';
      case ExportFormat.trialReport:
        return 'Trial Report';
      case ExportFormat.trialDefensibility:
        return 'Trial Defensibility Summary';
      case ExportFormat.armRatingShell:
        return 'Rating Sheet (Excel)';
    }
  }

  String get description {
    switch (this) {
      case ExportFormat.flatCsv:
        return 'Individual CSV files — observations, treatments, plots, applications, seeding, sessions, notes, and data dictionary';
      case ExportFormat.armHandoff:
        return 'ARM-compatible ZIP containing ratings, photos, manifest, and weather for round-trip to GDM ARM.';
      case ExportFormat.pdfReport:
        return 'Statistical results report with treatment means, ANOVA, directional summary, and raw plot data.';
      case ExportFormat.evidenceReport:
        return 'Trial-wide provenance, corrections, outliers, timestamps, weather, photos, and rater/device records for audit and regulatory review.';
      case ExportFormat.trialReport:
        return 'Regulatory-formatted trial document with numbered sections, completeness summary, crop injury log, field notes, and conclusions.';
      case ExportFormat.trialDefensibility:
        return 'PDF with quality flags, results, decisions and audit trail';
      case ExportFormat.armRatingShell:
        return 'Inject collected ratings back into the original protocol spreadsheet';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.flatCsv:
        return Icons.grid_on_outlined;
      case ExportFormat.armHandoff:
        return Icons.inventory_2_outlined;
      case ExportFormat.pdfReport:
        return Icons.description_outlined;
      case ExportFormat.evidenceReport:
        return Icons.verified_outlined;
      case ExportFormat.trialReport:
        return Icons.article_outlined;
      case ExportFormat.trialDefensibility:
        return Icons.verified_outlined;
      case ExportFormat.armRatingShell:
        return Icons.table_view_outlined;
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
      case ExportFormat.trialDefensibility:
        return 'Summary';
      case ExportFormat.armRatingShell:
        return 'Protocol';
      default:
        return '';
    }
  }
}
