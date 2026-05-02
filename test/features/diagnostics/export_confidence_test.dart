import 'package:arm_field_companion/core/database/app_database.dart'
    show AppDatabase, Trial;
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/export/export_trial_usecase.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertCompatibilityProfile({
  required AppDatabase db,
  required int trialId,
  required ImportConfidence exportConfidence,
}) async {
  final repo = ArmImportPersistenceRepository(db);
  const snapPayload = ImportSnapshotPayload(
    sourceFile: 't.csv',
    sourceRoute: 'arm_csv_v1',
    armVersion: null,
    rawHeaders: [],
    columnOrder: [],
    rowTypePatterns: [],
    plotCount: 0,
    treatmentCount: 0,
    assessmentCount: 0,
    identityColumns: [],
    assessmentTokens: [],
    treatmentTokens: [],
    plotTokens: [],
    unknownPatterns: [],
    hasSubsamples: false,
    hasMultiApplication: false,
    hasSparseData: false,
    hasRepeatedCodes: false,
    rawFileChecksum: 'chk',
  );
  final snapshotId =
      await repo.insertImportSnapshot(snapPayload, trialId: trialId);
  final profilePayload = CompatibilityProfilePayload(
    exportRoute: 'arm_xml_v1',
    columnMap: {},
    plotMap: {},
    treatmentMap: {},
    dataStartRow: 2,
    headerEndRow: 1,
    identityRowMarkers: const [],
    columnOrderOnExport: const [],
    identityFieldOrder: const [],
    knownUnsupported: const [],
    exportConfidence: exportConfidence,
    exportBlockReason: null,
  );
  await repo.insertCompatibilityProfile(
    profilePayload,
    trialId: trialId,
    snapshotId: snapshotId,
  );
}

ExportTrialUseCase _makeUseCase(AppDatabase db) {
  return ExportTrialUseCase(
    db: db,
    trialRepository: TrialRepository(db),
    plotRepository: PlotRepository(db),
    treatmentRepository: TreatmentRepository(db),
    applicationRepository: ApplicationRepository(db),
    applicationProductRepository: ApplicationProductRepository(db),
    seedingRepository: SeedingRepository(db),
    sessionRepository: SessionRepository(db),
    ratingRepository: RatingRepository(db),
    assignmentRepository: AssignmentRepository(db),
    photoRepository: PhotoRepository(db),
    weatherSnapshotRepository: WeatherSnapshotRepository(db),
    notesRepository: NotesRepository(db),
    armImportPersistenceRepository: ArmImportPersistenceRepository(db),
  );
}

Trial _trialFromId(int id) => Trial(
      id: id,
      name: 'T',
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      region: 'eppo_eu',
      isDeleted: false,
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('flat CSV export runs validation and records preflight warnings', () async {
    final trialRepo = TrialRepository(db);
    final trialId =
        await trialRepo.createTrial(name: 'Preflight', workspaceType: 'efficacy');
    await _insertCompatibilityProfile(
      db: db,
      trialId: trialId,
      exportConfidence: ImportConfidence.high,
    );
    await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
    final uc = _makeUseCase(db);
    final trial = _trialFromId(trialId);

    final bundle = await uc.execute(trial: trial, format: ExportFormat.flatCsv);
    expect(bundle.preflightNotes, isNotNull);
    expect(bundle.preflightNotes, isNotEmpty);
    expect(
      bundle.preflightNotes!.join(' '),
      contains('treatment'),
    );
  });
}
