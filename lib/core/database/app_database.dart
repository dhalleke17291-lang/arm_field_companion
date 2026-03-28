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

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
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
}

class TreatmentComponents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get treatmentId => integer().references(Treatments, #id)();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get productName => text().withLength(min: 1, max: 255)();
  TextColumn get rate => text().nullable()();
  TextColumn get rateUnit => text().nullable()();
  TextColumn get applicationTiming => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get activeIngredientPct => real().nullable()();
  TextColumn get formulationType => text().nullable()();
  TextColumn get manufacturer => text().nullable()();
  TextColumn get registrationNumber => text().nullable()();
  TextColumn get eppoCode => text().nullable()();
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

  TextColumn get timingCode => text().nullable()();
  IntColumn get daysAfterTreatment => integer().nullable()();
  TextColumn get assessmentMethod => text().nullable()();
  RealColumn get validMin => real().nullable()();
  RealColumn get validMax => real().nullable()();
  TextColumn get eppoCode => text().nullable()();
  TextColumn get cropPart => text().nullable()();
  TextColumn get timingDescription => text().nullable()();
  TextColumn get resultDirection =>
      text().withDefault(const Constant('neutral'))();
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
  TextColumn get notes => text().nullable()();

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

  /// Field layout: non-data / border plot (v1: display + flag only; no workflow change).
  BoolColumn get isGuardRow => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
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
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
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
])
class AppDatabase extends _$AppDatabase {
  /// In-memory database for testing only.
  AppDatabase.forTesting(super.e);

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 34;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
          await _seedAssessmentDefinitions();
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

  Future<void> _createIndexes() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_rating_current
      ON rating_records(trial_id, plot_pk, assessment_id, session_id, sub_unit_id)
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
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'arm_field_companion.db'));
    return NativeDatabase.createInBackground(file);
  });
}
