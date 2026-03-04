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
  IntColumn get treatmentId => integer().references(Treatments, #id).nullable()();
  TextColumn get row => text().nullable()();
  TextColumn get column => text().nullable()();
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
  TextColumn get resultStatus => text().withDefault(const Constant('RECORDED'))();
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
  IntColumn get ratingRecordId => integer().references(RatingRecords, #id).nullable()();
  TextColumn get deviationType => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get raterName => text().nullable()();
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
  Assessments,
  Plots,
  Sessions,
  SessionAssessments,
  RatingRecords,
  Notes,
  Photos,
  PlotFlags,
  DeviationFlags,
  AuditEvents,
  ImportEvents,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
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
