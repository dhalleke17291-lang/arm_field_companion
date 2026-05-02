import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/export/export_trial_usecase.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/seeding_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _insertHighConfidenceProfile(
    AppDatabase db, int trialId) async {
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
  final snapshotId = await repo.insertImportSnapshot(snapPayload, trialId: trialId);
  const profilePayload = CompatibilityProfilePayload(
    exportRoute: 'arm_xml_v1',
    columnMap: {},
    plotMap: {},
    treatmentMap: {},
    dataStartRow: 2,
    headerEndRow: 1,
    identityRowMarkers: [],
    columnOrderOnExport: [],
    identityFieldOrder: [],
    knownUnsupported: [],
    exportConfidence: ImportConfidence.high,
    exportBlockReason: null,
  );
  await repo.insertCompatibilityProfile(
    profilePayload,
    trialId: trialId,
    snapshotId: snapshotId,
  );
}

ExportTrialUseCase _exportUseCase(AppDatabase db) {
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

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('trial flat export notes.csv lists trial-level field note', () async {
    final trialRepo = TrialRepository(db);
    final trialId =
        await trialRepo.createTrial(name: 'ExportNote', workspaceType: 'efficacy');
    await _insertHighConfidenceProfile(db, trialId);
    await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
    await NotesRepository(db).createNote(
      trialId: trialId,
      content: 'Trial-level observation',
      createdBy: 'Exporter',
    );
    final bundle = await _exportUseCase(db).execute(
      trial: Trial(
        id: trialId,
        name: 'ExportNote',
        status: 'active',
        workspaceType: 'efficacy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        region: 'eppo_eu',
        isDeleted: false,
      ),
      format: ExportFormat.flatCsv,
    );
    expect(bundle.notesCsv, contains('Trial-level observation'));
    expect(bundle.notesCsv, contains('ExportNote'));
  });
}
