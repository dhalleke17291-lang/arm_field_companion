/// Report-ready data structure for standalone trial reports.
/// Assembled from existing repositories; no derived statistics.
/// Used by future PDF/report generation layer.
library;

/// Report layout/profile selection (PDF builder Pass 2).
enum ReportProfile {
  research,
  fieldSummary,
  interim,
  glpAudit,
  cooperator,
}

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
    this.sponsor,
    this.protocolNumber,
    this.investigatorName,
    this.cooperatorName,
    this.siteId,
    this.fieldName,
    this.county,
    this.stateProvince,
    this.country,
    this.latitude,
    this.longitude,
    this.elevationM,
    this.previousCrop,
    this.tillage,
    this.irrigated,
    this.soilSeries,
    this.soilTexture,
    this.organicMatterPct,
    this.soilPh,
    this.experimentalDesign,
    this.plotLengthM,
    this.plotWidthM,
    this.plotDimensions,
    this.plotRows,
    this.harvestDate,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? crop;
  final String? location;
  final String? season;
  final String status;
  final String workspaceType;

  // Identity
  final String? sponsor;
  final String? protocolNumber;
  final String? investigatorName;
  final String? cooperatorName;
  final String? siteId;
  final String? fieldName;

  // Location detail
  final String? county;
  final String? stateProvince;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? elevationM;

  // Site conditions
  final String? previousCrop;
  final String? tillage;
  final bool? irrigated;
  final String? soilSeries;
  final String? soilTexture;
  final double? organicMatterPct;
  final double? soilPh;

  // Plot layout
  final String? experimentalDesign;
  final double? plotLengthM;
  final double? plotWidthM;
  final String? plotDimensions;
  final int? plotRows;

  // Dates
  final DateTime? harvestDate;
  final DateTime? createdAt;
}

/// One product row within a treatment for report tables.
class TreatmentComponentSummary {
  const TreatmentComponentSummary({
    required this.productName,
    this.rate,
    this.rateUnit,
    this.formulationType,
    this.activeIngredientPct,
    this.manufacturer,
    this.applicationTiming,
  });

  final String productName;
  final String? rate;
  final String? rateUnit;
  final String? formulationType;
  final double? activeIngredientPct;
  final String? manufacturer;
  final String? applicationTiming;
}

/// Treatment summary for report.
class TreatmentReportSummary {
  const TreatmentReportSummary({
    required this.id,
    required this.code,
    required this.name,
    this.treatmentType,
    required this.componentCount,
    required this.components,
  });

  final int id;
  final String code;
  final String name;
  final String? treatmentType;
  final int componentCount;
  final List<TreatmentComponentSummary> components;
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
    this.variety,
    this.seedLotNumber,
    this.seedingRate,
    this.seedingRateUnit,
    this.plantingMethod,
    this.emergenceDate,
  });

  final DateTime seedingDate;
  final String status;
  final DateTime? completedAt;
  final String? operatorName;
  final String? variety;
  final String? seedLotNumber;
  final double? seedingRate;
  final String? seedingRateUnit;
  final String? plantingMethod;
  final DateTime? emergenceDate;
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
