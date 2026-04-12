import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/backup/backup_encryption.dart';
import 'package:arm_field_companion/features/backup/backup_models.dart';
import 'package:arm_field_companion/features/backup/backup_service.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.docs, this.tmp);
  final String docs;
  final String tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

void main() {
  late Directory root;
  late String docsPath;
  late String tmpPath;
  late PathProviderPlatform savedProvider;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    savedProvider = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('backup_svc_test_');
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
    return AppDatabase.forTesting(NativeDatabase.createInBackground(dbFile));
  }

  test('empty password rejected', () async {
    final db = await openDb();
    addTearDown(db.close);
    final svc = BackupService(db);
    expect(() => svc.createBackup(''), throwsA(isA<BackupException>()));
  });

  test('password under 6 characters rejected', () async {
    final db = await openDb();
    addTearDown(db.close);
    final svc = BackupService(db);
    expect(() => svc.createBackup('abcde'), throwsA(isA<BackupException>()));
  });

  test('agnexis has magic bytes and zip contains database.db and meta', () async {
    final db = await openDb();
    addTearDown(db.close);
    await TrialRepository(db).createTrial(name: 'T', workspaceType: 'efficacy');

    final svc = BackupService(db);
    final out = await svc.createBackup('secret12');
    expect(out.path.toLowerCase().endsWith('.agnexis'), isTrue);

    final agnexisBytes = await out.readAsBytes();
    expect(BackupEncryption.isValidAgnexisFile(agnexisBytes), isTrue);

    final zipBytes = BackupEncryption.decrypt(agnexisBytes, 'secret12');
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('database.db'));
    expect(names, contains('backup_meta.json'));

    final metaFile = archive.files.firstWhere((f) => f.name == 'backup_meta.json');
    final meta = BackupMeta.fromJson(
      jsonDecode(utf8.decode(metaFile.content as List<int>))
          as Map<String, dynamic>,
    );
    expect(meta.schemaVersion, db.schemaVersion);
  });

  test('missing photos and afc_imports does not fail', () async {
    final db = await openDb();
    addTearDown(db.close);
    await TrialRepository(db).createTrial(name: 'T', workspaceType: 'efficacy');

    final svc = BackupService(db);
    final out = await svc.createBackup('secret12');
    final zipBytes = BackupEncryption.decrypt(await out.readAsBytes(), 'secret12');
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names.where((n) => n.startsWith('photos/')).isEmpty, isTrue);
    expect(names.where((n) => n.startsWith('afc_imports/')).isEmpty, isTrue);
  });

  test('unreachable shell path recorded in missing_references', () async {
    final db = await openDb();
    addTearDown(db.close);
    final tid =
        await TrialRepository(db).createTrial(name: 'T', workspaceType: 'efficacy');
    await (db.update(db.trials)..where((t) => t.id.equals(tid))).write(
          const TrialsCompanion(
            armLinkedShellPath: Value('/no/such/shell/file.xlsx'),
          ),
        );

    final svc = BackupService(db);
    final out = await svc.createBackup('secret12');
    final zipBytes = BackupEncryption.decrypt(await out.readAsBytes(), 'secret12');
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final metaFile = archive.files.firstWhere((f) => f.name == 'backup_meta.json');
    final meta = BackupMeta.fromJson(
      jsonDecode(utf8.decode(metaFile.content as List<int>))
          as Map<String, dynamic>,
    );
    expect(meta.missingReferences, isNotEmpty);
    expect(meta.missingReferences.first.field, 'armLinkedShellPath');
  });
}
