import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'dart:io';

part 'app_database.g.dart';

/// Local user identity (identity only; authorization layered later).
/// role_key: stable code (technician, researcher, manager, admin).
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get displayName => text().withLength(min: 1, max: 255)();
  TextColumn get initials => text().nullable()();
  TextColumn get roleKey => text().withDefault(const Constant('technician'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get pinEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Trials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get crop => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get season => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Plot dimensions (e.g. "10 m × 2 m"). Trial-level default.
  TextColumn get plotDimensions => text().nullable()();

  /// Number of rows per plot. Trial-level default.
  IntColumn get plotRows => integer().nullable()();

  /// Spacing between plots (e.g. "0.5 m"). Trial-level default.
  TextColumn get plotSpacing => text().nullable()();

  // --- Trial setup (ARM protocol / site) ---
  TextColumn get sponsor => text().nullable()();
  TextColumn get protocolNumber => text().nullable()();
  TextColumn get investigatorName => text().nullable()();
  TextColumn get cooperatorName => text().nullable()();
  TextColumn get siteId => text().nullable()();
  TextColumn get fieldName => text().nullable()();
  TextColumn get county => text().nullable()();
  TextColumn get stateProvince => text().nullable()();
  TextColumn get country => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get elevationM => real().nullable()();
  TextColumn get experimentalDesign => text().nullable()();
  RealColumn get plotLengthM => real().nullable()();
  RealColumn get plotWidthM => real().nullable()();
  RealColumn get alleyLengthM => real().nullable()();
  TextColumn get previousCrop => text().nullable()();
  TextColumn get tillage => text().nullable()();
  BoolColumn get irrigated => boolean().nullable()();
  TextColumn get soilSeries => text().nullable()();
  TextColumn get soilTexture => text().nullable()();
  RealColumn get organicMatterPct => real().nullable()();
  RealColumn get soilPh => real().nullable()();
  DateTimeColumn get harvestDate => dateTime().nullable()();
  TextColumn get studyType => text().nullable()();

  /// Workspace type: variety | efficacy | glp | standalone
  TextColumn get workspaceType =>
      text().withDefault(const Constant('efficacy'))();

  /// Regulatory region for biological calibration.
  /// 'eppo_eu' and 'pmra_canada' are current values. Open text — new regions
  /// are additive without a schema change.
  TextColumn get region => text().withDefault(const Constant('eppo_eu'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();

  /// FK to shared site record. Nullable — trials without a linked site
  /// still store location/soil fields directly (denormalized copies).
  IntColumn get siteRefId =>
      integer().references(Sites, #id).nullable()();

  /// Cultivar / variety name (distinct from [crop] which is species).
  TextColumn get cultivar => text().nullable()();

  /// Row spacing in cm. Combined with [plantSpacingCm] gives crop density.
  RealColumn get rowSpacingCm => real().nullable()();

  /// Plant spacing within row, in cm.
  RealColumn get plantSpacingCm => real().nullable()();

  /// Whether the trial follows Good Experimental Practice guidelines.
  BoolColumn get gepComplianceFlag => boolean().nullable()();

  // Future field-geometry metadata (v78). GPS/satellite work not started.
  RealColumn get fieldOrientationDegrees => real().nullable()();
  TextColumn get fieldAnchorType => text().nullable()();
}

/// Per-trial ARM shell linkage and import metadata (Phase 0b).
///
/// Standalone trials have **no row** here. ARM-linked or imported trials have
/// exactly one row keyed by [trialId]. See `docs/ARM_SEPARATION.md`.
class ArmTrialMetadata extends Table {
  IntColumn get trialId => integer().references(Trials, #id)();

  BoolColumn get isArmLinked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get armImportedAt => dateTime().nullable()();
  TextColumn get armSourceFile => text().nullable()();
  TextColumn get armVersion => text().nullable()();

  /// Session used for ARM import ratings; preferred for Rating Shell export.
  /// Plain int (no FK) to avoid Drift circular ref: sessions already reference trials.
  IntColumn get armImportSessionId => integer().nullable()();

  /// Last ARM Rating Shell (.xlsx) path applied from the shell link workflow.
  TextColumn get armLinkedShellPath => text().nullable()();

  /// When [armLinkedShellPath] was last applied.
  DateTimeColumn get armLinkedShellAt => dateTime().nullable()();

  /// Internal app path where the shell file is stored (copied at import/link).
  TextColumn get shellInternalPath => text().nullable()();

  /// Free-text from the shell **Comments** sheet (`ECM` row, column B).
  TextColumn get shellCommentsSheet => text().nullable()();

  @override
  Set<Column> get primaryKey => {trialId};
}

/// Shared site record. Contains location, soil, and management fields
/// that are properties of the physical field, not of any individual trial.
/// One trial = one site record (no dedup in v1). Future: GPS proximity
/// matching for site history across seasons.
class Sites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get elevationM => real().nullable()();
  TextColumn get soilSeries => text().nullable()();
  TextColumn get soilTexture => text().nullable()();
  RealColumn get soilPh => real().nullable()();
  RealColumn get organicMatterPct => real().nullable()();
  TextColumn get previousCrop => text().nullable()();
  TextColumn get tillage => text().nullable()();
  BoolColumn get irrigated => boolean().nullable()();
  TextColumn get fieldName => text().nullable()();
  TextColumn get county => text().nullable()();
  TextColumn get stateProvince => text().nullable()();
  TextColumn get country => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get modifiedAt => dateTime().withDefault(currentDateAndTime)();
}

class Treatments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get code => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get treatmentType => text().nullable()();
  TextColumn get timingCode => text().nullable()();
  TextColumn get eppoCode => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  IntColumn get lastEditedByUserId =>
      integer().nullable().references(Users, #id)();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();
}

class TreatmentComponents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get treatmentId => integer().references(Treatments, #id)();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get productName => text().withLength(min: 1, max: 255)();
  RealColumn get rate => real().nullable()();
  TextColumn get rateUnit => text().nullable()();
  TextColumn get applicationTiming => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get activeIngredientPct => real().nullable()();
  TextColumn get formulationType => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get registrationNumber => text().nullable()();
  TextColumn get eppoCode => text().nullable()();

  /// Active ingredient common name (e.g. "glyphosate").
  TextColumn get activeIngredientName => text().nullable()();
  /// AI concentration (g/L or g/kg). Paired with [aiConcentrationUnit].
  RealColumn get aiConcentration => real().nullable()();
  TextColumn get aiConcentrationUnit => text().nullable()();
  /// Maximum legal rate from the product label, separate from trial rate.
  RealColumn get labelRate => real().nullable()();
  TextColumn get labelRateUnit => text().nullable()();
  /// Distinguishes test product from reference standard.
  BoolColumn get isTestProduct =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  IntColumn get lastEditedByUserId =>
      integer().nullable().references(Users, #id)();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();
}

class Assessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get dataType => text().withDefault(const Constant('numeric'))();
  RealColumn get minValue => real().nullable()();
  RealColumn get maxValue => real().nullable()();
  TextColumn get unit => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Hidden master library of assessment templates (ARM/GDM-style). Not shown in session UI until selected for a trial.
class AssessmentDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get category => text().withLength(min: 1, max: 50)();
  TextColumn get dataType => text().withDefault(const Constant('numeric'))();
  TextColumn get unit => text().nullable()();
  RealColumn get scaleMin => real().nullable()();
  RealColumn get scaleMax => real().nullable()();
  TextColumn get target => text().nullable()();
  TextColumn get method => text().nullable()();
  TextColumn get defaultInstructions => text().nullable()();
  TextColumn get timingType => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Rating date string from CSV header (e.g. "1-Jul-26"). Misnamed — stores
  /// date, not timing code. Technical debt: do not rename in this sprint.
  TextColumn get timingCode => text().nullable()();
  IntColumn get daysAfterTreatment => integer().nullable()();
  TextColumn get assessmentMethod => text().nullable()();
  RealColumn get validMin => real().nullable()();
  RealColumn get validMax => real().nullable()();
  TextColumn get eppoCode => text().nullable()();
  /// Plant part assessed (PLANT, LEAF3, etc.) — populated from shell Part Rated.
  TextColumn get cropPart => text().nullable()();
  TextColumn get timingDescription => text().nullable()();
  TextColumn get resultDirection =>
      text().withDefault(const Constant('neutral'))();
  /// Application timing code (A1, A3, A6, A9, AA) from shell row 42 (0-based).
  TextColumn get appTimingCode => text().nullable()();
  /// Treatment-evaluation interval (e.g. "-28 DA-A") from shell row 42 (0-based).
  TextColumn get trtEvalInterval => text().nullable()();
  /// Collect basis (PLOT, etc.) from shell row 23 (0-based).
  TextColumn get collectBasis => text().nullable()();
}

/// Trial-specific selection from library. Sessions only show assessments enabled here (or legacy Assessments).
class TrialAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get assessmentDefinitionId =>
      integer().references(AssessmentDefinitions, #id)();
  TextColumn get displayNameOverride => text().nullable()();
  BoolColumn get required => boolean().withDefault(const Constant(false))();
  BoolColumn get selectedFromProtocol =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get selectedManually =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultInSessions =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get timingMode => text().nullable()();
  IntColumn get daysAfterPlanting => integer().nullable()();
  IntColumn get daysAfterTreatment => integer().nullable()();
  TextColumn get growthStage => text().nullable()();
  TextColumn get methodOverride => text().nullable()();
  TextColumn get instructionOverride => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get legacyAssessmentId =>
      integer().references(Assessments, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get pestName => text().nullable()();
  TextColumn get eppoCodeLocal => text().nullable()();
  TextColumn get bbchScale => text().nullable()();
  TextColumn get cropStageAtAssessment => text().nullable()();

  // v60 (Phase 0b-ta contract phase) moved the per-column ARM anchor fields
  // (armImportColumnIndex, armShellColumnId, armShellRatingDate,
  // armColumnIdInteger) to arm_assessment_metadata. v61 (Unit 5d) finished
  // the cutover by dropping pestCode / seName / seDescription / armRatingType
  // from trial_assessments; those fields now live only on
  // arm_assessment_metadata.
}

class Plots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get plotId => text().withLength(min: 1, max: 50)();
  IntColumn get plotSortIndex => integer().nullable()();
  IntColumn get rep => integer().nullable()();
  IntColumn get treatmentId =>
      integer().references(Treatments, #id).nullable()();
  TextColumn get row => text().nullable()();
  TextColumn get column => text().nullable()();
  IntColumn get fieldRow => integer().nullable()();
  IntColumn get fieldColumn => integer().nullable()();

  /// Assignment provenance: 'imported' | 'manual' | null (unknown).
  TextColumn get assignmentSource => text().nullable()();
  DateTimeColumn get assignmentUpdatedAt => dateTime().nullable()();

  RealColumn get plotLengthM => real().nullable()();
  RealColumn get plotWidthM => real().nullable()();
  RealColumn get plotAreaM2 => real().nullable()();
  RealColumn get harvestLengthM => real().nullable()();
  RealColumn get harvestWidthM => real().nullable()();
  RealColumn get harvestAreaM2 => real().nullable()();
  TextColumn get plotDirection => text().nullable()();
  TextColumn get soilSeries => text().nullable()();
  TextColumn get plotNotes => text().nullable()();

  /// Field layout: non-data / border plot.
  /// v2: excluded from rating queue by default; display + editing unchanged in Plots tab.
  BoolColumn get isGuardRow => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();

  BoolColumn get excludeFromAnalysis =>
      boolean().withDefault(const Constant(false))();
  TextColumn get exclusionReason => text().nullable()();
  TextColumn get damageType => text().nullable()();

  /// Canonical ARM plot number (matches Rating Shell plot column); nullable for non-ARM plots.
  IntColumn get armPlotNumber => integer().nullable()();

  /// Index into source ARM CSV data rows for this plot row (import alignment).
  IntColumn get armImportDataRowIndex => integer().nullable()();
}

/// Protocol-to-field mapping: which treatment is assigned to which plot (ARM first-class entity).
/// One row per plot per trial. Resolution: Plot → Assignment → Treatment.
class Assignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotId => integer().references(Plots, #id)();
  IntColumn get treatmentId =>
      integer().references(Treatments, #id).nullable()();
  IntColumn get replication => integer().nullable()();
  IntColumn get block => integer().nullable()();
  IntColumn get range => integer().nullable()();
  IntColumn get column => integer().nullable()();
  IntColumn get position => integer().nullable()();
  BoolColumn get isCheck => boolean().nullable()();
  BoolColumn get isControl => boolean().nullable()();
  TextColumn get assignmentSource => text().nullable()();
  DateTimeColumn get assignedAt => dateTime().nullable()();
  IntColumn get assignedBy => integer().references(Users, #id).nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get sessionDateLocal => text()();
  TextColumn get raterName => text().nullable()();
  IntColumn get createdByUserId =>
      integer().references(Users, #id).nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();

  /// Optional BBCH growth stage (0–99) at rating session; null if not recorded.
  IntColumn get cropStageBbch => integer().nullable()();

  /// Crop injury / phytotoxicity status recorded at session close.
  /// Values: 'none_observed', 'symptoms_observed', 'not_assessed', or null (not yet recorded).
  TextColumn get cropInjuryStatus => text().nullable()();

  /// Free-text description when cropInjuryStatus = 'symptoms_observed'.
  TextColumn get cropInjuryNotes => text().nullable()();

  /// JSON array of photo IDs attached to the crop injury observation.
  TextColumn get cropInjuryPhotoIds => text().nullable()();
}

class SessionAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
  IntColumn get trialAssessmentId =>
      integer().references(TrialAssessments, #id).nullable()();

  /// User-defined order for rating flow (0, 1, 2, …). Same sequence applies to every plot.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RatingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
  IntColumn get trialAssessmentId =>
      integer().references(TrialAssessments, #id).nullable()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get subUnitId => integer().nullable()();
  TextColumn get resultStatus =>
      text().withDefault(const Constant('RECORDED'))();
  RealColumn get numericValue => real().nullable()();
  TextColumn get textValue => text().nullable()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(true))();
  IntColumn get previousId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
  // Provenance (nullable for legacy rows)
  TextColumn get createdAppVersion => text().nullable()();
  TextColumn get createdDeviceInfo => text().nullable()();
  RealColumn get capturedLatitude => real().nullable()();
  RealColumn get capturedLongitude => real().nullable()();

  /// Local time of rating as HH:mm.
  TextColumn get ratingTime => text().nullable()();
  TextColumn get ratingMethod => text().nullable()();
  /// certain | uncertain | estimated
  TextColumn get confidence => text().nullable()();
  BoolColumn get amended => boolean().withDefault(const Constant(false))();
  TextColumn get originalValue => text().nullable()();
  TextColumn get amendmentReason => text().nullable()();
  TextColumn get amendedBy => text().nullable()();
  DateTimeColumn get amendedAt => dateTime().nullable()();
  IntColumn get lastEditedByUserId =>
      integer().nullable().references(Users, #id)();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
}

/// Immutable correction records; original rating record is never overwritten.
class RatingCorrections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ratingId => integer().references(RatingRecords, #id)();
  RealColumn get oldNumericValue => real().nullable()();
  RealColumn get newNumericValue => real().nullable()();
  TextColumn get oldTextValue => text().nullable()();
  TextColumn get newTextValue => text().nullable()();
  TextColumn get oldResultStatus => text()();
  TextColumn get newResultStatus => text()();
  TextColumn get reason => text()();
  IntColumn get correctedByUserId =>
      integer().references(Users, #id).nullable()();
  DateTimeColumn get correctedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get sessionId => integer().references(Sessions, #id).nullable()();
  IntColumn get plotPk => integer().references(Plots, #id).nullable()();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().nullable().references(Plots, #id)();
  IntColumn get sessionId => integer().nullable().references(Sessions, #id)();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get updatedBy => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
}

class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get filePath => text()();
  TextColumn get tempPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('final'))();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Assessment linked to this photo (photo-anchored rating).
  IntColumn get assessmentId =>
      integer().nullable().references(Assessments, #id)();

  /// Rating value at the time the photo was captured.
  RealColumn get ratingValue => real().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
}

class PlotFlags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get flagType => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
}

class DeviationFlags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id).nullable()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get ratingRecordId =>
      integer().references(RatingRecords, #id).nullable()();
  TextColumn get deviationType => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
}

class SeedingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id).nullable()();
  IntColumn get sessionId => integer().references(Sessions, #id).nullable()();
  DateTimeColumn get seedingDate => dateTime()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get comments => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ProtocolSeedingFields extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get fieldKey => text()();
  TextColumn get fieldLabel => text()();
  TextColumn get fieldType => text()();
  TextColumn get unit => text().nullable()();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}

class SeedingFieldValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seedingRecordId => integer().references(SeedingRecords, #id)();
  TextColumn get fieldKey => text()();
  TextColumn get fieldLabel => text()();
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNumber => real().nullable()();
  TextColumn get valueDate => text().nullable()();
  BoolColumn get valueBool => boolean().nullable()();
  TextColumn get unit => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Planned application slots (protocol). No Dart repository writes this table today;
/// [ApplicationEvents.applicationSlotId] is optional. New installs create the table via `createAll` in `onCreate`.
class ApplicationSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get slotCode => text().withLength(min: 1, max: 20)();
  TextColumn get timingLabel => text().nullable()();
  TextColumn get methodDefault => text().withDefault(const Constant('spray'))();
  TextColumn get plannedGrowthStage => text().nullable()();
  TextColumn get protocolNotes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Legacy int-key application events. UI-reachable via [applicationsForTrialProvider]
/// → Plots tab (`plots_tab.dart` application selector / overlays). Canonical path:
/// [TrialApplicationEvents] + [trialApplicationsForTrialProvider].
class ApplicationEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get sessionId => integer().references(Sessions, #id).nullable()();
  IntColumn get applicationSlotId =>
      integer().references(ApplicationSlots, #id).nullable()();
  IntColumn get applicationNumber => integer().withDefault(const Constant(1))();
  TextColumn get timingLabel => text().nullable()();
  TextColumn get method => text().withDefault(const Constant('spray'))();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  DateTimeColumn get applicationDate => dateTime()();
  TextColumn get growthStage => text().nullable()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get equipment => text().nullable()();
  TextColumn get weather => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get partialFlag => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-plot application coverage for a legacy [ApplicationEvents] row. Used from
/// [ApplicationRepository] when Plots tab loads plot records for a selected event.
class ApplicationPlotRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(ApplicationEvents, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get status => text().withDefault(const Constant('applied'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AuditEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id).nullable()();
  IntColumn get sessionId => integer().references(Sessions, #id).nullable()();
  IntColumn get plotPk => integer().references(Plots, #id).nullable()();
  TextColumn get eventType => text()();
  TextColumn get description => text()();
  TextColumn get performedBy => text().nullable()();
  IntColumn get performedByUserId =>
      integer().references(Users, #id).nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().nullable()();
}

class ImportEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get fileName => text()();
  TextColumn get savedFilePath => text().nullable()();
  TextColumn get status => text()();
  IntColumn get rowsImported => integer().withDefault(const Constant(0))();
  IntColumn get rowsSkipped => integer().withDefault(const Constant(0))();
  TextColumn get warnings => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One seeding event per trial (enforced by unique trial_id). Upsert via insertOnConflictUpdate.
class SeedingEvents extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  IntColumn get trialId => integer().references(Trials, #id)();
  DateTimeColumn get seedingDate => dateTime()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get seedLotNumber => text().nullable()();
  RealColumn get seedingRate => real().nullable()();
  TextColumn get seedingRateUnit => text().nullable()();
  RealColumn get seedingDepth => real().nullable()();
  RealColumn get rowSpacing => real().nullable()();
  TextColumn get equipmentUsed => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get variety => text().nullable()();
  TextColumn get seedTreatment => text().nullable()();
  RealColumn get germinationPct => real().nullable()();
  DateTimeColumn get emergenceDate => dateTime().nullable()();
  RealColumn get emergencePct => real().nullable()();
  TextColumn get plantingMethod => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get lastEditedByUserId =>
      integer().nullable().references(Users, #id)();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  // Weather conditions recorded at seeding time
  RealColumn get temperatureC => real().nullable()();
  RealColumn get humidityPct => real().nullable()();
  RealColumn get windSpeedKmh => real().nullable()();
  TextColumn get windDirection => text().nullable()();
  RealColumn get cloudCoverPct => real().nullable()();
  TextColumn get precipitation => text().nullable()();
  RealColumn get precipitationMm => real().nullable()();
  TextColumn get soilMoisture => text().nullable()();
  RealColumn get soilTemperature => real().nullable()();
  DateTimeColumn get conditionsRecordedAt => dateTime().nullable()();
  // GPS captured at time of seeding operation (immutable after completion)
  RealColumn get capturedLatitude => real().nullable()();
  RealColumn get capturedLongitude => real().nullable()();
  DateTimeColumn get locationCapturedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Application events per trial (multiple per trial). FK types match Trials.id and Treatments.id (IntColumn).
/// days_after_seeding is never stored — derived at read time from application_date minus seeding date.
class TrialApplicationEvents extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get treatmentId =>
      integer().references(Treatments, #id).nullable()();
  DateTimeColumn get applicationDate => dateTime()();
  TextColumn get growthStageCode => text().nullable()();
  TextColumn get operatorName => text().nullable()();
  TextColumn get equipmentUsed => text().nullable()();
  TextColumn get productName => text().nullable()();
  RealColumn get rate => real().nullable()();
  TextColumn get rateUnit => text().nullable()();
  RealColumn get waterVolume => real().nullable()();
  RealColumn get windSpeed => real().nullable()();
  TextColumn get windDirection => text().nullable()();
  RealColumn get temperature => real().nullable()();
  RealColumn get humidity => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get applicationTime => text().nullable()();
  TextColumn get applicationMethod => text().nullable()();
  TextColumn get nozzleType => text().nullable()();
  RealColumn get nozzleSpacingCm => real().nullable()();
  RealColumn get operatingPressure => real().nullable()();
  TextColumn get pressureUnit => text().nullable()();
  RealColumn get groundSpeed => real().nullable()();
  TextColumn get speedUnit => text().nullable()();
  TextColumn get adjuvantName => text().nullable()();
  RealColumn get adjuvantRate => real().nullable()();
  TextColumn get adjuvantRateUnit => text().nullable()();
  RealColumn get spraySolutionPh => real().nullable()();
  TextColumn get waterVolumeUnit => text().nullable()();
  RealColumn get cloudCoverPct => real().nullable()();
  TextColumn get soilMoisture => text().nullable()();
  RealColumn get soilTemperature => real().nullable()();
  TextColumn get soilTempUnit => text().nullable()();
  RealColumn get soilDepth => real().nullable()();
  TextColumn get soilDepthUnit => text().nullable()();
  RealColumn get treatedArea => real().nullable()();
  TextColumn get treatedAreaUnit => text().nullable()();
  TextColumn get plotsTreated => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get appliedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get lastEditedByUserId =>
      integer().nullable().references(Users, #id)();
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  // Session lifecycle fields (Sprint 3).
  TextColumn get precipitation => text().nullable()();
  RealColumn get precipitationMm => real().nullable()();
  DateTimeColumn get conditionsRecordedAt => dateTime().nullable()();
  RealColumn get boomHeightCm => real().nullable()();
  TextColumn get sessionName => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  /// Total product mixed in the tank (g, mL, or other unit matching rate).
  RealColumn get totalProductMixed => real().nullable()();
  /// Total area actually sprayed (hectares).
  RealColumn get totalAreaSprayedHa => real().nullable()();

  RealColumn get capturedLatitude => real().nullable()();
  RealColumn get capturedLongitude => real().nullable()();
  DateTimeColumn get locationCapturedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tank-mix products per trial application event (trial_application_events.id is TEXT).
class TrialApplicationProducts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trialApplicationEventId =>
      text().references(TrialApplicationEvents, #id,
          onDelete: KeyAction.cascade)();
  TextColumn get productName => text()();
  RealColumn get rate => real().nullable()();
  TextColumn get rateUnit => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // Plan-vs-actual deviation fields (Sprint 3).
  TextColumn get plannedProduct => text().nullable()();
  RealColumn get plannedRate => real().nullable()();
  TextColumn get plannedRateUnit => text().nullable()();
  BoolColumn get deviationFlag =>
      boolean().withDefault(const Constant(false))();
  TextColumn get deviationNotes => text().nullable()();
  TextColumn get lotCode => text().nullable().named('lot_code')();
}

/// Junction table linking application events to individual plots.
/// Replaces the comma-separated [TrialApplicationEvents.plotsTreated] TEXT
/// field for structured queries. The TEXT field is kept as a denormalized
/// cache alongside this table during the transition period.
class ApplicationPlotAssignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get applicationEventId =>
      text().references(TrialApplicationEvents, #id,
          onDelete: KeyAction.cascade)();
  TextColumn get plotLabel => text()();
  IntColumn get plotId => integer().references(Plots, #id).nullable()();
}

class ImportSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get sourceFile => text()();
  TextColumn get sourceRoute => text()();
  TextColumn get armVersion => text().nullable()();
  TextColumn get rawHeaders => text()();
  TextColumn get columnOrder => text()();
  TextColumn get rowTypePatterns => text()();
  IntColumn get plotCount => integer()();
  IntColumn get treatmentCount => integer()();
  IntColumn get assessmentCount => integer()();
  TextColumn get identityColumns => text()();
  TextColumn get assessmentTokens => text()();
  TextColumn get treatmentTokens => text()();
  TextColumn get plotTokens => text()();
  TextColumn get unknownPatterns => text()();
  BoolColumn get hasSubsamples => boolean().withDefault(const Constant(false))();
  BoolColumn get hasMultiApplication =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hasSparseData => boolean().withDefault(const Constant(false))();
  BoolColumn get hasRepeatedCodes =>
      boolean().withDefault(const Constant(false))();
  TextColumn get rawFileChecksum => text()();
  DateTimeColumn get capturedAt => dateTime()();
}

class CompatibilityProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get snapshotId => integer().references(ImportSnapshots, #id)();
  TextColumn get exportRoute => text()();
  TextColumn get columnMap => text()();
  TextColumn get plotMap => text()();
  TextColumn get treatmentMap => text()();
  IntColumn get dataStartRow => integer()();
  IntColumn get headerEndRow => integer()();
  TextColumn get identityRowMarkers => text()();
  TextColumn get columnOrderOnExport => text()();
  TextColumn get identityFieldOrder => text()();
  TextColumn get knownUnsupported => text()();
  TextColumn get exportConfidence => text()();
  TextColumn get exportBlockReason => text().nullable()();
  BoolColumn get roundTripValidated =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get roundTripValidatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastValidatedAt => dateTime().nullable()();
}

class CropDescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id).unique()();

  DateTimeColumn get plantingDate => dateTime().nullable()();
  DateTimeColumn get transplantingDate => dateTime().nullable()();
  DateTimeColumn get emergenceDate => dateTime().nullable()();
  DateTimeColumn get harvestDate => dateTime().nullable()();

  TextColumn get varietyOrHybrid => text().nullable()();
  TextColumn get seedLot => text().nullable()();

  TextColumn get seedbedPreparation => text().nullable()();
  TextColumn get tillageType => text().nullable()();

  RealColumn get standardMoisture => real().nullable()();
  RealColumn get moistureAtHarvest => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text().nullable()();
}

class TrialContacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id).unique()();

  TextColumn get trialDirector => text().nullable()();
  TextColumn get cooperator => text().nullable()();
  TextColumn get sponsor => text().nullable()();
  TextColumn get applicator => text().nullable()();
  TextColumn get assessor => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text().nullable()();
}

class YieldDetails extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get trialId => integer().references(Trials, #id)();

  IntColumn get plotId => integer().references(Plots, #id).nullable()();
  IntColumn get trialAssessmentId =>
      integer().references(TrialAssessments, #id).nullable()();

  RealColumn get harvestWeight => real().nullable()();
  RealColumn get harvestMoisture => real().nullable()();
  RealColumn get harvestedArea => real().nullable()();
  RealColumn get standardMoistureUsed => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text().nullable()();
}

/// Manual field weather snapshot; one row per parent (e.g. rating session).
class WeatherSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get trialId => integer().references(Trials, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get parentType =>
      text().withDefault(const Constant('rating_session'))();
  IntColumn get parentId => integer().references(Sessions, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  RealColumn get temperature => real().nullable()();
  TextColumn get temperatureUnit =>
      text().withDefault(const Constant('C'))();
  RealColumn get humidity => real().nullable()();
  RealColumn get windSpeed => real().nullable()();
  TextColumn get windSpeedUnit =>
      text().withDefault(const Constant('km/h'))();
  TextColumn get windDirection => text().nullable()();
  TextColumn get cloudCover => text().nullable()();
  TextColumn get precipitation => text().nullable()();
  TextColumn get soilCondition => text().nullable()();
  TextColumn get notes => text().nullable()();
  /// UTC epoch milliseconds when conditions were observed.
  IntColumn get recordedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get modifiedAt => integer()();
  TextColumn get createdBy => text()();
}

/// Latest export-time diagnostics snapshot per trial (replaced on each publish).
class TrialExportDiagnostics extends Table {
  IntColumn get trialId => integer().references(Trials, #id)();
  DateTimeColumn get publishedAt => dateTime()();
  TextColumn get attemptLabel => text()();
  TextColumn get findingsJson => text()();
  IntColumn get payloadVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {trialId};
}

// ─────────────────────────────────────────────────────────────────────────────
// ARM extension tables
// ─────────────────────────────────────────────────────────────────────────────
// These tables hold ARM-specific metadata and the bridge between ARM's
// (measurement, date) column model and this app's (assessment, session) model.
// They only carry rows for ARM-linked trials; standalone trials never touch
// them. Schema lives here for Drift codegen reasons; all read/write access
// is restricted to code under lib/data/arm/ and lib/features/arm_*.
// See docs/ARM_SEPARATION.md.

/// Bridge table tying every ARM Column ID on the shell to the app-side
/// (trial_assessment, session) pair it represents. One row per ARM column.
///
/// Why this exists: ARM models an assessment column as
/// `(measurement_type × rating_date × timing)` — three "Weed Control" columns
/// on three dates are three separate ARM columns with distinct Column IDs.
/// This app models rating = plot × assessment × session, so the same three
/// rating events are one assessment rated in three sessions. This table
/// preserves ARM's semantic identity for round-trip export without forcing
/// the core schema to replicate ARM's column-per-date shape.
///
/// [trialAssessmentId] and [sessionId] may both be null for *orphan* ARM
/// columns (metadata fully blank in the shell). Orphans are preserved only
/// so export can emit them back as empty columns and the shell round-trips
/// structurally. They are never surfaced in the UI.
class ArmColumnMappings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();

  /// ARM Column ID exactly as it appears in the shell (typically numeric
  /// but kept as text to preserve leading zeros or future non-numeric IDs).
  TextColumn get armColumnId => text()();

  /// Integer form of [armColumnId] when parseable; null otherwise. Used as
  /// the canonical round-trip matching key where the shell offers it.
  IntColumn get armColumnIdInteger => integer().nullable()();

  /// 0-based position of the column within the shell's assessment-column
  /// area. Stable across import/export as long as the shell is not reshaped.
  IntColumn get armColumnIndex => integer()();

  /// The deduplicated app-side assessment this column belongs to.
  /// Null = orphan column (preserved for round-trip, hidden from UI).
  IntColumn get trialAssessmentId =>
      integer().references(TrialAssessments, #id).nullable()();

  /// The app-side session this column's rating date maps to.
  /// Null = orphan column (see above).
  IntColumn get sessionId =>
      integer().references(Sessions, #id).nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-assessment ARM metadata. One row per distinct (measurement-identity)
/// trial_assessment created by the ARM importer. Fields are the verbatim
/// values from the ARM Plot Data header rows; keep them raw so round-trip
/// export can emit exactly what ARM gave us.
class ArmAssessmentMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialAssessmentId =>
      integer().references(TrialAssessments, #id)();

  /// ARM "SE Name" code (e.g. "W003", "CF013"). Part of the dedup identity.
  TextColumn get seName => text().nullable()();

  /// Verbatim "SE Description" from the shell (e.g. "Weed Control").
  TextColumn get seDescription => text().nullable()();

  /// ARM "Part Rated" (e.g. "PLANT", "LEAF3"). Part of the dedup identity.
  TextColumn get partRated => text().nullable()();

  /// ARM "Rating Type" (e.g. "CONTRO", "LODGIN", "PESINC").
  /// Part of the dedup identity.
  TextColumn get ratingType => text().nullable()();

  TextColumn get ratingUnit => text().nullable()();
  RealColumn get ratingMin => real().nullable()();
  RealColumn get ratingMax => real().nullable()();

  /// "P" = per plot, "S" = per subsample.
  TextColumn get collectBasis => text().nullable()();

  /// Number of subsamples per plot when [collectBasis] = "S".
  IntColumn get numSubsamples => integer().nullable()();

  /// Primary pest / weed / disease target code (EPPO or ARM code).
  TextColumn get pestCode => text().nullable()();

  /// Optional secondary target code when the assessment covers two.
  TextColumn get pestCodeSecondary => text().nullable()();

  /// Original CSV column index (0-based) of the assessment column in the
  /// source Plot Data file. Used to preserve export ordering round-trip.
  IntColumn get armImportColumnIndex => integer().nullable()();

  /// ARM shell Column ID (row 7) as a raw string (e.g. "0001"). Preserved
  /// verbatim so round-trip export can emit the exact cell ARM provided.
  TextColumn get armShellColumnId => text().nullable()();

  /// Integer form of the ARM Column ID (row 7, parsed). Primary export
  /// anchor when we need to key by number rather than the raw string.
  IntColumn get armColumnIdInteger => integer().nullable()();

  /// Shell rating-date cell (row 15) as the raw display string, including
  /// any trailing markers; paired with [ArmSessionMetadata.armRatingDate].
  TextColumn get armShellRatingDate => text().nullable()();

  // ── Phase 1 Plot Data: descriptor rows 8–46 (0-based) / Excel 9–47 ──
  // Verbatim strings for round-trip; see [ArmColumnMap] and
  // test/fixtures/arm_shells/README.md.

  TextColumn get shellPestType => text().nullable()();
  TextColumn get shellPestName => text().nullable()();
  TextColumn get shellCropCode => text().nullable()();
  TextColumn get shellCropName => text().nullable()();
  TextColumn get shellCropVariety => text().nullable()();
  TextColumn get shellRatingTime => text().nullable()();
  TextColumn get shellCropOrPest => text().nullable()();
  TextColumn get shellSampleSize => text().nullable()();
  TextColumn get shellSizeUnit => text().nullable()();
  TextColumn get shellCollectionBasisUnit => text().nullable()();
  TextColumn get shellReportingBasis => text().nullable()();
  TextColumn get shellReportingBasisUnit => text().nullable()();
  TextColumn get shellStageScale => text().nullable()();
  TextColumn get shellCropStageMaj => text().nullable()();
  TextColumn get shellCropStageMin => text().nullable()();
  TextColumn get shellCropStageMax => text().nullable()();
  TextColumn get shellCropDensity => text().nullable()();
  TextColumn get shellCropDensityUnit => text().nullable()();
  TextColumn get shellPestStageMaj => text().nullable()();
  TextColumn get shellPestStageMin => text().nullable()();
  TextColumn get shellPestStageMax => text().nullable()();
  TextColumn get shellPestDensity => text().nullable()();
  TextColumn get shellPestDensityUnit => text().nullable()();
  TextColumn get shellAssessedBy => text().nullable()();
  TextColumn get shellEquipment => text().nullable()();
  TextColumn get shellUntreatedRatingType => text().nullable()();
  TextColumn get shellArmActions => text().nullable()();

  /// Row 41 (0-based) — ARM `035EET` Rating / App timing code (A1, A3, AA).
  TextColumn get shellAppTimingCode => text().nullable()();

  /// Row 42 (0-based) — ARM `036ETI` treatment-evaluation interval.
  TextColumn get shellTrtEvalInterval => text().nullable()();

  /// Row 43 (0-based) — ARM `037EPI` plant-evaluation / DAT interval.
  TextColumn get shellPlantEvalInterval => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-session ARM metadata. One row per session created by the ARM
/// importer (one per unique ARM Rating Date). Captures the protocol timing
/// context so round-trip export can reproduce the shell's date/timing/stage
/// header accurately.
class ArmSessionMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();

  /// Rating Date from the ARM shell, stored as a YYYY-MM-DD string to match
  /// the shell's own representation and the app's [Sessions.sessionDateLocal].
  TextColumn get armRatingDate => text()();

  /// ARM timing code (e.g. "A1", "A3", "A6", "AA") identifying the
  /// pre/post-application slot this rating belongs to.
  TextColumn get timingCode => text().nullable()();

  /// Major crop stage (ARM "Crop Stage Maj", e.g. "V5", "R1", "BBCH 30").
  TextColumn get cropStageMaj => text().nullable()();

  /// Minor crop stage (ARM "Crop Stage Min").
  TextColumn get cropStageMin => text().nullable()();

  /// Scale used for the crop stage (e.g. "BBCH", "Feekes").
  TextColumn get cropStageScale => text().nullable()();

  /// Days-after-treatment interval string (e.g. "21 DA-A").
  TextColumn get trtEvalInterval => text().nullable()();

  /// Days-after-planting interval string (e.g. "14 DA-P").
  TextColumn get plantEvalInterval => text().nullable()();

  /// Rater initials from the Plot Data header; may differ per rating date.
  TextColumn get raterInitials => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-treatment ARM metadata (Phase 0b-treatments).
///
/// One optional row per core [Treatments] row. Holds ARM-specific coding
/// from the ARM Treatments sheet that is **not** universal to every trial
/// (Type code, formulation concentration / type / unit like `%W/W`). The
/// universal fields (`productName`, `rate`, `rateUnit`) stay on
/// [TreatmentComponents] because a researcher running a standalone trial
/// naturally needs them. Standalone trials have **no row** here.
///
/// Phase 0b introduces the table only; the ARM Treatments-sheet importer
/// (Phase 2) will write to it, and the ARM Protocol tab sub-section
/// (Phase 6) will read it. Keeping the table empty now lets later phases
/// land without a new migration each time a field is added — add columns
/// as Phase 2 learns what the sheet actually ships.
class ArmTreatmentMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get treatmentId => integer().references(Treatments, #id)();

  /// ARM "Type" column (e.g. "H" = herbicide, "F" = fungicide). Free text
  /// because ARM's list evolves; the mapping to a core concept (if any)
  /// is a display concern.
  TextColumn get armTypeCode => text().nullable()();

  /// ARM "Form Conc" — formulation concentration as a real number
  /// (e.g. 480). Paired with [formConcUnit].
  RealColumn get formConc => real().nullable()();

  /// ARM "Form Conc Unit" — formulation concentration unit string
  /// (e.g. "%W/W", "%W/V", "G/L"). Stored verbatim so round-trip export
  /// emits exactly what ARM provided.
  TextColumn get formConcUnit => text().nullable()();

  /// ARM "Form Type" — formulation type code (e.g. "SC", "EC", "WG").
  TextColumn get formType => text().nullable()();

  /// 0-based row position of the treatment in the ARM Treatments sheet.
  /// Preserves the importer's original ordering for export.
  IntColumn get armRowSortOrder => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ARM **Applications** sheet metadata (79 descriptor rows per application
/// column in the Rating Shell `.xlsx`). One row per core
/// [TrialApplicationEvents] for ARM-linked trials.
///
/// [row01]…[row79] hold **verbatim** cell text for Excel rows **1–79** of
/// the Applications sheet (1-based; see `test/fixtures/arm_shells/README.md`:
/// R1 `ADA` … R79 `TMA`). Phase 3b/3c map parser output and dual-write
/// universal fields onto [TrialApplicationEvents] separately.
///
/// Standalone trials have zero rows here. See docs/ARM_SEPARATION.md.
class ArmApplications extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get trialApplicationEventId =>
      text().references(TrialApplicationEvents, #id,
          onDelete: KeyAction.cascade)();

  /// 0-based worksheet column index of this application block (Excel `C` → 2).
  IntColumn get armSheetColumnIndex => integer().nullable()();

  TextColumn get row01 => text().nullable()();
  TextColumn get row02 => text().nullable()();
  TextColumn get row03 => text().nullable()();
  TextColumn get row04 => text().nullable()();
  TextColumn get row05 => text().nullable()();
  TextColumn get row06 => text().nullable()();
  TextColumn get row07 => text().nullable()();
  TextColumn get row08 => text().nullable()();
  TextColumn get row09 => text().nullable()();
  TextColumn get row10 => text().nullable()();
  TextColumn get row11 => text().nullable()();
  TextColumn get row12 => text().nullable()();
  TextColumn get row13 => text().nullable()();
  TextColumn get row14 => text().nullable()();
  TextColumn get row15 => text().nullable()();
  TextColumn get row16 => text().nullable()();
  TextColumn get row17 => text().nullable()();
  TextColumn get row18 => text().nullable()();
  TextColumn get row19 => text().nullable()();
  TextColumn get row20 => text().nullable()();
  TextColumn get row21 => text().nullable()();
  TextColumn get row22 => text().nullable()();
  TextColumn get row23 => text().nullable()();
  TextColumn get row24 => text().nullable()();
  TextColumn get row25 => text().nullable()();
  TextColumn get row26 => text().nullable()();
  TextColumn get row27 => text().nullable()();
  TextColumn get row28 => text().nullable()();
  TextColumn get row29 => text().nullable()();
  TextColumn get row30 => text().nullable()();
  TextColumn get row31 => text().nullable()();
  TextColumn get row32 => text().nullable()();
  TextColumn get row33 => text().nullable()();
  TextColumn get row34 => text().nullable()();
  TextColumn get row35 => text().nullable()();
  TextColumn get row36 => text().nullable()();
  TextColumn get row37 => text().nullable()();
  TextColumn get row38 => text().nullable()();
  TextColumn get row39 => text().nullable()();
  TextColumn get row40 => text().nullable()();
  TextColumn get row41 => text().nullable()();
  TextColumn get row42 => text().nullable()();
  TextColumn get row43 => text().nullable()();
  TextColumn get row44 => text().nullable()();
  TextColumn get row45 => text().nullable()();
  TextColumn get row46 => text().nullable()();
  TextColumn get row47 => text().nullable()();
  TextColumn get row48 => text().nullable()();
  TextColumn get row49 => text().nullable()();
  TextColumn get row50 => text().nullable()();
  TextColumn get row51 => text().nullable()();
  TextColumn get row52 => text().nullable()();
  TextColumn get row53 => text().nullable()();
  TextColumn get row54 => text().nullable()();
  TextColumn get row55 => text().nullable()();
  TextColumn get row56 => text().nullable()();
  TextColumn get row57 => text().nullable()();
  TextColumn get row58 => text().nullable()();
  TextColumn get row59 => text().nullable()();
  TextColumn get row60 => text().nullable()();
  TextColumn get row61 => text().nullable()();
  TextColumn get row62 => text().nullable()();
  TextColumn get row63 => text().nullable()();
  TextColumn get row64 => text().nullable()();
  TextColumn get row65 => text().nullable()();
  TextColumn get row66 => text().nullable()();
  TextColumn get row67 => text().nullable()();
  TextColumn get row68 => text().nullable()();
  TextColumn get row69 => text().nullable()();
  TextColumn get row70 => text().nullable()();
  TextColumn get row71 => text().nullable()();
  TextColumn get row72 => text().nullable()();
  TextColumn get row73 => text().nullable()();
  TextColumn get row74 => text().nullable()();
  TextColumn get row75 => text().nullable()();
  TextColumn get row76 => text().nullable()();
  TextColumn get row77 => text().nullable()();
  TextColumn get row78 => text().nullable()();
  TextColumn get row79 => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Reference lookup table for SE type biological profiles.
/// One row per ratingType prefix (e.g. 'CONTRO', 'PHYGEN').
/// This is seeded reference data — not per-trial, not computed.
/// The authoritative grounding for all relationship-layer biological-window
/// and variance computations. See docs/architecture/TRIAL_MODEL.md.
class SeTypeProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ARM ratingType prefix used as the natural key (e.g. 'CONTRO', 'PHYGEN').
  TextColumn get ratingTypePrefix =>
      text().unique().withLength(min: 1, max: 20)();

  /// Human-readable name (e.g. 'Weed Control', 'Crop Injury - Chlorosis').
  TextColumn get displayName => text()();

  /// Broad measurement category: 'percent', 'count', 'continuous', 'ordinal'.
  TextColumn get measurementCategory => text()();

  /// Rating direction: 'higher_better', 'lower_better', 'neutral'.
  TextColumn get responseDirection => text()();

  /// Earliest DAT at which ratings are biologically meaningful (null = unbounded).
  IntColumn get validObservationWindowMinDat => integer().nullable()();

  /// Latest DAT at which ratings are biologically meaningful (null = unbounded).
  IntColumn get validObservationWindowMaxDat => integer().nullable()();

  /// Lower bound of expected coefficient-of-variation range (null = unknown).
  RealColumn get expectedCvMin => real().nullable()();

  /// Upper bound of expected coefficient-of-variation range (null = unknown).
  RealColumn get expectedCvMax => real().nullable()();

  /// Minimum valid rating value for this SE type (null = no constraint).
  RealColumn get scaleMin => real().nullable()();

  /// Maximum valid rating value for this SE type (null = no constraint).
  RealColumn get scaleMax => real().nullable()();

  /// Reference authority: 'EPPO_PP1', 'ARM_CONVENTION', 'TRAJECTORY_ANALYSIS_TODO'.
  TextColumn get source => text()();

  /// Caveats or limitations on this profile (null = none).
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Field intelligence: signals / decisions / evidence (schema v72+) ──────
// Spec uses "rating_sessions" and "raters" — this app maps them to [Sessions]
// and [Users] respectively.

/// A raised insight or warning for field work (trial/session/plot scoped).
class Signals extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get trialId => integer().references(Trials, #id)();

  /// [Sessions.id] — spec name "rating_sessions" not used in this codebase.
  IntColumn get sessionId => integer().nullable().references(Sessions, #id)();

  IntColumn get plotId => integer().nullable().references(Plots, #id)();

  /// scale_violation | spatial_anomaly | protocol_divergence | ...
  TextColumn get signalType => text()();

  /// 1–5 (Last Actionable Moment).
  IntColumn get moment => integer()();

  /// critical | review | info
  TextColumn get severity => text()();

  /// Trusted time, epoch milliseconds UTC.
  IntColumn get raisedAt => integer()();

  /// [Users.id] — spec "raters"; null = system.
  IntColumn get raisedBy => integer().nullable().references(Users, #id)();

  /// JSON: neighbors, treatment mean, session mean, protocol expected value.
  TextColumn get referenceContext => text()();

  /// JSON: deltas, % differences.
  TextColumn get magnitudeContext => text().nullable()();

  TextColumn get consequenceText => text()();

  /// open | deferred | investigating | resolved | expired | suppressed
  TextColumn get status => text().withDefault(const Constant('open'))();

  IntColumn get createdAt => integer()();
}

/// Immutable decision log — application code must never UPDATE rows.
class SignalDecisionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get signalId =>
      integer().references(Signals, #id, onDelete: KeyAction.cascade)();

  /// confirm | re_rate | investigate | defer | suppress | expire
  TextColumn get eventType => text()();

  IntColumn get occurredAt => integer()();

  IntColumn get actorUserId => integer().nullable().references(Users, #id)();

  TextColumn get note => text().nullable()();

  IntColumn get followUpDueAt => integer().nullable()();

  TextColumn get followUpContext => text().nullable()();

  TextColumn get resultingStatus => text()();

  IntColumn get createdAt => integer()();
}

/// Materialized side-effects of a decision (field-level audit trail).
class ActionEffects extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get decisionEventId => integer().references(SignalDecisionEvents, #id,
      onDelete: KeyAction.cascade)();

  /// plot_observation | session | trial | application | photo
  TextColumn get entityType => text()();

  IntColumn get entityId => integer()();

  TextColumn get fieldName => text()();

  TextColumn get oldValue => text().nullable()();

  TextColumn get newValue => text().nullable()();

  IntColumn get appliedAt => integer()();

  IntColumn get createdAt => integer()();
}

/// EPPO-aligned causal expectations per SE type × trial mode (seeded reference).
class SeTypeCausalProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// CONTRO | LODGIN | PESINC | ...
  TextColumn get seType => text()();

  /// efficacy | variety | breeding | on_farm
  TextColumn get trialType => text()();

  IntColumn get causalWindowDaysMin => integer()();

  IntColumn get causalWindowDaysMax => integer()();

  /// increase | decrease | stable
  TextColumn get expectedResponseDirection => text()();

  RealColumn get expectedChangeRatePerWeek => real().nullable()();

  BoolColumn get spatialClusteringExpected =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get untreatedExcludedFromMean =>
      boolean().withDefault(const Constant(true))();

  RealColumn get baseThresholdSdMultiplier =>
      real().withDefault(const Constant(2.0))();

  TextColumn get source => text()();

  TextColumn get sourceReference => text().nullable()();

  /// Regulatory region; NULL means profile applies to any region.
  TextColumn get region => text().nullable()();

  /// Timing window type: 'bbch' (days-based) or 'gdd' (growing degree days).
  /// Open text to allow future window types without a schema change.
  TextColumn get windowType =>
      text().nullable().withDefault(const Constant('bbch'))();

  IntColumn get createdAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {seType, trialType, region},
      ];
}

/// Links evidence rows (photos, weather, GPS, audit) to analytical claims.
class EvidenceAnchors extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get trialId => integer().references(Trials, #id)();

  /// photo | weather_snapshot | gps_record | audit_entry
  TextColumn get evidenceType => text()();

  /// Polymorphic FK — resolved via [evidenceType].
  IntColumn get evidenceId => integer()();

  /// rating | session | application | deviation
  TextColumn get claimType => text()();

  IntColumn get claimId => integer()();

  TextColumn get anchorReason => text().nullable()();

  IntColumn get anchoredAt => integer()();

  IntColumn get anchoredBy => integer().nullable().references(Users, #id)();

  IntColumn get createdAt => integer()();
}

/// Versioned trial intent object. Current active version = newest non-superseded row.
/// status: draft | partial | confirmed | superseded
/// sourceMode: arm_structure | manual_revelation | protocol_document | mixed
class TrialPurposes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get sourceMode =>
      text().withDefault(const Constant('manual_revelation'))();
  TextColumn get claimBeingTested => text().nullable()();
  TextColumn get trialPurpose => text().nullable()();
  TextColumn get regulatoryContext => text().nullable()();
  TextColumn get primaryEndpoint => text().nullable()();
  TextColumn get primaryEndpointRationale => text().nullable()();
  TextColumn get treatmentRoleSummary => text().nullable()();
  TextColumn get knownInterpretationFactors => text().nullable()();
  TextColumn get requiredEvidenceSummary => text().nullable()();
  TextColumn get readinessCriteriaSummary => text().nullable()();
  TextColumn get inferredFieldsJson => text().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  TextColumn get confirmedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get supersededAt => dateTime().nullable()();
}

/// Append-only audit trail for Mode C intent capture.
/// answerState: unknown | captured | confirmed | revised | skipped
class IntentRevelationEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get trialPurposeId =>
      integer().references(TrialPurposes, #id).nullable()();
  TextColumn get touchpoint => text()();
  TextColumn get questionKey => text()();
  TextColumn get questionText => text()();
  TextColumn get answerValue => text().nullable()();
  TextColumn get answerState =>
      text().withDefault(const Constant('unknown'))();
  TextColumn get source => text()();
  TextColumn get capturedBy => text().nullable()();
  DateTimeColumn get capturedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Critical-to-quality factor definitions for the trial claim.
/// These are definitions of what matters — not findings.
class CtqFactorDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get trialPurposeId =>
      integer().references(TrialPurposes, #id)();
  TextColumn get factorKey => text()();
  TextColumn get factorLabel => text()();
  TextColumn get factorType => text()();
  TextColumn get importance =>
      text().withDefault(const Constant('standard'))();
  TextColumn get expectedEvidenceType => text().nullable()();
  TextColumn get evaluationRuleKey => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get retiredAt => dateTime().nullable()();
}

/// Future-proof references to protocol/study-plan documents.
/// No parsing. No LLM. Store references only.
class ProtocolDocumentReferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get documentLabel => text()();
  TextColumn get documentType => text()();
  TextColumn get storageUri => text().nullable()();
  TextColumn get externalReference => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();
  TextColumn get uploadedBy => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

@DriftDatabase(tables: [
  Users,
  Trials,
  Treatments,
  TreatmentComponents,
  Assessments,
  AssessmentDefinitions,
  TrialAssessments,
  Plots,
  Assignments,
  Sessions,
  SessionAssessments,
  RatingRecords,
  RatingCorrections,
  Notes,
  Photos,
  PlotFlags,
  DeviationFlags,
  SeedingRecords,
  ProtocolSeedingFields,
  SeedingFieldValues,
  ApplicationSlots,
  ApplicationEvents,
  ApplicationPlotRecords,
  AuditEvents,
  ImportEvents,
  SeedingEvents,
  TrialApplicationEvents,
  TrialApplicationProducts,
  ApplicationPlotAssignments,
  ImportSnapshots,
  CompatibilityProfiles,
  CropDescriptions,
  TrialContacts,
  YieldDetails,
  TrialExportDiagnostics,
  WeatherSnapshots,
  Sites,
  // ARM extension tables (see ARM extension tables section above).
  ArmColumnMappings,
  ArmAssessmentMetadata,
  ArmSessionMetadata,
  ArmTrialMetadata,
  ArmTreatmentMetadata,
  ArmApplications,
  // Reference / lookup tables (seeded at install; not per-trial, not computed).
  SeTypeProfiles,
  // Field intelligence (v72): signals pipeline + causal profiles + evidence anchors.
  Signals,
  SignalDecisionEvents,
  ActionEffects,
  SeTypeCausalProfiles,
  EvidenceAnchors,
  // Trial Cognition V1 (v78): purpose versioning, Mode C revelation, CTQ factors, protocol docs.
  TrialPurposes,
  IntentRevelationEvents,
  CtqFactorDefinitions,
  ProtocolDocumentReferences,
])
class AppDatabase extends _$AppDatabase {
  /// In-memory database for testing only.
  AppDatabase.forTesting(super.e);

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 78;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
          await _seedAssessmentDefinitions();
          await _seedSeTypeProfiles();
          await _seedSeTypeCausalProfiles();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(seedingRecords);
            await m.createTable(protocolSeedingFields);
            await m.createTable(seedingFieldValues);
          }
          if (from < 6) {
            await m.addColumn(plots, plots.fieldRow);
            await m.addColumn(plots, plots.fieldColumn);
          }
          if (from < 7) {
            await m.createTable(users);
            await m.addColumn(sessions, sessions.createdByUserId);
            await m.addColumn(auditEvents, auditEvents.performedByUserId);
          }
          if (from < 8) {
            await m.createTable(ratingCorrections);
            await m.addColumn(ratingRecords, ratingRecords.createdAppVersion);
            await m.addColumn(ratingRecords, ratingRecords.createdDeviceInfo);
            await m.addColumn(ratingRecords, ratingRecords.capturedLatitude);
            await m.addColumn(ratingRecords, ratingRecords.capturedLongitude);
          }
          if (from < 9) {
            await m.addColumn(plots, plots.assignmentSource);
            await m.addColumn(plots, plots.assignmentUpdatedAt);
          }
          if (from < 10) {
            await m.createTable(assignments);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_assignments_trial_plot ON assignments(trial_id, plot_id)',
            );
            // Drift DateTimeColumn expects INTEGER (unix seconds), not text from datetime('now').
            await customStatement('''
              INSERT INTO assignments (trial_id, plot_id, treatment_id, replication, range, "column", assignment_source, assigned_at, created_at, updated_at)
              SELECT trial_id, id, treatment_id, rep, field_row, field_column, assignment_source,
                CASE WHEN assignment_updated_at IS NULL THEN NULL
                     WHEN typeof(assignment_updated_at) = 'text' THEN strftime('%s', assignment_updated_at)
                     ELSE assignment_updated_at END,
                strftime('%s', 'now'),
                strftime('%s', 'now')
              FROM plots
            ''');
          }
          if (from < 11) {
            await m.createTable(assessmentDefinitions);
            await m.createTable(trialAssessments);
            await m.addColumn(
                sessionAssessments, sessionAssessments.trialAssessmentId);
            await m.addColumn(ratingRecords, ratingRecords.trialAssessmentId);
            await _seedAssessmentDefinitions();
          }
          // Repair assignments + assessment_definitions: v10/v11 wrote datetime('now') (text); Drift expects INTEGER unix seconds.
          if (from < 12) {
            await customStatement(
              "UPDATE assignments SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text'",
            );
            await customStatement(
              "UPDATE assignments SET updated_at = strftime('%s', updated_at) WHERE typeof(updated_at) = 'text'",
            );
            await customStatement(
              "UPDATE assignments SET assigned_at = strftime('%s', assigned_at) WHERE assigned_at IS NOT NULL AND typeof(assigned_at) = 'text'",
            );
            await customStatement(
              "UPDATE assessment_definitions SET created_at = strftime('%s', created_at) WHERE typeof(created_at) = 'text'",
            );
            await customStatement(
              "UPDATE assessment_definitions SET updated_at = strftime('%s', updated_at) WHERE typeof(updated_at) = 'text'",
            );
          }
          if (from < 13) {
            await m.addColumn(importEvents, importEvents.savedFilePath);
          }
          if (from < 14) {
            await m.addColumn(sessionAssessments, sessionAssessments.sortOrder);
          }
          if (from < 15) {
            await m.addColumn(trials, trials.plotDimensions);
            await m.addColumn(trials, trials.plotRows);
            await m.addColumn(trials, trials.plotSpacing);
          }
          if (from < 16) {
            await m.createTable(seedingEvents);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_seeding_events_trial ON seeding_events(trial_id)',
            );
          }
          if (from < 17) {
            await m.createTable(trialApplicationEvents);
          }
          if (from < 18) {
            await m.addColumn(trials, trials.sponsor);
            await m.addColumn(trials, trials.protocolNumber);
            await m.addColumn(trials, trials.investigatorName);
            await m.addColumn(trials, trials.cooperatorName);
            await m.addColumn(trials, trials.siteId);
            await m.addColumn(trials, trials.fieldName);
            await m.addColumn(trials, trials.county);
            await m.addColumn(trials, trials.stateProvince);
            await m.addColumn(trials, trials.country);
            await m.addColumn(trials, trials.latitude);
            await m.addColumn(trials, trials.longitude);
            await m.addColumn(trials, trials.elevationM);
            await m.addColumn(trials, trials.experimentalDesign);
            await m.addColumn(trials, trials.plotLengthM);
            await m.addColumn(trials, trials.plotWidthM);
            await m.addColumn(trials, trials.alleyLengthM);
            await m.addColumn(trials, trials.previousCrop);
            await m.addColumn(trials, trials.tillage);
            await m.addColumn(trials, trials.irrigated);
            await m.addColumn(trials, trials.soilSeries);
            await m.addColumn(trials, trials.soilTexture);
            await m.addColumn(trials, trials.organicMatterPct);
            await m.addColumn(trials, trials.soilPh);
            await m.addColumn(trials, trials.harvestDate);
            await m.addColumn(trials, trials.studyType);
          }
          if (from < 19) {
            await m.addColumn(seedingEvents, seedingEvents.variety);
            await m.addColumn(seedingEvents, seedingEvents.seedTreatment);
            await m.addColumn(seedingEvents, seedingEvents.germinationPct);
            await m.addColumn(seedingEvents, seedingEvents.emergenceDate);
            await m.addColumn(seedingEvents, seedingEvents.emergencePct);
            await m.addColumn(seedingEvents, seedingEvents.plantingMethod);
          }
          if (from < 20) {
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.applicationTime);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.applicationMethod);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.nozzleType);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.nozzleSpacingCm);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.operatingPressure);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.pressureUnit);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.groundSpeed);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.speedUnit);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.adjuvantName);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.adjuvantRate);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.adjuvantRateUnit);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.spraySolutionPh);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.waterVolumeUnit);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.cloudCoverPct);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.soilMoisture);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.treatedArea);
            await m.addColumn(trialApplicationEvents,
                trialApplicationEvents.treatedAreaUnit);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.plotsTreated);
          }
          if (from < 21) {
            await m.addColumn(treatments, treatments.treatmentType);
            await m.addColumn(treatments, treatments.timingCode);
            await m.addColumn(treatments, treatments.eppoCode);
            await m.addColumn(treatmentComponents,
                treatmentComponents.activeIngredientPct);
            await m.addColumn(treatmentComponents,
                treatmentComponents.formulationType);
            await m.addColumn(treatmentComponents,
                treatmentComponents.manufacturer);
            await m.addColumn(treatmentComponents,
                treatmentComponents.registrationNumber);
            await m.addColumn(treatmentComponents,
                treatmentComponents.eppoCode);
          }
          if (from < 22) {
            await m.addColumn(plots, plots.plotLengthM);
            await m.addColumn(plots, plots.plotWidthM);
            await m.addColumn(plots, plots.plotAreaM2);
            await m.addColumn(plots, plots.harvestLengthM);
            await m.addColumn(plots, plots.harvestWidthM);
            await m.addColumn(plots, plots.harvestAreaM2);
            await m.addColumn(plots, plots.plotDirection);
            await m.addColumn(plots, plots.soilSeries);
            await m.addColumn(plots, plots.plotNotes);
          }
          if (from < 23) {
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.timingCode);
            await m.addColumn(assessmentDefinitions,
                assessmentDefinitions.daysAfterTreatment);
            await m.addColumn(assessmentDefinitions,
                assessmentDefinitions.assessmentMethod);
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.validMin);
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.validMax);
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.eppoCode);
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.cropPart);
            await m.addColumn(assessmentDefinitions,
                assessmentDefinitions.timingDescription);
          }
          if (from < 24) {
            await m.addColumn(ratingRecords, ratingRecords.ratingTime);
            await m.addColumn(ratingRecords, ratingRecords.ratingMethod);
            await m.addColumn(ratingRecords, ratingRecords.confidence);
            await m.addColumn(ratingRecords, ratingRecords.amended);
            await m.addColumn(ratingRecords, ratingRecords.originalValue);
            await m.addColumn(ratingRecords, ratingRecords.amendmentReason);
            await m.addColumn(ratingRecords, ratingRecords.amendedBy);
            await m.addColumn(ratingRecords, ratingRecords.amendedAt);
          }
          if (from < 25) {
            await m.addColumn(
                trialApplicationEvents,
                trialApplicationEvents.soilTemperature);
            await m.addColumn(
                trialApplicationEvents,
                trialApplicationEvents.soilTempUnit);
            await m.addColumn(
                trialApplicationEvents,
                trialApplicationEvents.soilDepth);
            await m.addColumn(
                trialApplicationEvents,
                trialApplicationEvents.soilDepthUnit);
          }
          if (from < 26) {
            await m.addColumn(trials, trials.isDeleted);
            await m.addColumn(trials, trials.deletedAt);
            await m.addColumn(trials, trials.deletedBy);
            await m.addColumn(sessions, sessions.isDeleted);
            await m.addColumn(sessions, sessions.deletedAt);
            await m.addColumn(sessions, sessions.deletedBy);
            await m.addColumn(plots, plots.isDeleted);
            await m.addColumn(plots, plots.deletedAt);
            await m.addColumn(plots, plots.deletedBy);
            await m.addColumn(ratingRecords, ratingRecords.isDeleted);
            await m.addColumn(ratingRecords, ratingRecords.deletedAt);
            await m.addColumn(ratingRecords, ratingRecords.deletedBy);
          }
          if (from < 27) {
            await m.addColumn(
                ratingRecords, ratingRecords.lastEditedByUserId);
            await m.addColumn(ratingRecords, ratingRecords.lastEditedAt);
          }
          if (from < 28) {
            await m.addColumn(plots, plots.isGuardRow);
          }
          if (from < 29) {
            await m.createTable(trialApplicationProducts);
            await customStatement('''
INSERT INTO trial_application_products (
  trial_application_event_id, product_name, rate, rate_unit, sort_order)
SELECT id, product_name, rate, rate_unit, 0
FROM trial_application_events
WHERE product_name IS NOT NULL AND LENGTH(TRIM(product_name)) > 0
''');
          }
          if (from < 30) {
            await m.addColumn(trials, trials.workspaceType);
          }
          if (from < 31) {
            await m.addColumn(
                assessmentDefinitions, assessmentDefinitions.resultDirection);
          }
          if (from < 32) {
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.appliedAt);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.status);
            await customStatement('''
UPDATE trial_application_events
SET status = 'applied',
    applied_at = COALESCE(application_date, created_at)
''');
          }
          if (from < 33) {
            await m.addColumn(seedingEvents, seedingEvents.completedAt);
            await m.addColumn(seedingEvents, seedingEvents.status);
            await customStatement('''
UPDATE seeding_events
SET status = 'completed',
    completed_at = COALESCE(seeding_date, created_at)
''');
          }
          if (from < 35) {
            await m.createTable(importSnapshots);
            await m.createTable(compatibilityProfiles);
            final tc35 = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tc35.contains('is_arm_linked')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN is_arm_linked INTEGER NOT NULL DEFAULT 0',
              );
            }
            if (!tc35.contains('arm_imported_at')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_imported_at INTEGER',
              );
            }
            if (!tc35.contains('arm_source_file')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_source_file TEXT',
              );
            }
            if (!tc35.contains('arm_version')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_version TEXT',
              );
            }
          }
          if (from < 36) {
            await m.addColumn(plots, plots.excludeFromAnalysis);
            await m.addColumn(plots, plots.exclusionReason);
            await m.addColumn(plots, plots.damageType);

            // Historical v36 add. pestCode later moved to
            // arm_assessment_metadata and was dropped from trial_assessments
            // in v61 (Unit 5d); the ADD here uses raw SQL so pre-v36
            // upgrades still pass through v61's drop cleanly.
            final taCols36 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!taCols36.contains('pest_code')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN pest_code TEXT',
              );
            }
            await m.addColumn(trialAssessments, trialAssessments.pestName);
            await m.addColumn(trialAssessments, trialAssessments.eppoCodeLocal);
            await m.addColumn(trialAssessments, trialAssessments.bbchScale);
            await m.addColumn(
                trialAssessments, trialAssessments.cropStageAtAssessment);

            await m.createTable(cropDescriptions);
            await m.createTable(trialContacts);
            await m.createTable(yieldDetails);
          }
          if (from < 37) {
            await m.addColumn(treatments, treatments.isDeleted);
            await m.addColumn(treatments, treatments.deletedAt);
            await m.addColumn(treatments, treatments.deletedBy);
            await m.addColumn(treatmentComponents, treatmentComponents.isDeleted);
            await m.addColumn(
                treatmentComponents, treatmentComponents.deletedAt);
            await m.addColumn(
                treatmentComponents, treatmentComponents.deletedBy);
            await m.addColumn(photos, photos.isDeleted);
            await m.addColumn(photos, photos.deletedAt);
            await m.addColumn(photos, photos.deletedBy);
          }
          if (from < 38) {
            await m.addColumn(seedingEvents, seedingEvents.lastEditedByUserId);
            await m.addColumn(seedingEvents, seedingEvents.lastEditedAt);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.lastEditedByUserId);
            await m.addColumn(
                trialApplicationEvents, trialApplicationEvents.lastEditedAt);
          }
          if (from < 39) {
            await m.addColumn(treatments, treatments.lastEditedByUserId);
            await m.addColumn(treatments, treatments.lastEditedAt);
            await m.addColumn(
                treatmentComponents, treatmentComponents.lastEditedByUserId);
            await m.addColumn(
                treatmentComponents, treatmentComponents.lastEditedAt);
          }
          if (from < 40) {
            await m.createTable(trialExportDiagnostics);
          }
          if (from < 41) {
            await m.addColumn(plots, plots.armPlotNumber);
            await m.addColumn(plots, plots.armImportDataRowIndex);
            // Historical column added to trial_assessments in v41, then moved
            // to arm_assessment_metadata and dropped in v60. Keep the v41 ADD
            // here via raw SQL so users upgrading from pre-v41 still land at
            // a valid v60 schema (v60 drops the column again idempotently).
            final taCols41 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!taCols41.contains('arm_import_column_index')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN arm_import_column_index INTEGER',
              );
            }
            final tc41 = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tc41.contains('arm_import_session_id')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_import_session_id INTEGER',
              );
            }
          }
          if (from < 42) {
            final tc42 = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tc42.contains('arm_linked_shell_path')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_linked_shell_path TEXT',
              );
            }
            if (!tc42.contains('arm_linked_shell_at')) {
              await customStatement(
                'ALTER TABLE trials ADD COLUMN arm_linked_shell_at INTEGER',
              );
            }
          }
          if (from < 43) {
            // Historical v43 additions. Two of the per-column ARM fields
            // (armShellColumnId, armShellRatingDate) were later moved to
            // arm_assessment_metadata and dropped from trial_assessments in
            // v60. The three SE / rating-type fields added in v43
            // (seName, seDescription, armRatingType) were likewise moved
            // to arm_assessment_metadata and dropped in v61. The ADDs here
            // use raw SQL so pre-v43 upgrades still pass through v60/v61's
            // drops cleanly.
            final taCols43 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!taCols43.contains('arm_shell_column_id')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN arm_shell_column_id TEXT',
              );
            }
            if (!taCols43.contains('arm_shell_rating_date')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN arm_shell_rating_date TEXT',
              );
            }
            if (!taCols43.contains('se_name')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN se_name TEXT',
              );
            }
            if (!taCols43.contains('se_description')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN se_description TEXT',
              );
            }
            if (!taCols43.contains('arm_rating_type')) {
              await customStatement(
                'ALTER TABLE trial_assessments ADD COLUMN arm_rating_type TEXT',
              );
            }
          }
          if (from < 44) {
            await m.createTable(weatherSnapshots);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_weather_snapshots_parent ON weather_snapshots(parent_type, parent_id)',
            );
          }
          // v44 tables lacked ON DELETE CASCADE on trial/session FKs; recreate so
          // deleting a trial or session removes dependent weather rows.
          if (from < 45) {
            await customStatement(
              'ALTER TABLE weather_snapshots RENAME TO weather_snapshots_old',
            );
            await m.createTable(weatherSnapshots);
            await customStatement(
              'INSERT INTO weather_snapshots SELECT * FROM weather_snapshots_old',
            );
            await customStatement('DROP TABLE weather_snapshots_old');
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_weather_snapshots_parent ON weather_snapshots(parent_type, parent_id)',
            );
          }
          if (from < 46) {
            await m.addColumn(sessions, sessions.cropStageBbch);
          }
          if (from < 47) {
            await customStatement('''
UPDATE plots SET plot_notes = CASE
  WHEN notes IS NOT NULL AND TRIM(notes) != '' AND plot_notes IS NOT NULL AND TRIM(plot_notes) != ''
    THEN notes || char(10) || '---' || char(10) || plot_notes
  WHEN notes IS NOT NULL AND TRIM(notes) != ''
    THEN notes
  ELSE plot_notes
END
WHERE notes IS NOT NULL AND TRIM(notes) != ''
   OR plot_notes IS NOT NULL
''');
            await customStatement('ALTER TABLE plots DROP COLUMN notes');
            await customStatement('ALTER TABLE notes RENAME TO notes_old');
            await m.createTable(notes);
            await customStatement('''
INSERT INTO notes (
  id, trial_id, plot_pk, session_id, content, created_at, rater_name,
  updated_at, updated_by, is_deleted, deleted_at, deleted_by
)
SELECT
  id,
  trial_id,
  plot_pk,
  session_id,
  content,
  CASE WHEN typeof(created_at) = 'text' THEN strftime('%s', created_at) ELSE created_at END,
  rater_name,
  NULL,
  NULL,
  0,
  NULL,
  NULL
FROM notes_old
''');
            await customStatement('DROP TABLE notes_old');
            await customStatement('''
INSERT OR REPLACE INTO sqlite_sequence (name, seq)
SELECT 'notes', COALESCE((SELECT MAX(id) FROM notes), 0)
''');
          }
          if (from < 49) {
            // Defensive creation of application tables missing from onUpgrade.
            // Must be created in dependency order:
            // application_slots → application_events → application_plot_records.
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (!existingTables.contains('application_slots')) {
              await m.createTable(applicationSlots);
            }
            if (!existingTables.contains('application_events')) {
              await m.createTable(applicationEvents);
            }
            if (!existingTables.contains('application_plot_records')) {
              await m.createTable(applicationPlotRecords);
            }
          }

          if (from < 50) {
            final sessionCols = await customSelect(
              "SELECT name FROM pragma_table_info('sessions')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in [
              'crop_injury_status',
              'crop_injury_notes',
              'crop_injury_photo_ids',
            ]) {
              if (!sessionCols.contains(col)) {
                await customStatement(
                    'ALTER TABLE sessions ADD COLUMN $col TEXT');
              }
            }
          }

          if (from < 51) {
            // Create Sites table.
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            if (!existingTables.contains('sites')) {
              await m.createTable(sites);
            }

            // Add new Trial columns (defensive: check before adding).
            final trialCols = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in {
              'site_ref_id': 'INTEGER REFERENCES sites(id)',
              'cultivar': 'TEXT',
              'row_spacing_cm': 'REAL',
              'plant_spacing_cm': 'REAL',
              'gep_compliance_flag': 'INTEGER',
            }.entries) {
              if (!trialCols.contains(col.key)) {
                await customStatement(
                    'ALTER TABLE trials ADD COLUMN ${col.key} ${col.value}');
              }
            }

            // Backfill: create a Site record for each trial that has
            // GPS or soil data. One site per trial, no dedup.
            final trialsWithSiteData = await customSelect(
              'SELECT id, latitude, longitude, elevation_m, '
              'soil_series, soil_texture, soil_ph, organic_matter_pct, '
              'previous_crop, tillage, irrigated, field_name, '
              'county, state_province, country '
              'FROM trials WHERE is_deleted = 0 AND '
              '(latitude IS NOT NULL OR soil_texture IS NOT NULL '
              'OR soil_ph IS NOT NULL)',
            ).get();
            for (final row in trialsWithSiteData) {
              final trialId = row.read<int>('id');
              await customStatement(
                'INSERT INTO sites (latitude, longitude, elevation_m, '
                'soil_series, soil_texture, soil_ph, organic_matter_pct, '
                'previous_crop, tillage, irrigated, field_name, '
                'county, state_province, country) '
                'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                  row.readNullable<double>('latitude'),
                  row.readNullable<double>('longitude'),
                  row.readNullable<double>('elevation_m'),
                  row.readNullable<String>('soil_series'),
                  row.readNullable<String>('soil_texture'),
                  row.readNullable<double>('soil_ph'),
                  row.readNullable<double>('organic_matter_pct'),
                  row.readNullable<String>('previous_crop'),
                  row.readNullable<String>('tillage'),
                  row.readNullable<bool>('irrigated'),
                  row.readNullable<String>('field_name'),
                  row.readNullable<String>('county'),
                  row.readNullable<String>('state_province'),
                  row.readNullable<String>('country'),
                ],
              );
              // Link trial → newly created site.
              await customStatement(
                'UPDATE trials SET site_ref_id = last_insert_rowid() '
                'WHERE id = ?',
                [trialId],
              );
            }
          }

          if (from < 52) {
            // Application session lifecycle + deviation fields.
            final appCols = await customSelect(
              "SELECT name FROM pragma_table_info('trial_application_events')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in {
              'precipitation': 'TEXT',
              'precipitation_mm': 'REAL',
              'conditions_recorded_at': 'INTEGER',
              'boom_height_cm': 'REAL',
              'session_name': 'TEXT',
              'started_at': 'INTEGER',
              'completed_at': 'INTEGER',
              'closed_at': 'INTEGER',
              'total_product_mixed': 'REAL',
              'total_area_sprayed_ha': 'REAL',
            }.entries) {
              if (!appCols.contains(col.key)) {
                await customStatement(
                    'ALTER TABLE trial_application_events '
                    'ADD COLUMN ${col.key} ${col.value}');
              }
            }

            final prodCols = await customSelect(
              "SELECT name FROM pragma_table_info('trial_application_products')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in {
              'planned_product': 'TEXT',
              'planned_rate': 'REAL',
              'planned_rate_unit': 'TEXT',
              'deviation_flag': 'INTEGER DEFAULT 0',
              'deviation_notes': 'TEXT',
            }.entries) {
              if (!prodCols.contains(col.key)) {
                await customStatement(
                    'ALTER TABLE trial_application_products '
                    'ADD COLUMN ${col.key} ${col.value}');
              }
            }
          }

          if (from < 53) {
            final compCols = await customSelect(
              "SELECT name FROM pragma_table_info('treatment_components')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in {
              'active_ingredient_name': 'TEXT',
              'ai_concentration': 'REAL',
              'ai_concentration_unit': 'TEXT',
              'label_rate': 'REAL',
              'label_rate_unit': 'TEXT',
              'is_test_product': 'INTEGER DEFAULT 0',
            }.entries) {
              if (!compCols.contains(col.key)) {
                await customStatement(
                    'ALTER TABLE treatment_components '
                    'ADD COLUMN ${col.key} ${col.value}');
              }
            }
          }

          if (from < 54) {
            final photoCols = await customSelect(
              "SELECT name FROM pragma_table_info('photos')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            if (!photoCols.contains('assessment_id')) {
              await customStatement(
                  'ALTER TABLE photos ADD COLUMN assessment_id INTEGER '
                  'REFERENCES assessments(id)');
            }
            if (!photoCols.contains('rating_value')) {
              await customStatement(
                  'ALTER TABLE photos ADD COLUMN rating_value REAL');
            }
          }

          if (from < 55) {
            // ── Item 1: ApplicationPlotAssignments junction table ──
            await customStatement('''
              CREATE TABLE IF NOT EXISTS application_plot_assignments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                application_event_id TEXT NOT NULL
                  REFERENCES trial_application_events(id) ON DELETE CASCADE,
                plot_label TEXT NOT NULL,
                plot_id INTEGER REFERENCES plots(id)
              )
            ''');

            // Migrate existing plotsTreated TEXT values into junction rows.
            final rows = await customSelect(
              'SELECT id, trial_id, plots_treated '
              'FROM trial_application_events '
              'WHERE plots_treated IS NOT NULL AND TRIM(plots_treated) != \'\'',
            ).get();
            for (final row in rows) {
              final eventId = row.read<String>('id');
              final trialId = row.read<int>('trial_id');
              final plotsTreated = row.read<String>('plots_treated');
              final labels = plotsTreated
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              for (final label in labels) {
                // Try to resolve label to a plot PK for this trial.
                final plotRows = await customSelect(
                  'SELECT id FROM plots '
                  'WHERE trial_id = ? AND (plot_id = ? OR plot_label = ?) '
                  'AND is_deleted = 0 '
                  'LIMIT 1',
                  variables: [
                    Variable.withInt(trialId),
                    Variable.withString(label),
                    Variable.withString(label),
                  ],
                ).get();
                final plotId =
                    plotRows.isNotEmpty ? plotRows.first.read<int>('id') : null;
                await customStatement(
                  'INSERT INTO application_plot_assignments '
                  '(application_event_id, plot_label, plot_id) '
                  'VALUES (?, ?, ?)',
                  [eventId, label, plotId],
                );
              }
            }

            // ── Item 6: TreatmentComponents.rate TEXT → REAL ──
            // SQLite doesn't support ALTER COLUMN TYPE. Use the standard
            // rename → create → copy → drop pattern.
            await customStatement(
                'ALTER TABLE treatment_components '
                'RENAME COLUMN rate TO rate_text_old');
            await customStatement(
                'ALTER TABLE treatment_components '
                'ADD COLUMN rate REAL');
            await customStatement(
                'UPDATE treatment_components '
                'SET rate = CAST(REPLACE(rate_text_old, \',\', \'.\') AS REAL) '
                'WHERE rate_text_old IS NOT NULL '
                'AND rate_text_old != \'\' '
                'AND TYPEOF(CAST(REPLACE(rate_text_old, \',\', \'.\') AS REAL)) = \'real\'');
            // Drop the old column (SQLite 3.35+, iOS 15+ / Android API 34+).
            // For safety on older devices, keep the column but it is ignored
            // by the new Drift table definition. Drift only reads columns
            // declared in the table class.
          }

          if (from < 56) {
            // ── AssessmentDefinitions: new metadata columns ──
            final defCols = await customSelect(
              "SELECT name FROM pragma_table_info('assessment_definitions')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            for (final col in {
              'app_timing_code': 'TEXT',
              'trt_eval_interval': 'TEXT',
              'collect_basis': 'TEXT',
            }.entries) {
              if (!defCols.contains(col.key)) {
                await customStatement(
                    'ALTER TABLE assessment_definitions '
                    'ADD COLUMN ${col.key} ${col.value}');
              }
            }

            // ── TrialAssessments: ARM Column ID integer ──
            final taCols = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            if (!taCols.contains('arm_column_id_integer')) {
              await customStatement(
                  'ALTER TABLE trial_assessments '
                  'ADD COLUMN arm_column_id_integer INTEGER');
            }

            // ── Trials: shell internal path ──
            final trialCols = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) =>
                rows.map((r) => r.read<String>('name')).toSet());
            if (!trialCols.contains('shell_internal_path')) {
              await customStatement(
                  'ALTER TABLE trials '
                  'ADD COLUMN shell_internal_path TEXT');
            }
          }

          if (from < 57) {
            // ── Phase 1a: ARM extension tables ──
            // Additive schema only: new tables, no core-table changes.
            // Created defensively so the migration is safe to rerun.
            // These tables are empty for standalone trials by construction
            // and are only written by code under lib/data/arm/ and
            // lib/features/arm_*. See docs/ARM_SEPARATION.md.
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (!existingTables.contains('arm_column_mappings')) {
              await m.createTable(armColumnMappings);
            }
            if (!existingTables.contains('arm_assessment_metadata')) {
              await m.createTable(armAssessmentMetadata);
            }
            if (!existingTables.contains('arm_session_metadata')) {
              await m.createTable(armSessionMetadata);
            }
          }

          if (from < 58) {
            // ── Phase 0b: trial-level ARM metadata → arm_trial_metadata ──
            final tables58 = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tables58.contains('arm_trial_metadata')) {
              await m.createTable(armTrialMetadata);
            }

            final trialCols58 = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (trialCols58.contains('is_arm_linked')) {
              await customStatement('''
INSERT OR REPLACE INTO arm_trial_metadata (
  trial_id, is_arm_linked, arm_imported_at, arm_source_file, arm_version,
  arm_import_session_id, arm_linked_shell_path, arm_linked_shell_at, shell_internal_path
)
SELECT
  id,
  is_arm_linked,
  arm_imported_at,
  arm_source_file,
  arm_version,
  arm_import_session_id,
  arm_linked_shell_path,
  arm_linked_shell_at,
  shell_internal_path
FROM trials
WHERE COALESCE(is_arm_linked, 0) != 0
   OR arm_imported_at IS NOT NULL
   OR (arm_source_file IS NOT NULL AND TRIM(arm_source_file) != '')
   OR (arm_version IS NOT NULL AND TRIM(arm_version) != '')
   OR arm_import_session_id IS NOT NULL
   OR (arm_linked_shell_path IS NOT NULL AND TRIM(arm_linked_shell_path) != '')
   OR arm_linked_shell_at IS NOT NULL
   OR (shell_internal_path IS NOT NULL AND TRIM(shell_internal_path) != '')
''');
              const armTrialColsOnTrials = <String>[
                'is_arm_linked',
                'arm_imported_at',
                'arm_source_file',
                'arm_version',
                'arm_import_session_id',
                'arm_linked_shell_path',
                'arm_linked_shell_at',
                'shell_internal_path',
              ];
              for (final col in armTrialColsOnTrials) {
                final fresh = await customSelect(
                  "SELECT name FROM pragma_table_info('trials')",
                ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
                if (fresh.contains(col)) {
                  await customStatement('ALTER TABLE trials DROP COLUMN $col');
                }
              }
            }
          }

          if (from < 59) {
            // ── Phase 0b-ta (expand phase): per-column ARM fields move
            //    from trial_assessments → arm_assessment_metadata.
            //
            // Additive only: new columns are added to arm_assessment_metadata
            // and backfilled from trial_assessments. Old columns on
            // trial_assessments are kept untouched here; readers/writers are
            // flipped in later units, and the old columns are dropped in a
            // later schema bump. Safe to re-run.
            final aamCols59 = await customSelect(
              "SELECT name FROM pragma_table_info('arm_assessment_metadata')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (!aamCols59.contains('arm_import_column_index')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.armImportColumnIndex);
            }
            if (!aamCols59.contains('arm_shell_column_id')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.armShellColumnId);
            }
            if (!aamCols59.contains('arm_column_id_integer')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.armColumnIdInteger);
            }
            if (!aamCols59.contains('arm_shell_rating_date')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.armShellRatingDate);
            }

            // Ensure an arm_assessment_metadata row exists for every
            // trial_assessment that carries any ARM field. This covers
            // trials imported before Phase 1a created the metadata table,
            // where ARM data lives only on trial_assessments today.
            final taCols59 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            final hasArmFieldsOnTa = taCols59.contains('arm_import_column_index') ||
                taCols59.contains('arm_shell_column_id') ||
                taCols59.contains('arm_column_id_integer') ||
                taCols59.contains('arm_shell_rating_date') ||
                taCols59.contains('se_name') ||
                taCols59.contains('se_description') ||
                taCols59.contains('arm_rating_type') ||
                taCols59.contains('pest_code');

            if (hasArmFieldsOnTa) {
              // Build predicate only from columns that actually exist on TA.
              final predicateParts = <String>[];
              if (taCols59.contains('arm_import_column_index')) {
                predicateParts.add('arm_import_column_index IS NOT NULL');
              }
              if (taCols59.contains('arm_shell_column_id')) {
                predicateParts.add(
                    "(arm_shell_column_id IS NOT NULL AND TRIM(arm_shell_column_id) != '')");
              }
              if (taCols59.contains('arm_column_id_integer')) {
                predicateParts.add('arm_column_id_integer IS NOT NULL');
              }
              if (taCols59.contains('arm_shell_rating_date')) {
                predicateParts.add(
                    "(arm_shell_rating_date IS NOT NULL AND TRIM(arm_shell_rating_date) != '')");
              }
              if (taCols59.contains('se_name')) {
                predicateParts
                    .add("(se_name IS NOT NULL AND TRIM(se_name) != '')");
              }
              if (taCols59.contains('se_description')) {
                predicateParts.add(
                    "(se_description IS NOT NULL AND TRIM(se_description) != '')");
              }
              if (taCols59.contains('arm_rating_type')) {
                predicateParts.add(
                    "(arm_rating_type IS NOT NULL AND TRIM(arm_rating_type) != '')");
              }
              if (taCols59.contains('pest_code')) {
                predicateParts
                    .add("(pest_code IS NOT NULL AND TRIM(pest_code) != '')");
              }
              final armTaPredicate = predicateParts.join(' OR ');

              // 1) Backfill missing AAM rows for any TA that carries ARM data.
              await customStatement('''
INSERT INTO arm_assessment_metadata (trial_assessment_id, created_at)
SELECT ta.id, strftime('%s', 'now')
FROM trial_assessments ta
WHERE ($armTaPredicate)
  AND NOT EXISTS (
    SELECT 1 FROM arm_assessment_metadata aam
    WHERE aam.trial_assessment_id = ta.id
  )
''');

              // 2) Copy the 4 per-column ARM fields TA → AAM (column-by-column,
              //    only if the source column actually exists on TA).
              if (taCols59.contains('arm_import_column_index')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET arm_import_column_index = (
  SELECT arm_import_column_index FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE arm_import_column_index IS NULL
''');
              }
              if (taCols59.contains('arm_shell_column_id')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET arm_shell_column_id = (
  SELECT arm_shell_column_id FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE arm_shell_column_id IS NULL
''');
              }
              if (taCols59.contains('arm_column_id_integer')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET arm_column_id_integer = (
  SELECT arm_column_id_integer FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE arm_column_id_integer IS NULL
''');
              }
              if (taCols59.contains('arm_shell_rating_date')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET arm_shell_rating_date = (
  SELECT arm_shell_rating_date FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE arm_shell_rating_date IS NULL
''');
              }

              // 3) Backfill the already-existing AAM measurement-identity
              //    columns where AAM is NULL but TA has the value. Makes AAM
              //    a complete source of truth before later units flip reads.
              if (taCols59.contains('se_name')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET se_name = (
  SELECT se_name FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE se_name IS NULL
''');
              }
              if (taCols59.contains('se_description')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET se_description = (
  SELECT se_description FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE se_description IS NULL
''');
              }
              if (taCols59.contains('arm_rating_type')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET rating_type = (
  SELECT arm_rating_type FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE rating_type IS NULL
''');
              }
              if (taCols59.contains('pest_code')) {
                await customStatement('''
UPDATE arm_assessment_metadata
SET pest_code = (
  SELECT pest_code FROM trial_assessments
  WHERE trial_assessments.id = arm_assessment_metadata.trial_assessment_id
)
WHERE pest_code IS NULL
''');
              }
            }
          }

          if (from < 60) {
            // ── Phase 0b-ta (contract phase): drop the four per-column ARM
            //    anchor fields from trial_assessments now that
            //    arm_assessment_metadata is the source of truth (v59 backfill
            //    ran; Units 2–3 flipped writers and readers). Idempotent: we
            //    inspect the live schema before each DROP so re-runs or
            //    installs that never had the column are a no-op.
            final taCols60 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            const taColsToDrop = <String>[
              'arm_import_column_index',
              'arm_shell_column_id',
              'arm_shell_rating_date',
              'arm_column_id_integer',
            ];
            for (final col in taColsToDrop) {
              if (taCols60.contains(col)) {
                await customStatement(
                  'ALTER TABLE trial_assessments DROP COLUMN $col',
                );
              }
            }
          }

          if (from < 61) {
            // ── Unit 5d (contract phase): drop the four duplicate ARM
            //    fields from trial_assessments. pestCode / seName /
            //    seDescription / armRatingType now live only on
            //    arm_assessment_metadata. The v59 backfill populated AAM
            //    from TA for all existing rows; Unit 5b/5c flipped writers
            //    and readers; Unit 5d part 1 removed the last TA reads and
            //    writes. Idempotent: each DROP is guarded by a pragma
            //    check so re-runs or installs that never had the column
            //    are a no-op.
            final taCols61 = await customSelect(
              "SELECT name FROM pragma_table_info('trial_assessments')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            const taColsToDrop61 = <String>[
              'pest_code',
              'se_name',
              'se_description',
              'arm_rating_type',
            ];
            for (final col in taColsToDrop61) {
              if (taCols61.contains(col)) {
                await customStatement(
                  'ALTER TABLE trial_assessments DROP COLUMN $col',
                );
              }
            }
          }

          if (from < 62) {
            // ── Phase 0b-treatments: introduce arm_treatment_metadata as
            //    the destination for ARM-specific treatment coding (Type,
            //    Form Conc, Form Conc Unit, Form Type). Table only; no
            //    backfill — no writer exists yet (Phase 2 adds one) and
            //    no existing rows need rehoming. Idempotent: re-entry is
            //    a no-op when the table is already present.
            final tables62 = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tables62.contains('arm_treatment_metadata')) {
              await m.createTable(armTreatmentMetadata);
            }
          }

          if (from < 63) {
            // ── Phase 2b: backfill arm_treatment_metadata.armTypeCode from
            //    core Treatments.treatmentType for ARM-linked trials only.
            //    Preserves the ARM-verbatim coding (HERB/FUNG/CHK/…) as a
            //    round-trip-safe source even if a later edit humanizes the
            //    core display value. Core column is NOT nulled — core UI
            //    and control-treatment detection continue to read it.
            //
            //    Idempotent: a treatment that already has an AAM row is
            //    left untouched. Standalone trials (no arm_trial_metadata
            //    row, or isArmLinked = 0) are never modified.
            await customStatement('''
              INSERT INTO arm_treatment_metadata (treatment_id, arm_type_code)
              SELECT t.id, t.treatment_type
              FROM treatments t
              JOIN arm_trial_metadata atm ON atm.trial_id = t.trial_id
              WHERE atm.is_arm_linked = 1
                AND t.treatment_type IS NOT NULL
                AND TRIM(t.treatment_type) <> ''
                AND NOT EXISTS (
                  SELECT 1 FROM arm_treatment_metadata x
                  WHERE x.treatment_id = t.id
                )
            ''');
          }

          if (from < 64) {
            // ── Phase 1: full Plot Data descriptor capture on AAM (rows 8–46).
            final aamCols64 = await customSelect(
              "SELECT name FROM pragma_table_info('arm_assessment_metadata')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (!aamCols64.contains('shell_pest_type')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestType);
            }
            if (!aamCols64.contains('shell_pest_name')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestName);
            }
            if (!aamCols64.contains('shell_crop_code')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropCode);
            }
            if (!aamCols64.contains('shell_crop_name')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropName);
            }
            if (!aamCols64.contains('shell_crop_variety')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropVariety);
            }
            if (!aamCols64.contains('shell_rating_time')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellRatingTime);
            }
            if (!aamCols64.contains('shell_crop_or_pest')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropOrPest);
            }
            if (!aamCols64.contains('shell_sample_size')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellSampleSize);
            }
            if (!aamCols64.contains('shell_size_unit')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellSizeUnit);
            }
            if (!aamCols64.contains('shell_collection_basis_unit')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellCollectionBasisUnit);
            }
            if (!aamCols64.contains('shell_reporting_basis')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellReportingBasis);
            }
            if (!aamCols64.contains('shell_reporting_basis_unit')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellReportingBasisUnit);
            }
            if (!aamCols64.contains('shell_stage_scale')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellStageScale);
            }
            if (!aamCols64.contains('shell_crop_stage_maj')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropStageMaj);
            }
            if (!aamCols64.contains('shell_crop_stage_min')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropStageMin);
            }
            if (!aamCols64.contains('shell_crop_stage_max')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropStageMax);
            }
            if (!aamCols64.contains('shell_crop_density')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellCropDensity);
            }
            if (!aamCols64.contains('shell_crop_density_unit')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellCropDensityUnit);
            }
            if (!aamCols64.contains('shell_pest_stage_maj')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestStageMaj);
            }
            if (!aamCols64.contains('shell_pest_stage_min')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestStageMin);
            }
            if (!aamCols64.contains('shell_pest_stage_max')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestStageMax);
            }
            if (!aamCols64.contains('shell_pest_density')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellPestDensity);
            }
            if (!aamCols64.contains('shell_pest_density_unit')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellPestDensityUnit);
            }
            if (!aamCols64.contains('shell_assessed_by')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellAssessedBy);
            }
            if (!aamCols64.contains('shell_equipment')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellEquipment);
            }
            if (!aamCols64.contains('shell_untreated_rating_type')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellUntreatedRatingType);
            }
            if (!aamCols64.contains('shell_arm_actions')) {
              await m.addColumn(
                  armAssessmentMetadata, armAssessmentMetadata.shellArmActions);
            }
          }

          if (from < 65) {
            // ── Phase 1: timing + interval descriptor rows on AAM (Plot Data
            //    rows 42–44, 0-based 41–43) for round-trip + Protocol tab.
            final aamCols65 = await customSelect(
              "SELECT name FROM pragma_table_info('arm_assessment_metadata')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());

            if (!aamCols65.contains('shell_app_timing_code')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellAppTimingCode);
            }
            if (!aamCols65.contains('shell_trt_eval_interval')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellTrtEvalInterval);
            }
            if (!aamCols65.contains('shell_plant_eval_interval')) {
              await m.addColumn(armAssessmentMetadata,
                  armAssessmentMetadata.shellPlantEvalInterval);
            }
          }

          if (from < 66) {
            // ── Phase 3a: ARM Applications sheet extension (79 verbatim
            //    descriptor rows per [TrialApplicationEvents]). Parser +
            //    importer land in Phase 3b/3c.
            final tables66 = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tables66.contains('arm_applications')) {
              await m.createTable(armApplications);
            }
          }
          if (from < 67) {
            final cols67 = await customSelect(
              "SELECT name FROM pragma_table_info('arm_trial_metadata')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!cols67.contains('shell_comments_sheet')) {
              await m.addColumn(
                armTrialMetadata,
                armTrialMetadata.shellCommentsSheet,
              );
            }
          }
          if (from < 68) {
            final userCols = await customSelect(
              "SELECT name FROM pragma_table_info('users')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!userCols.contains('pin_hash')) {
              await m.addColumn(users, users.pinHash);
            }
            if (!userCols.contains('pin_enabled')) {
              await m.addColumn(users, users.pinEnabled);
            }
          }
          if (from < 69) {
            final seCols = await customSelect(
              "SELECT name FROM pragma_table_info('seeding_events')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            for (final entry in {
              'temperature_c': 'REAL',
              'humidity_pct': 'REAL',
              'wind_speed_kmh': 'REAL',
              'wind_direction': 'TEXT',
              'cloud_cover_pct': 'REAL',
              'precipitation': 'TEXT',
              'precipitation_mm': 'REAL',
              'soil_moisture': 'TEXT',
              'soil_temperature': 'REAL',
              'conditions_recorded_at': 'INTEGER',
              'captured_latitude': 'REAL',
              'captured_longitude': 'REAL',
              'location_captured_at': 'INTEGER',
            }.entries) {
              if (!seCols.contains(entry.key)) {
                await customStatement(
                  'ALTER TABLE seeding_events ADD COLUMN ${entry.key} ${entry.value}',
                );
              }
            }
          }

          if (from < 70) {
            final taeCols = await customSelect(
              "SELECT name FROM pragma_table_info('trial_application_events')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            for (final entry in {
              'captured_latitude': 'REAL',
              'captured_longitude': 'REAL',
              'location_captured_at': 'INTEGER',
            }.entries) {
              if (!taeCols.contains(entry.key)) {
                await customStatement(
                  'ALTER TABLE trial_application_events ADD COLUMN ${entry.key} ${entry.value}',
                );
              }
            }
          }

          if (from < 71) {
            final tapCols = await customSelect(
              "SELECT name FROM pragma_table_info('trial_application_products')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!tapCols.contains('lot_code')) {
              await customStatement(
                'ALTER TABLE trial_application_products ADD COLUMN lot_code TEXT',
              );
            }
          }

          if (from < 72) {
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!existingTables.contains('se_type_profiles')) {
              await m.createTable(seTypeProfiles);
            }
            await _seedSeTypeProfiles();
          }

          if (from < 73) {
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!existingTables.contains('signals')) {
              await m.createTable(signals);
            }
            if (!existingTables.contains('signal_decision_events')) {
              await m.createTable(signalDecisionEvents);
            }
            if (!existingTables.contains('action_effects')) {
              await m.createTable(actionEffects);
            }
            if (!existingTables.contains('se_type_causal_profiles')) {
              await m.createTable(seTypeCausalProfiles);
            }
            if (!existingTables.contains('evidence_anchors')) {
              await m.createTable(evidenceAnchors);
            }
            await _seedSeTypeCausalProfiles();
          }

          if (from < 74) {
            final trialCols = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!trialCols.contains('region')) {
              // NOT NULL DEFAULT 'eppo_eu' fills all existing rows automatically.
              await customStatement(
                "ALTER TABLE trials ADD COLUMN region TEXT NOT NULL DEFAULT 'eppo_eu'",
              );
            }
          }

          if (from < 75) {
            final profileCols = await customSelect(
              "SELECT name FROM pragma_table_info('se_type_causal_profiles')",
            ).get().then((rows) => rows.map((r) => r.read<String>('name')).toSet());
            if (!profileCols.contains('region')) {
              // Step 1: add the two new columns to the existing table so the
              // data copy below works with a simple SELECT *.
              await customStatement(
                'ALTER TABLE se_type_causal_profiles ADD COLUMN region TEXT',
              );
              await customStatement(
                "ALTER TABLE se_type_causal_profiles ADD COLUMN window_type TEXT DEFAULT 'bbch'",
              );
              // Step 2: rebuild to change inline UNIQUE(se_type, trial_type)
              // → UNIQUE(se_type, trial_type, region). SQLite does not support
              // DROP CONSTRAINT, so a rename-recreate-copy cycle is required.
              await customStatement(
                'ALTER TABLE se_type_causal_profiles RENAME TO se_type_causal_profiles_v73',
              );
              await m.createTable(seTypeCausalProfiles);
              await customStatement('''
INSERT INTO se_type_causal_profiles (
  id, se_type, trial_type, causal_window_days_min, causal_window_days_max,
  expected_response_direction, expected_change_rate_per_week,
  spatial_clustering_expected, untreated_excluded_from_mean,
  base_threshold_sd_multiplier, source, source_reference,
  region, window_type, created_at
)
SELECT
  id, se_type, trial_type, causal_window_days_min, causal_window_days_max,
  expected_response_direction, expected_change_rate_per_week,
  spatial_clustering_expected, untreated_excluded_from_mean,
  base_threshold_sd_multiplier, source, source_reference,
  region, window_type, created_at
FROM se_type_causal_profiles_v73
''');
              await customStatement('DROP TABLE se_type_causal_profiles_v73');
              await customStatement('''
INSERT OR REPLACE INTO sqlite_sequence (name, seq)
SELECT 'se_type_causal_profiles', COALESCE((SELECT MAX(id) FROM se_type_causal_profiles), 0)
''');
            }
          }

          if (from < 76) {
            // Data-repair: advance trials that have session data but were left
            // in draft/ready due to silent promoteTrialToActiveIfReady failures.
            // Idempotent — running twice updates zero rows on the second run.
            await customStatement('''
UPDATE trials
SET status = 'active'
WHERE status IN ('draft', 'ready')
  AND id IN (SELECT DISTINCT trial_id FROM sessions WHERE is_deleted = 0)
''');
          }

          if (from < 77) {
            // Change 1: drop projection column — zero consumers confirmed in
            // Phase A audit. Guard: fresh-install schemas wound back to an older
            // user_version in test environments never had this column.
            final ydCols = await customSelect(
                    "SELECT name FROM pragma_table_info('yield_details')")
                .get();
            if (ydCols.any((r) => r.read<String>('name') == 'converted_yield')) {
              await customStatement(
                  'ALTER TABLE yield_details DROP COLUMN converted_yield');
            }
            // Change 2: replace broken partial unique index on rating_records.
            // _createIndexes() uses IF NOT EXISTS throughout, so without an
            // explicit DROP the null-hole form (bare sub_unit_id) would survive
            // on every existing device. The DROP lets _createIndexes() below
            // recreate it with the COALESCE expression that closes the gap.
            await customStatement('DROP INDEX IF EXISTS idx_rating_current');
            // Change 3: sync trigger so signals.status is always consistent
            // with the immutable signal_decision_events log. The manual UPDATE
            // in SignalRepository.recordDecisionEvent() stays as an idempotent
            // safety net — having both is harmless.
            await customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_signal_status
AFTER INSERT ON signal_decision_events
BEGIN
  UPDATE signals SET status = NEW.resulting_status WHERE id = NEW.signal_id;
END
''');
          }

          if (from < 78) {
            final existingTables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final tableNames =
                existingTables.map((r) => r.read<String>('name')).toSet();
            if (!tableNames.contains('trial_purposes')) {
              await m.createTable(trialPurposes);
            }
            if (!tableNames.contains('intent_revelation_events')) {
              await m.createTable(intentRevelationEvents);
            }
            if (!tableNames.contains('ctq_factor_definitions')) {
              await m.createTable(ctqFactorDefinitions);
            }
            if (!tableNames.contains('protocol_document_references')) {
              await m.createTable(protocolDocumentReferences);
            }
            final trialCols = await customSelect(
              "SELECT name FROM pragma_table_info('trials')",
            ).get();
            final trialColNames =
                trialCols.map((r) => r.read<String>('name')).toSet();
            if (!trialColNames.contains('field_orientation_degrees')) {
              await m.addColumn(trials, trials.fieldOrientationDegrees);
            }
            if (!trialColNames.contains('field_anchor_type')) {
              await m.addColumn(trials, trials.fieldAnchorType);
            }
          }

          await _createIndexes();
        },
      );

  /// Call after reset or when definitions table is empty. Idempotent: only inserts if table is empty.
  Future<void> ensureAssessmentDefinitionsSeeded() async {
    final existing = await select(assessmentDefinitions).get();
    if (existing.isEmpty) {
      await _seedAssessmentDefinitions();
    }
  }

  Future<void> _seedAssessmentDefinitions() async {
    const rows = [
      ['CROP_INJURY', 'Crop injury', 'crop_injury', 'numeric', '%', 0.0, 100.0],
      [
        'DISEASE_SEV',
        'Disease severity',
        'disease',
        'numeric',
        '%',
        0.0,
        100.0
      ],
      ['WEED_COVER', 'Weed cover', 'weed', 'numeric', '%', 0.0, 100.0],
      ['PLANT_HEIGHT', 'Plant height', 'growth', 'numeric', 'cm', 0.0, 9999.0],
      [
        'STAND_COUNT',
        'Stand count',
        'growth',
        'numeric',
        'plants/plot',
        0.0,
        99999.0
      ],
      ['YIELD', 'Yield', 'yield', 'numeric', 'kg/ha', 0.0, 99999.0],
      [
        'PHENOLOGY_BBCH',
        'Growth stage (BBCH)',
        'phenology',
        'numeric',
        null,
        0.0,
        99.0
      ],
      ['QUALITY_GRADE', 'Quality grade', 'quality', 'numeric', null, 1.0, 9.0],
      ['NOTES', 'Notes / observation', 'custom', 'text', null, null, null],
    ];
    for (final r in rows) {
      await customStatement(
        'INSERT INTO assessment_definitions (code, name, category, data_type, unit, scale_min, scale_max, result_direction, is_system, is_active, created_at, updated_at) '
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'neutral', 1, 1, strftime('%s','now'), strftime('%s','now'))",
        [r[0], r[1], r[2], r[3], r[4], r[5], r[6]],
      );
    }
  }

  Future<void> _seedSeTypeProfiles() async {
    // MVP seed rows — conservative defaults pending calibration from EPPO PP1
    // and ARM field data post-pilot. INSERT OR IGNORE: idempotent; ratingTypePrefix is UNIQUE.
    const sql = 'INSERT OR IGNORE INTO se_type_profiles '
        '(rating_type_prefix, display_name, measurement_category, response_direction, '
        'valid_observation_window_min_dat, valid_observation_window_max_dat, '
        'expected_cv_min, expected_cv_max, scale_min, scale_max, source, notes, created_at) '
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%s','now'))";
    await customStatement(sql, [
      'CONTRO', 'Weed Control', 'percent', 'higher_better',
      7, null, null, null, 0.0, 100.0, 'ARM_CONVENTION',
      'MVP default — min DAT conservative; CV range pending calibration',
    ]);
    await customStatement(sql, [
      'PHYGEN', 'Crop Injury — Phytotoxicity', 'percent', 'lower_better',
      3, null, null, null, 0.0, 100.0, 'EPPO_PP1',
      'MVP default — min DAT conservative; CV range pending calibration from PP1/135',
    ]);
  }

  /// EPPO-aligned causal SE profiles (CONTRO / PESINC / LODGIN × efficacy).
  /// INSERT OR IGNORE — unique on (se_type, trial_type, region).
  /// All seed rows have region NULL (applies to any region). SQLite treats
  /// NULLs as distinct in UNIQUE constraints; seeding is only called once
  /// (onCreate) so duplicates cannot accumulate.
  Future<void> _seedSeTypeCausalProfiles() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<void> insertRow(List<Object?> params) async {
      await customStatement(
        'INSERT OR IGNORE INTO se_type_causal_profiles '
        '(se_type, trial_type, causal_window_days_min, causal_window_days_max, '
        'expected_response_direction, expected_change_rate_per_week, '
        'spatial_clustering_expected, untreated_excluded_from_mean, '
        'base_threshold_sd_multiplier, source, source_reference, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        params,
      );
    }

    await insertRow([
      'CONTRO',
      'efficacy',
      7,
      28,
      'increase',
      8.0,
      0,
      1,
      2.0,
      'EPPO_PP1',
      'PP1/152',
      now,
    ]);
    await insertRow([
      'PESINC',
      'efficacy',
      7,
      21,
      'decrease',
      5.0,
      1,
      1,
      2.5,
      'EPPO_PP1',
      'PP1/135',
      now,
    ]);
    await insertRow([
      'LODGIN',
      'efficacy',
      0,
      0,
      'stable',
      2.0,
      1,
      0,
      3.0,
      'EPPO_PP1',
      'PP1/152',
      now,
    ]);
  }

  Future<void> _createIndexes() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_rating_current
      ON rating_records(trial_id, plot_pk, assessment_id, session_id, COALESCE(sub_unit_id, -1))
      WHERE is_current = 1
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_rating_lookup
      ON rating_records(trial_id, plot_pk, assessment_id, session_id, is_current)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_plots_trial
      ON plots(trial_id, plot_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_session_assessments
      ON session_assessments(session_id, assessment_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_photos_lookup
      ON photos(trial_id, session_id, plot_pk)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_audit_events
      ON audit_events(trial_id, created_at)
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_seeding_events_trial ON seeding_events(trial_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_weather_snapshots_parent ON weather_snapshots(parent_type, parent_id)',
    );
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_treatments_trial
      ON treatments(trial_id, is_deleted)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_trial_assessments_trial
      ON trial_assessments(trial_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_assignments_plot
      ON assignments(plot_id, trial_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_assessments_trial
      ON assessments(trial_id, name)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_trials_workspace
      ON trials(workspace_type, is_deleted)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sessions_trial
      ON sessions(trial_id)
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_arm_applications_event '
      'ON arm_applications(trial_application_event_id)',
    );
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_signals_trial_status
      ON signals(trial_id, status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_signals_session
      ON signals(session_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_signals_open
      ON signals(status)
      WHERE status IN ('open', 'deferred', 'investigating')
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sde_signal_time
      ON signal_decision_events(signal_id, occurred_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sde_actor
      ON signal_decision_events(actor_user_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sde_followup
      ON signal_decision_events(follow_up_due_at)
      WHERE follow_up_due_at IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_action_effects_event
      ON action_effects(decision_event_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_evidence_anchors_claim
      ON evidence_anchors(claim_type, claim_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_se_profiles_type
      ON se_type_causal_profiles(se_type, trial_type, region)
    ''');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'arm_field_companion.db'));
    return NativeDatabase.createInBackground(file);
  });
}
