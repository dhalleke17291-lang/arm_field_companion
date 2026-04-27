/// Data models for the Field Evidence Report.
///
/// Each section corresponds to a page or section of the PDF evidence
/// appendix. Assembled from existing database tables — no new data
/// collection required.
library;

/// Trial identity card — page 1.
class EvidenceTrialIdentity {
  const EvidenceTrialIdentity({
    required this.name,
    this.protocolNumber,
    this.sponsor,
    this.investigatorName,
    this.cooperatorName,
    this.crop,
    this.location,
    this.season,
    this.siteId,
    this.fieldName,
    this.county,
    this.stateProvince,
    this.country,
    this.latitude,
    this.longitude,
    this.soilSeries,
    this.soilTexture,
    this.experimentalDesign,
    this.plotCount,
    this.treatmentCount,
    this.repCount,
    this.createdAt,
    required this.status,
    required this.workspaceType,
  });

  final String name;
  final String? protocolNumber;
  final String? sponsor;
  final String? investigatorName;
  final String? cooperatorName;
  final String? crop;
  final String? location;
  final String? season;
  final String? siteId;
  final String? fieldName;
  final String? county;
  final String? stateProvince;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? soilSeries;
  final String? soilTexture;
  final String? experimentalDesign;
  final int? plotCount;
  final int? treatmentCount;
  final int? repCount;
  final DateTime? createdAt;
  final String status;
  final String workspaceType;
}

/// A single event on the protocol timeline — page 2.
class TimelineEvent {
  const TimelineEvent({
    required this.label,
    required this.date,
    this.detail,
  });

  final String label;
  final DateTime date;
  final String? detail;
}

/// Treatment with full component details — page 3.
class EvidenceTreatment {
  const EvidenceTreatment({
    required this.code,
    required this.name,
    this.treatmentType,
    required this.components,
  });

  final String code;
  final String name;
  final String? treatmentType;
  final List<EvidenceTreatmentComponent> components;
}

class EvidenceTreatmentComponent {
  const EvidenceTreatmentComponent({
    required this.productName,
    this.rate,
    this.rateUnit,
    this.formulationType,
    this.applicationTiming,
  });

  final String productName;
  final String? rate;
  final String? rateUnit;
  final String? formulationType;
  final String? applicationTiming;
}

/// Seeding evidence — page 4.
class EvidenceSeeding {
  const EvidenceSeeding({
    required this.seedingDate,
    this.variety,
    this.seedLotNumber,
    this.seedingRate,
    this.seedingRateUnit,
    this.plantingMethod,
    this.operatorName,
    this.completedAt,
    this.emergenceDate,
    this.status,
  });

  final DateTime seedingDate;
  final String? variety;
  final String? seedLotNumber;
  final double? seedingRate;
  final String? seedingRateUnit;
  final String? plantingMethod;
  final String? operatorName;
  final DateTime? completedAt;
  final DateTime? emergenceDate;
  final String? status;
}

/// Application evidence — pages 5-6.
class EvidenceApplication {
  const EvidenceApplication({
    required this.applicationDate,
    this.productName,
    this.treatmentCode,
    this.rate,
    this.rateUnit,
    this.applicationMethod,
    this.equipmentUsed,
    this.operatorName,
    this.applicationTime,
    this.temperature,
    this.humidity,
    this.windSpeed,
    this.windDirection,
    this.waterVolume,
    this.waterVolumeUnit,
    this.status,
    this.appliedAt,
    this.growthStageCode,
  });

  final DateTime applicationDate;
  final String? productName;
  final String? treatmentCode;
  final String? rate;
  final String? rateUnit;
  final String? applicationMethod;
  final String? equipmentUsed;
  final String? operatorName;
  final String? applicationTime;
  final double? temperature;
  final double? humidity;
  final double? windSpeed;
  final String? windDirection;
  final double? waterVolume;
  final String? waterVolumeUnit;
  final String? status;
  final DateTime? appliedAt;
  final String? growthStageCode;
}

/// Session evidence row — page 7.
class EvidenceSession {
  const EvidenceSession({
    required this.id,
    required this.name,
    required this.sessionDateLocal,
    this.raterName,
    this.startedAt,
    this.endedAt,
    this.cropStageBbch,
    required this.plotsRated,
    required this.plotsFlagged,
    required this.plotsEdited,
    required this.assessmentCount,
    required this.totalRatings,
    this.weather,
    required this.status,
  });

  final int id;
  final String name;
  final String sessionDateLocal;
  final String? raterName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? cropStageBbch;
  final int plotsRated;
  final int plotsFlagged;
  final int plotsEdited;
  final int assessmentCount;
  final int totalRatings;
  final EvidenceWeather? weather;
  final String status;
}

/// Weather conditions.
class EvidenceWeather {
  const EvidenceWeather({
    this.temperature,
    this.temperatureUnit,
    this.humidity,
    this.windSpeed,
    this.windSpeedUnit,
    this.windDirection,
    this.cloudCover,
    this.precipitation,
    this.soilCondition,
    this.source,
  });

  final double? temperature;
  final String? temperatureUnit;
  final double? humidity;
  final double? windSpeed;
  final String? windSpeedUnit;
  final String? windDirection;
  final String? cloudCover;
  final String? precipitation;
  final String? soilCondition;
  final String? source;

  bool get hasData =>
      temperature != null ||
      humidity != null ||
      windSpeed != null ||
      cloudCover != null;
}

/// Data integrity evidence — pages 8-9.
class EvidenceDataIntegrity {
  const EvidenceDataIntegrity({
    required this.totalRatings,
    required this.ratingsWithGps,
    required this.ratingsWithConfidence,
    required this.ratingsWithTimestamp,
    required this.amendments,
    required this.corrections,
    required this.statusCounts,
    required this.deviceSummaries,
    required this.raterSummaries,
    required this.sessionTimestampDistributions,
  });

  final int totalRatings;
  final int ratingsWithGps;
  final int ratingsWithConfidence;
  final int ratingsWithTimestamp;
  final List<EvidenceAmendment> amendments;
  final List<EvidenceCorrection> corrections;

  /// Count of each resultStatus (RECORDED, VOID, NOT_OBSERVED, etc).
  final Map<String, int> statusCounts;

  /// Unique devices used.
  final List<EvidenceDevice> deviceSummaries;

  /// Unique raters.
  final List<EvidenceRater> raterSummaries;

  /// Per-session timestamp distributions.
  final List<SessionTimestampDistribution> sessionTimestampDistributions;
}

class EvidenceAmendment {
  const EvidenceAmendment({
    required this.plotLabel,
    required this.assessmentName,
    required this.sessionName,
    this.originalValue,
    this.newValue,
    this.reason,
    this.amendedBy,
    this.amendedAt,
  });

  final String plotLabel;
  final String assessmentName;
  final String sessionName;
  final String? originalValue;
  final String? newValue;
  final String? reason;
  final String? amendedBy;
  final DateTime? amendedAt;
}

class EvidenceCorrection {
  const EvidenceCorrection({
    required this.plotLabel,
    required this.sessionName,
    this.oldValue,
    this.newValue,
    this.oldStatus,
    this.newStatus,
    this.reason,
    this.correctedBy,
    this.correctedAt,
  });

  final String plotLabel;
  final String sessionName;
  final String? oldValue;
  final String? newValue;
  final String? oldStatus;
  final String? newStatus;
  final String? reason;
  final String? correctedBy;
  final DateTime? correctedAt;
}

class EvidenceDevice {
  const EvidenceDevice({
    required this.deviceInfo,
    required this.appVersion,
    required this.ratingCount,
    required this.sessionNames,
  });

  final String deviceInfo;
  final String appVersion;
  final int ratingCount;
  final List<String> sessionNames;
}

class EvidenceRater {
  const EvidenceRater({
    required this.name,
    required this.ratingCount,
    required this.sessionNames,
  });

  final String name;
  final int ratingCount;
  final List<String> sessionNames;
}

class SessionTimestampDistribution {
  const SessionTimestampDistribution({
    required this.sessionName,
    required this.sessionDate,
    this.firstRatingTime,
    this.lastRatingTime,
    required this.ratingCount,
    required this.durationMinutes,
    required this.ratingTimesMinutesFromStart,
  });

  final String sessionName;
  final String sessionDate;
  final String? firstRatingTime;
  final String? lastRatingTime;
  final int ratingCount;
  final int durationMinutes;

  /// Minutes from session start for each rating, for distribution analysis.
  final List<int> ratingTimesMinutesFromStart;
}

/// Outlier documentation — page 10.
class EvidenceOutlier {
  const EvidenceOutlier({
    required this.plotLabel,
    required this.treatmentCode,
    this.rep,
    required this.assessmentName,
    required this.value,
    required this.treatmentMean,
    required this.sdFromMean,
    this.raterName,
    this.confidence,
    required this.wasAmended,
  });

  final String plotLabel;
  final String treatmentCode;
  final int? rep;
  final String assessmentName;
  final double value;
  final double treatmentMean;
  final double sdFromMean;
  final String? raterName;
  final String? confidence;
  final bool wasAmended;
}

/// Evidence completeness score — final section.
class EvidenceCompletenessScore {
  const EvidenceCompletenessScore({
    required this.totalScore,
    required this.maxScore,
    required this.components,
  });

  final int totalScore;
  final int maxScore;
  final List<EvidenceScoreComponent> components;

  double get percentage => maxScore > 0 ? (totalScore / maxScore) * 100 : 0;
}

class EvidenceScoreComponent {
  const EvidenceScoreComponent({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.detail,
  });

  final String name;
  final int score;
  final int maxScore;
  final String detail;
}

/// Photo evidence entry.
class EvidencePhoto {
  const EvidencePhoto({
    required this.plotLabel,
    required this.sessionName,
    required this.sessionDate,
    required this.createdAt,
    this.caption,
    this.filePath,
    this.imageBytes,
  });

  final String plotLabel;
  final String sessionName;
  final String sessionDate;
  final DateTime createdAt;
  final String? caption;
  final String? filePath;

  /// JPEG bytes for PDF embedding; null if file could not be read.
  final List<int>? imageBytes;
}

/// Full assembled evidence report.
class EvidenceReportData {
  const EvidenceReportData({
    required this.identity,
    required this.timeline,
    required this.treatments,
    this.seeding,
    required this.applications,
    required this.sessions,
    required this.integrity,
    required this.outliers,
    required this.photos,
    required this.weatherRecords,
    required this.completenessScore,
    required this.generatedAt,
    required this.appVersion,
  });

  final EvidenceTrialIdentity identity;
  final List<TimelineEvent> timeline;
  final List<EvidenceTreatment> treatments;
  final EvidenceSeeding? seeding;
  final List<EvidenceApplication> applications;
  final List<EvidenceSession> sessions;
  final EvidenceDataIntegrity integrity;
  final List<EvidenceOutlier> outliers;
  final List<EvidencePhoto> photos;
  final List<EvidenceWeather> weatherRecords;
  final EvidenceCompletenessScore completenessScore;
  final DateTime generatedAt;
  final String appVersion;
}
