import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrialRepository trialRepo;
  late ArmImportPersistenceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trialRepo = TrialRepository(db);
    repo = ArmImportPersistenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insertImportSnapshot writes row', () async {
    final trialId =
        await trialRepo.createTrial(name: 'T', workspaceType: 'efficacy');
    const payload = ImportSnapshotPayload(
      sourceFile: 'a.csv',
      sourceRoute: 'arm_csv_v1',
      armVersion: '1.0',
      rawHeaders: ['Plot'],
      columnOrder: ['Plot', 'trt'],
      rowTypePatterns: ['plot'],
      plotCount: 2,
      treatmentCount: 1,
      assessmentCount: 1,
      identityColumns: ['Plot'],
      assessmentTokens: [
        {'h': 'x'},
      ],
      treatmentTokens: [],
      plotTokens: [],
      unknownPatterns: [],
      hasSubsamples: false,
      hasMultiApplication: false,
      hasSparseData: false,
      hasRepeatedCodes: false,
      rawFileChecksum: 'chk',
    );

    final id = await repo.insertImportSnapshot(payload, trialId: trialId);
    final row = await (db.select(db.importSnapshots)
          ..where((s) => s.id.equals(id)))
        .getSingle();

    expect(row.trialId, trialId);
    expect(row.sourceFile, 'a.csv');
    expect(jsonDecode(row.rawHeaders), ['Plot']);
    expect(jsonDecode(row.assessmentTokens), [
      {'h': 'x'},
    ]);
    expect(row.capturedAt, isNotNull);
  });

  test('insertCompatibilityProfile writes row', () async {
    final trialId =
        await trialRepo.createTrial(name: 'T2', workspaceType: 'efficacy');
    const snapPayload = ImportSnapshotPayload(
      sourceFile: 'b.csv',
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
      rawFileChecksum: 'x',
    );
    final snapshotId =
        await repo.insertImportSnapshot(snapPayload, trialId: trialId);

    const profilePayload = CompatibilityProfilePayload(
      exportRoute: 'arm_xml_v1',
      columnMap: {'a': 1},
      plotMap: {'p': 'q'},
      treatmentMap: {'t': 'u'},
      dataStartRow: 5,
      headerEndRow: 2,
      identityRowMarkers: [1, 'h'],
      columnOrderOnExport: ['Plot'],
      identityFieldOrder: ['Plot'],
      knownUnsupported: ['x'],
      exportConfidence: ImportConfidence.medium,
      exportBlockReason: null,
    );

    final profileId = await repo.insertCompatibilityProfile(
      profilePayload,
      trialId: trialId,
      snapshotId: snapshotId,
    );

    final row = await (db.select(db.compatibilityProfiles)
          ..where((c) => c.id.equals(profileId)))
        .getSingle();

    expect(row.trialId, trialId);
    expect(row.snapshotId, snapshotId);
    expect(jsonDecode(row.columnMap), {'a': 1});
    expect(row.exportConfidence, ImportConfidence.medium.name);
    expect(row.createdAt, isNotNull);
  });

  test('getLatestExportConfidenceForTrial returns newest compatibility row',
      () async {
    final trialId =
        await trialRepo.createTrial(name: 'T_latest', workspaceType: 'efficacy');
    const snapPayload = ImportSnapshotPayload(
      sourceFile: 'c.csv',
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
      rawFileChecksum: 'c1',
    );
    final snap1 = await repo.insertImportSnapshot(snapPayload, trialId: trialId);
    await repo.insertCompatibilityProfile(
      const CompatibilityProfilePayload(
        exportRoute: 'r',
        columnMap: {},
        plotMap: {},
        treatmentMap: {},
        dataStartRow: 1,
        headerEndRow: 1,
        identityRowMarkers: [],
        columnOrderOnExport: [],
        identityFieldOrder: [],
        knownUnsupported: [],
        exportConfidence: ImportConfidence.low,
      ),
      trialId: trialId,
      snapshotId: snap1,
    );
    const snapPayload2 = ImportSnapshotPayload(
      sourceFile: 'd.csv',
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
      rawFileChecksum: 'c2',
    );
    final snap2 = await repo.insertImportSnapshot(snapPayload2, trialId: trialId);
    await repo.insertCompatibilityProfile(
      const CompatibilityProfilePayload(
        exportRoute: 'r',
        columnMap: {},
        plotMap: {},
        treatmentMap: {},
        dataStartRow: 1,
        headerEndRow: 1,
        identityRowMarkers: [],
        columnOrderOnExport: [],
        identityFieldOrder: [],
        knownUnsupported: [],
        exportConfidence: ImportConfidence.high,
      ),
      trialId: trialId,
      snapshotId: snap2,
    );

    expect((await repo.getLatestExportConfidenceForTrial(trialId)),
        ImportConfidence.high.name);
    expect(
      await repo.getLatestExportBlockReasonForTrial(trialId),
      isNull,
    );
  });

  test('markTrialAsArmLinked updates trial flags', () async {
    final trialId =
        await trialRepo.createTrial(name: 'T3', workspaceType: 'efficacy');

    await repo.markTrialAsArmLinked(
      trialId: trialId,
      sourceFile: '/path/file.csv',
      armVersion: '2.1',
    );

    final t = await trialRepo.getTrialById(trialId);
    expect(t, isNotNull);
    expect(t!.isArmLinked, isTrue);
    expect(t.armSourceFile, '/path/file.csv');
    expect(t.armVersion, '2.1');
    expect(t.armImportedAt, isNotNull);
  });
}
