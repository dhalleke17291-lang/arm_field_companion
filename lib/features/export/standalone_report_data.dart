/// Report-ready data structure for standalone trial reports.
/// Assembled from existing repositories; no derived statistics.
/// Used by future PDF/report generation layer.
library;

/// Trial-level summary for report header.
class TrialReportSummary {
  const TrialReportSummary({
    required this.id,
    required this.name,
    this.crop,
    this.location,
    this.season,
    required this.status,
    required this.workspaceType,
  });

  final int id;
  final String name;
  final String? crop;
  final String? location;
  final String? season;
  final String status;
  final String workspaceType;
}

/// Treatment summary for report.
class TreatmentReportSummary {
  const TreatmentReportSummary({
    required this.id,
    required this.code,
    required this.name,
    this.treatmentType,
    required this.componentCount,
  });

  final int id;
  final String code;
  final String name;
  final String? treatmentType;
  final int componentCount;
}

/// Plot summary for report.
class PlotReportSummary {
  const PlotReportSummary({
    required this.plotPk,
    required this.plotId,
    this.plotSortIndex,
    this.rep,
    this.treatmentId,
    this.treatmentCode,
  });

  final int plotPk;
  final String plotId;
  final int? plotSortIndex;
  final int? rep;
  final int? treatmentId;
  final String? treatmentCode;
}

/// Session summary for report.
class SessionReportSummary {
  const SessionReportSummary({
    required this.id,
    required this.name,
    required this.sessionDateLocal,
    required this.status,
  });

  final int id;
  final String name;
  final String sessionDateLocal;
  final String status;
}

/// Application event summary for report.
class ApplicationReportSummary {
  const ApplicationReportSummary({
    required this.id,
    required this.applicationDate,
    this.productName,
    required this.status,
    this.appliedAt,
  });

  final String id;
  final DateTime applicationDate;
  final String? productName;
  final String status;
  final DateTime? appliedAt;
}

/// Seeding event summary for standalone report.
class SeedingReportSummary {
  const SeedingReportSummary({
    required this.seedingDate,
    required this.status,
    this.completedAt,
    this.operatorName,
  });

  final DateTime seedingDate;
  final String status;
  final DateTime? completedAt;
  final String? operatorName;
}

/// Applications section summary.
class ApplicationsReportSummary {
  const ApplicationsReportSummary({
    required this.count,
    required this.events,
  });

  final int count;
  final List<ApplicationReportSummary> events;
}

/// Photo count only; structure not yet safely available in this layer.
class PhotoReportSummary {
  const PhotoReportSummary({required this.count});

  final int count;
}

/// One per-plot assessment result row for the report.
class RatingResultRow {
  final String plotId;
  final int rep;
  final String treatmentCode;
  final String assessmentName;
  final String unit;
  final String value;
  final String resultStatus;
  /// Result direction for numeric summary: higherBetter | lowerBetter | neutral.
  final String resultDirection;

  const RatingResultRow({
    required this.plotId,
    required this.rep,
    required this.treatmentCode,
    required this.assessmentName,
    required this.unit,
    required this.value,
    required this.resultStatus,
    this.resultDirection = 'neutral',
  });
}

/// Full assembled report data for a trial.
class StandaloneReportData {
  const StandaloneReportData({
    required this.trial,
    required this.treatments,
    required this.plots,
    required this.sessions,
    required this.applications,
    required this.photoCount,
    this.ratings = const [],
    this.seeding,
  });

  final TrialReportSummary trial;
  final List<TreatmentReportSummary> treatments;
  final List<PlotReportSummary> plots;
  final List<SessionReportSummary> sessions;
  final ApplicationsReportSummary applications;
  final PhotoReportSummary photoCount;
  final List<RatingResultRow> ratings;
  final SeedingReportSummary? seeding;
}
