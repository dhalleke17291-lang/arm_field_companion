import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_database.g.dart';

class Trials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get crop => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get season => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
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
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get sessionDateLocal => text()();
  TextColumn get raterName => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
}

class SessionAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
}

class RatingRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  IntColumn get plotPk => integer().references(Plots, #id)();
  IntColumn get assessmentId => integer().references(Assessments, #id)();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().nullable()();
}

class ImportEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trialId => integer().references(Trials, #id)();
  TextColumn get fileName => text()();
  TextColumn get status => text()();
  IntColumn get rowsImported => integer().withDefault(const Constant(0))();
  IntColumn get rowsSkipped => integer().withDefault(const Constant(0))();
  TextColumn get warnings => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Trials,
  Treatments,
  TreatmentComponents,
  Assessments,
  Plots,
  Sessions,
  SessionAssessments,
  RatingRecords,
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
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
          await _createIndexes();
        },
      );

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
