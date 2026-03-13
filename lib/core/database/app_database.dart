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
  TextColumn get roleKey =>
      text().withDefault(const Constant('technician'))();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Treatments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get code => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
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
}

/// Trial-specific selection from library. Sessions only show assessments enabled here (or legacy Assessments).
class TrialAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get assessmentDefinitionId => integer().references(AssessmentDefinitions, #id)();
  TextColumn get displayNameOverride => text().nullable()();
  BoolColumn get required => boolean().withDefault(const Constant(false))();
  BoolColumn get selectedFromProtocol => boolean().withDefault(const Constant(false))();
  BoolColumn get selectedManually => boolean().withDefault(const Constant(true))();
  BoolColumn get defaultInSessions => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get timingMode => text().nullable()();
  IntColumn get daysAfterPlanting => integer().nullable()();
  IntColumn get daysAfterTreatment => integer().nullable()();
  TextColumn get growthStage => text().nullable()();
  TextColumn get methodOverride => text().nullable()();
  TextColumn get instructionOverride => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get legacyAssessmentId => integer().references(Assessments, #id).nullable()();
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
}

class SessionAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
  IntColumn get trialAssessmentId => integer().references(TrialAssessments, #id).nullable()();
  /// User-defined order for rating flow (0, 1, 2, …). Same sequence applies to every plot.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RatingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
  IntColumn get trialAssessmentId => integer().references(TrialAssessments, #id).nullable()();
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
  IntColumn get correctedByUserId => integer().references(Users, #id).nullable()();
  DateTimeColumn get correctedAt => dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get applicationSlotId => integer().references(ApplicationSlots, #id).nullable()();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Application events per trial (multiple per trial). FK types match Trials.id and Treatments.id (IntColumn).
/// days_after_seeding is never stored — derived at read time from application_date minus seeding date.
class TrialApplicationEvents extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get treatmentId => integer().references(Treatments, #id).nullable()();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
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
])
class AppDatabase extends _$AppDatabase {
  /// In-memory database for testing only.
  AppDatabase.forTesting(super.e);

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 17;

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
            await m.addColumn(sessionAssessments, sessionAssessments.trialAssessmentId);
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
      ['DISEASE_SEV', 'Disease severity', 'disease', 'numeric', '%', 0.0, 100.0],
      ['WEED_COVER', 'Weed cover', 'weed', 'numeric', '%', 0.0, 100.0],
      ['PLANT_HEIGHT', 'Plant height', 'growth', 'numeric', 'cm', 0.0, 9999.0],
      ['STAND_COUNT', 'Stand count', 'growth', 'numeric', 'plants/plot', 0.0, 99999.0],
      ['YIELD', 'Yield', 'yield', 'numeric', 'kg/ha', 0.0, 99999.0],
      ['PHENOLOGY_BBCH', 'Growth stage (BBCH)', 'phenology', 'numeric', null, 0.0, 99.0],
      ['QUALITY_GRADE', 'Quality grade', 'quality', 'numeric', null, 1.0, 9.0],
      ['NOTES', 'Notes / observation', 'custom', 'text', null, null, null],
    ];
    for (final r in rows) {
      await customStatement(
        'INSERT INTO assessment_definitions (code, name, category, data_type, unit, scale_min, scale_max, is_system, is_active, created_at, updated_at) '
        "VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, strftime('%s','now'), strftime('%s','now'))",
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
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'arm_field_companion.db'));
    return NativeDatabase.createInBackground(file);
  });
}
