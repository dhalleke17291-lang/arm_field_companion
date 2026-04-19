import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:arm_field_companion/core/config/app_info.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/data/arm_import_persistence_repository.dart';
import 'package:arm_field_companion/features/arm_import/domain/enums/import_confidence.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/compatibility_profile_payload.dart';
import 'package:arm_field_companion/features/arm_import/domain/models/import_snapshot_payload.dart';
import 'package:arm_field_companion/features/export/export_format.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:uuid/uuid.dart';

import '../../stress/stress_import_helpers.dart';
import '../../support/session_date_test_utils.dart';

const MethodChannel _kShareChannel =
    MethodChannel('dev.fluttercommunity.plus/share');

String? _lastSharedZipPath;

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.docs, this.tmp);
  final String docs;
  final String tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

Future<void> _insertCompatibilityProfile({
  required AppDatabase db,
  required int trialId,
  ImportConfidence exportConfidence = ImportConfidence.high,
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

void _installShareZipCaptureMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_kShareChannel, (call) async {
    // share_plus_platform_interface v4 uses `shareFiles` for shareXFiles;
    // newer versions use `share` with a unified params map.
    if (call.method == 'shareFiles' || call.method == 'share') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final paths = args?['paths'];
      if (paths is List && paths.isNotEmpty) {
        _lastSharedZipPath = paths.first as String?;
      }
      return 'success';
    }
    return null;
  });
}

void _clearShareMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_kShareChannel, null);
}

Future<Archive> _runArmHandoffAndDecodeZip(
  AppDatabase db,
  Trial trial,
) async {
  _lastSharedZipPath = null;
  await exportStressTrialUseCase(db).execute(
    trial: trial,
    format: ExportFormat.armHandoff,
  );
  final path = _lastSharedZipPath;
  expect(path, isNotNull);
  expect(path!.toLowerCase().endsWith('.zip'), isTrue);
  final bytes = await File(path).readAsBytes();
  return ZipDecoder().decodeBytes(bytes);
}

List<ArchiveFile> _photoFiles(Archive archive) {
  return archive.files
      .where((f) =>
          f.isFile &&
          f.name.startsWith('photos/') &&
          f.name.endsWith('.jpg'))
      .toList();
}

Future<({int trialId, int plotPk, int sessionId, int assessmentId})>
    _seedMinimalRatedTrial(AppDatabase db, {required String trialName}) async {
  final trialId =
      await TrialRepository(db).createTrial(name: trialName, workspaceType: 'efficacy');
  await _insertCompatibilityProfile(db: db, trialId: trialId);
  final assessmentId = await db.into(db.assessments).insert(
        AssessmentsCompanion.insert(
          trialId: trialId,
          name: 'Vis',
        ),
      );
  final plotPk = await PlotRepository(db).insertPlot(
    trialId: trialId,
    plotId: '101',
    rep: 1,
  );
  await (db.update(db.plots)..where((p) => p.id.equals(plotPk))).write(
    const PlotsCompanion(armPlotNumber: Value(101)),
  );
  final treatmentId = await TreatmentRepository(db).insertTreatment(
    trialId: trialId,
    code: '1',
    name: 'Trt',
  );
  await AssignmentRepository(db).upsert(
    trialId: trialId,
    plotId: plotPk,
    treatmentId: treatmentId,
    assignmentSource: 'test',
  );
  final sessionRepo = SessionRepository(db);
  final session = await sessionRepo.createSession(
    trialId: trialId,
    name: 'S1',
    sessionDateLocal: await sessionDateLocalValidForTrial(db, trialId),
    assessmentIds: [assessmentId],
  );
  await RatingRepository(db).saveRating(
    trialId: trialId,
    plotPk: plotPk,
    assessmentId: assessmentId,
    sessionId: session.id,
    resultStatus: 'RECORDED',
    numericValue: 7.0,
    textValue: null,
    isSessionClosed: false,
  );
  return (
    trialId: trialId,
    plotPk: plotPk,
    sessionId: session.id,
    assessmentId: assessmentId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_installShareZipCaptureMock);
  tearDownAll(_clearShareMock);

  group('ExportTrialUseCase armHandoff ZIP contents', () {
    late Directory root;
    late String docsPath;
    late String tmpPath;
    late PathProviderPlatform savedPathProvider;

    setUp(() async {
      savedPathProvider = PathProviderPlatform.instance;
      root = await Directory.systemTemp.createTemp('export_zip_test_');
      docsPath = p.join(root.path, 'docs');
      tmpPath = p.join(root.path, 'tmp');
      await Directory(docsPath).create(recursive: true);
      await Directory(tmpPath).create(recursive: true);
      PathProviderPlatform.instance = _TestPathProvider(docsPath, tmpPath);
    });

    tearDown(() async {
      PathProviderPlatform.instance = savedPathProvider;
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    test('README.txt is present and describes the bundle', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'ReadmeTrial');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      expect(trial, isNotNull);
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final readmeFiles = archive.files
          .where((f) => f.isFile && f.name == 'README.txt')
          .toList();
      expect(readmeFiles, hasLength(1));
      final text = utf8.decode(readmeFiles.single.content as List<int>);
      expect(text, contains(AppInfo.appName));
      expect(text, contains('ReadmeTrial'));
      expect(text, contains('import_guide.csv'));
      expect(text, contains('App version:'));
    });

    test('1: one photo → ZIP has exactly one photos/*.jpg', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'OnePhoto');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      expect(trial, isNotNull);
      final photoDir = await Directory.systemTemp.createTemp('zip_photo_one_');
      addTearDown(() => photoDir.delete(recursive: true));
      final img = File('${photoDir.path}/a.jpg');
      await img.writeAsBytes([1, 2, 3]);
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              trialId: ids.trialId,
              plotPk: ids.plotPk,
              sessionId: ids.sessionId,
              filePath: img.path,
              createdAt: Value(DateTime(2026, 4, 10, 12)),
            ),
          );
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final jpgs = _photoFiles(archive);
      expect(jpgs, hasLength(1));
    });

    test('2: photo filename matches ARM stem pattern', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'StemTrial');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final photoDir = await Directory.systemTemp.createTemp('zip_photo_stem_');
      addTearDown(() => photoDir.delete(recursive: true));
      final img = File('${photoDir.path}/x.jpg');
      await img.writeAsBytes([1]);
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              trialId: ids.trialId,
              plotPk: ids.plotPk,
              sessionId: ids.sessionId,
              filePath: img.path,
              createdAt: Value(DateTime(2026, 4, 10, 12)),
            ),
          );
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final name = _photoFiles(archive).single.name;
      final re = RegExp(
        r'^photos/StemTrial_T0001_Apr-10-2026_P101\.jpg$',
      );
      expect(re.hasMatch(name), isTrue, reason: 'got $name');
    });

    test('3: two photos same stem get _01 and _02 suffixes', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'Collide');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final photoDir = await Directory.systemTemp.createTemp('zip_photo_col_');
      addTearDown(() => photoDir.delete(recursive: true));
      final same = DateTime(2026, 4, 10, 12);
      for (var i = 0; i < 2; i++) {
        final img = File('${photoDir.path}/p$i.jpg');
        await img.writeAsBytes([i]);
        await db.into(db.photos).insert(
              PhotosCompanion.insert(
                trialId: ids.trialId,
                plotPk: ids.plotPk,
                sessionId: ids.sessionId,
                filePath: img.path,
                createdAt: Value(same),
              ),
            );
      }
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final names =
          _photoFiles(archive).map((f) => f.name).toList()..sort();
      expect(names, [
        'photos/Collide_T0001_Apr-10-2026_P101_01.jpg',
        'photos/Collide_T0001_Apr-10-2026_P101_02.jpg',
      ]);
    });

    test('4: no photos → no photos/ entries and no photos_manifest.csv',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'NoPhoto');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      expect(
        archive.files.any((f) => f.name.startsWith('photos/')),
        isFalse,
      );
      expect(
        archive.files.any((f) => f.name == 'photos/photos_manifest.csv'),
        isFalse,
      );
    });

    test('5: missing photo file → photos_missing.csv, not in photos/*.jpg',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'MissingF');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              trialId: ids.trialId,
              plotPk: ids.plotPk,
              sessionId: ids.sessionId,
              filePath: '/no/such/path/missing_photo.jpg',
              createdAt: Value(DateTime(2026, 4, 10, 12)),
            ),
          );
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      expect(_photoFiles(archive), isEmpty);
      final missing = archive.files
          .where((f) => f.name == 'photos/photos_missing.csv')
          .toList();
      expect(missing, hasLength(1));
      final csv = utf8.decode(missing.single.content as List<int>);
      expect(csv, contains('missing_photo.jpg'));
    });

    test('6: one weather snapshot → weather.csv present', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'WxOne');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await WeatherSnapshotRepository(db).upsertWeatherSnapshot(
        WeatherSnapshotsCompanion.insert(
          uuid: const Uuid().v4(),
          trialId: ids.trialId,
          parentId: ids.sessionId,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 't',
        ),
      );
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      expect(
        archive.files.any((f) => f.name == 'weather.csv'),
        isTrue,
      );
    });

    test('7: weather.csv header row exact', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'WxHdr');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await WeatherSnapshotRepository(db).upsertWeatherSnapshot(
        WeatherSnapshotsCompanion.insert(
          uuid: const Uuid().v4(),
          trialId: ids.trialId,
          parentId: ids.sessionId,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 't',
        ),
      );
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final wx = archive.files
          .firstWhere((f) => f.name == 'weather.csv')
          .content as List<int>;
      final line = const LineSplitter().convert(utf8.decode(wx)).first;
      expect(
        line,
        'session_date,session_status,recorded_at,temperature,temp_unit,'
        'humidity_pct,wind_speed,wind_unit,wind_direction,cloud_cover,'
        'precipitation,soil_condition,notes,crop_stage_bbch',
      );
    });

    test('8: weather for soft-deleted session excluded from weather.csv',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'WxDel');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final sessionRepo = SessionRepository(db);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await WeatherSnapshotRepository(db).upsertWeatherSnapshot(
        WeatherSnapshotsCompanion.insert(
          uuid: const Uuid().v4(),
          trialId: ids.trialId,
          parentId: ids.sessionId,
          recordedAt: now,
          createdAt: now,
          modifiedAt: now,
          createdBy: 't',
        ),
      );
      await sessionRepo.closeSession(ids.sessionId);
      final s2 = await sessionRepo.createSession(
        trialId: ids.trialId,
        name: 'S2',
        sessionDateLocal: await sessionDateLocalValidForTrial(db, ids.trialId),
        assessmentIds: [ids.assessmentId],
      );
      await RatingRepository(db).saveRating(
        trialId: ids.trialId,
        plotPk: ids.plotPk,
        assessmentId: ids.assessmentId,
        sessionId: s2.id,
        resultStatus: 'RECORDED',
        numericValue: 3.0,
        textValue: null,
        isSessionClosed: false,
      );
      await WeatherSnapshotRepository(db).upsertWeatherSnapshot(
        WeatherSnapshotsCompanion.insert(
          uuid: const Uuid().v4(),
          trialId: ids.trialId,
          parentId: s2.id,
          recordedAt: now + 1,
          createdAt: now + 1,
          modifiedAt: now + 1,
          createdBy: 't2',
        ),
      );
      await sessionRepo.softDeleteSession(ids.sessionId, deletedBy: 'test');

      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      final wx = utf8.decode(
        archive.files.firstWhere((f) => f.name == 'weather.csv').content
            as List<int>,
      );
      final lines =
          const LineSplitter().convert(wx).where((l) => l.isNotEmpty).toList();
      expect(lines.length, 2, reason: 'header + one active-session row');
    });

    test('9: no weather → no weather.csv in ZIP', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ids = await _seedMinimalRatedTrial(db, trialName: 'NoWx');
      final trial = await TrialRepository(db).getTrialById(ids.trialId);
      final archive = await _runArmHandoffAndDecodeZip(db, trial!);
      expect(
        archive.files.any((f) => f.name == 'weather.csv'),
        isFalse,
      );
    });
  });
}
