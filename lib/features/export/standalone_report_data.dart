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
  });

  final String id;
  final DateTime applicationDate;
  final String? productName;
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

/// Full assembled report data for a trial.
class StandaloneReportData {
  const StandaloneReportData({
    required this.trial,
    required this.treatments,
    required this.plots,
    required this.sessions,
    required this.applications,
    required this.photoCount,
  });

  final TrialReportSummary trial;
  final List<TreatmentReportSummary> treatments;
  final List<PlotReportSummary> plots;
  final List<SessionReportSummary> sessions;
  final ApplicationsReportSummary applications;
  final PhotoReportSummary photoCount;
}
