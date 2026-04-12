import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/backup/backup_encryption.dart';
import 'package:arm_field_companion/features/backup/backup_models.dart';
import 'package:arm_field_companion/features/backup/backup_service.dart';
import 'package:arm_field_companion/features/backup/restore_service.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.docs, this.tmp);
  final String docs;
  final String tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

Future<File> buildAgnexisFile({
  required String docsPath,
  required String tmpPath,
  required int schemaVersion,
  required String password,
}) async {
  final work = Directory(p.join(tmpPath, 'build_${DateTime.now().microsecondsSinceEpoch}'));
  await work.create(recursive: true);
  final meta = BackupMeta(
    appName: 'Agnexis',
    appVersion: '1.0.0',
    schemaVersion: schemaVersion,
    backupDate: DateTime.utc(2026, 1, 1),
    deviceInfo: 'test',
    trialCount: 0,
    photoCount: 0,
    estimatedSizeBytes: 0,
  );
  await File(p.join(work.path, 'backup_meta.json'))
      .writeAsString(meta.toJsonString());
  await File(p.join(work.path, 'database.db')).writeAsString('sqlite-placeholder');

  final zipPath = p.join(tmpPath, 'bundle_${DateTime.now().microsecondsSinceEpoch}.zip');
  final encoder = ZipFileEncoder();
  encoder.create(zipPath, level: ZipFileEncoder.GZIP);
  await encoder.addDirectory(work, includeDirName: false);
  await encoder.close();

  final zipBytes = await File(zipPath).readAsBytes();
  final agnexisBytes = BackupEncryption.encrypt(zipBytes, password);
  final out = File(p.join(tmpPath, 'test_${DateTime.now().microsecondsSinceEpoch}.agnexis'));
  await out.writeAsBytes(agnexisBytes);

  await work.delete(recursive: true);
  await File(zipPath).delete();
  return out;
}

void main() {
  late Directory root;
  late String docsPath;
  late String tmpPath;
  late PathProviderPlatform savedProvider;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    savedProvider = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('restore_svc_test_');
    docsPath = p.join(root.path, 'docs');
    tmpPath = p.join(root.path, 'tmp');
    await Directory(docsPath).create(recursive: true);
    await Directory(tmpPath).create(recursive: true);
    PathProviderPlatform.instance = _TestPaths(docsPath, tmpPath);
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<AppDatabase> openDb() async {
    final dbFile = File(p.join(docsPath, 'arm_field_companion.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    for (final extra in ['-wal', '-shm']) {
      final f = File('${dbFile.path}$extra');
      if (await f.exists()) await f.delete();
    }
    return AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
  }

  test('validateBackup returns BackupMeta', () async {
    final db = await openDb();
    addTearDown(db.close);
    final f = await buildAgnexisFile(
      docsPath: docsPath,
      tmpPath: tmpPath,
      schemaVersion: db.schemaVersion,
      password: 'password12',
    );
    final rs = RestoreService(db);
    final meta = await rs.validateBackup(f, 'password12');
    expect(meta.schemaVersion, db.schemaVersion);
  });

  test('validateBackup rejects wrong magic', () async {
    final db = await openDb();
    addTearDown(db.close);
    final bad = File(p.join(tmpPath, 'bad.agnexis'));
    await bad.writeAsBytes(Uint8List.fromList(List.filled(60, 0)));
    final rs = RestoreService(db);
    expect(
      () => rs.validateBackup(bad, 'password12'),
      throwsA(isA<RestoreException>()),
    );
  });

  test('validateBackup rejects wrong password', () async {
    final db = await openDb();
    addTearDown(db.close);
    final f = await buildAgnexisFile(
      docsPath: docsPath,
      tmpPath: tmpPath,
      schemaVersion: db.schemaVersion,
      password: 'rightpass12',
    );
    final rs = RestoreService(db);
    expect(
      () => rs.validateBackup(f, 'wrongpass12'),
      throwsA(isA<RestoreException>()),
    );
  });

  test('validateBackup rejects newer schema than app', () async {
    final db = await openDb();
    addTearDown(db.close);
    final f = await buildAgnexisFile(
      docsPath: docsPath,
      tmpPath: tmpPath,
      schemaVersion: db.schemaVersion + 50,
      password: 'password12',
    );
    final rs = RestoreService(db);
    expect(
      () => rs.validateBackup(f, 'password12'),
      throwsA(isA<RestoreException>().having(
        (e) => e.toString(),
        'msg',
        contains('schema v${db.schemaVersion + 50}'),
      )),
    );
  });

  test('validateBackup accepts older schema backup', () async {
    final db = await openDb();
    addTearDown(db.close);
    final f = await buildAgnexisFile(
      docsPath: docsPath,
      tmpPath: tmpPath,
      schemaVersion: 1,
      password: 'password12',
    );
    final rs = RestoreService(db);
    final meta = await rs.validateBackup(f, 'password12');
    expect(meta.schemaVersion, 1);
  });

  test('restore creates pre-restore snapshot and replaces database', () async {
    final dbFile = File(p.join(docsPath, 'arm_field_companion.db'));
    final db = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    await TrialRepository(db).createTrial(name: 'Live', workspaceType: 'efficacy');
    final agnexis = await BackupService(db).createBackup('pw12longer');
    await TrialRepository(db).createTrial(name: 'Extra', workspaceType: 'efficacy');
    expect((await db.select(db.trials).get()).length, 2);

    final rs = RestoreService(db);
    expect(await rs.restore(agnexis, 'pw12longer'), isTrue);

    final preDb = Directory(docsPath)
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.contains('pre_restore') && f.path.endsWith('.db'))
        .toList();
    expect(preDb, isNotEmpty);

    final db2 = AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
    addTearDown(db2.close);
    final rows = await db2.select(db2.trials).get();
    expect(rows.where((t) => !t.isDeleted).length, 1);
    expect(rows.firstWhere((t) => !t.isDeleted).name, 'Live');
  });

  // V1 manual test: restore a backup from an older schema version, reopen app,
  // verify data is accessible and schema is current.
  // Automated migration-after-restore test deferred — requires file-based DB
  // fixture and opening a fresh AppDatabase after restore simulates next launch.
}
