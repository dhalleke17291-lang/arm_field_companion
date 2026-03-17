import 'dart:io';

// ignore_for_file: prefer_const_constructors
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';

/// Minimal assessment descriptor for validation (id + name).
/// Callers can map from Assessment or TrialAssessment + display name.
class AssessmentDefinition {
  const AssessmentDefinition({required this.id, required this.name});
  final int id;
  final String name;
}

class ExportValidationService {
  ExportValidationReport validate({
    required List<Plot> plots,
    required List<Assignment> assignments,
    required List<AssessmentDefinition> assessments,
    required List<RatingRecord> records,
    required List<Session> sessions,
    required List<Photo> photos,
  }) {
    final issues = <ValidationIssue>[];

    // 1. Missing plot labels
    for (final plot in plots) {
      if (plot.plotId.trim().isEmpty) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.error,
          category: 'Plot',
          message: 'Plot has no label — will not map to ARM',
          plotId: plot.id,
        ));
      }
    }

    // 2. Missing rep numbers
    for (final plot in plots) {
      if (plot.rep == null) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.warning,
          category: 'Plot',
          message: 'Plot ${plot.plotId} has no rep number',
          plotId: plot.id,
        ));
      }
    }

    // 3. Unassigned plots
    final assignedPlotIds = assignments.map((a) => a.plotId).toSet();
    for (final plot in plots) {
      if (!assignedPlotIds.contains(plot.id)) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.warning,
          category: 'Assignment',
          message: 'Plot ${plot.plotId} has no treatment assigned',
          plotId: plot.id,
        ));
      }
    }

    // 4. Empty assessment names
    for (final a in assessments) {
      if (a.name.trim().isEmpty) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.error,
          category: 'Assessment',
          message: 'Assessment has no name — will export as blank TRAIT',
        ));
      }
    }

    // 5. Records with no value and status Recorded
    for (final r in records) {
      if (r.isCurrent &&
          r.resultStatus == 'RECORDED' &&
          (r.numericValue == null &&
              (r.textValue == null || r.textValue!.trim().isEmpty))) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.warning,
          category: 'Rating',
          message: 'Plot ${r.plotPk} has status Recorded but no value',
          plotId: r.plotPk,
        ));
      }
    }

    // 6. Duplicate observations — same plot + assessment + session
    final seen = <String>{};
    for (final r in records.where((r) => r.isCurrent)) {
      final key = '${r.plotPk}|${r.assessmentId}|${r.sessionId}';
      if (!seen.add(key)) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.error,
          category: 'Rating',
          message:
              'Duplicate observation: plot ${r.plotPk}, same assessment and session',
          plotId: r.plotPk,
        ));
      }
    }

    // 7. Photos with missing files
    for (final photo in photos) {
      final file = File(photo.filePath);
      if (!file.existsSync()) {
        final fileName = p.basename(photo.filePath);
        issues.add(ValidationIssue(
          severity: IssueSeverity.warning,
          category: 'Photo',
          message: 'Photo file missing: $fileName',
        ));
      }
    }

    // 8. Sessions with no ratings
    final ratedSessionIds = records.map((r) => r.sessionId).toSet();
    for (final session in sessions) {
      if (!ratedSessionIds.contains(session.id)) {
        issues.add(ValidationIssue(
          severity: IssueSeverity.info,
          category: 'Session',
          message: 'Session ${session.name} has no ratings recorded',
        ));
      }
    }

    final errors =
        issues.where((i) => i.severity == IssueSeverity.error).length;
    final warnings =
        issues.where((i) => i.severity == IssueSeverity.warning).length;
    final infos = issues.where((i) => i.severity == IssueSeverity.info).length;

    return ExportValidationReport(
      issues: issues,
      errorCount: errors,
      warningCount: warnings,
      infoCount: infos,
      isClean: errors == 0,
    );
  }

  /// Converts the report to a CSV string for inclusion in the export package
  String toCsv(ExportValidationReport report) {
    final sb = StringBuffer();
    sb.writeln('severity,category,message,plot_id');
    for (final issue in report.issues) {
      sb.writeln([
        issue.severity.name,
        issue.category,
        '"${issue.message.replaceAll('"', '""')}"',
        issue.plotId?.toString() ?? '',
      ].join(','));
    }
    return sb.toString();
  }
}

enum IssueSeverity { error, warning, info }

class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.category,
    required this.message,
    this.plotId,
  });

  final IssueSeverity severity;
  final String category;
  final String message;
  final int? plotId;
}

class ExportValidationReport {
  const ExportValidationReport({
    required this.issues,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.isClean,
  });

  final List<ValidationIssue> issues;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final bool isClean;
}
