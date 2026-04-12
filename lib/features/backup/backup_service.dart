import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_info.dart';
import '../../core/database/app_database.dart';
import 'backup_encryption.dart';
import 'backup_file_helpers.dart';
import 'backup_models.dart';

/// Creates encrypted `.agnexis` backups (WAL checkpoint, streaming ZIP, then encrypt).
///
/// V1: Encryption step reads the full ZIP into memory (large backups use significant RAM).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Returns the `.agnexis` file ready for sharing.
  Future<File> createBackup(
    String password, {
    void Function(String status)? onProgress,
  }) async {
    if (password.isEmpty) {
      throw BackupException('Password cannot be empty');
    }
    if (password.length < 6) {
      throw BackupException('Password must be at least 6 characters');
    }

    final rootTemp = await getTemporaryDirectory();
    final workId = const Uuid().v4();
    final workRoot = Directory(p.join(rootTemp.path, 'agq_backup_$workId'));
    final backupTemp = Directory(p.join(workRoot.path, 'payload'));
    final zipPath = p.join(workRoot.path, 'backup.zip');

    try {
      onProgress?.call('Preparing database...');
      await backupTemp.create(recursive: true);

      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      final docsDir = await getApplicationDocumentsDirectory();
      final dbSrc = File(p.join(docsDir.path, 'arm_field_companion.db'));
      if (!await dbSrc.exists()) {
        throw BackupException('Database file not found');
      }
      await dbSrc.copy(p.join(backupTemp.path, 'database.db'));

      onProgress?.call('Copying photos...');
      final photosSrc = Directory(p.join(docsDir.path, 'photos'));
      final photosDst = Directory(p.join(backupTemp.path, 'photos'));
      if (await photosSrc.exists()) {
        await copyDirectory(photosSrc, photosDst);
      }

      onProgress?.call('Copying import files...');
      final importsSrc = Directory(p.join(docsDir.path, 'afc_imports'));
      final importsDst = Directory(p.join(backupTemp.path, 'afc_imports'));
      if (await importsSrc.exists()) {
        await copyDirectory(importsSrc, importsDst);
      }

      final shellsDir = Directory(p.join(backupTemp.path, 'shells'));
      await shellsDir.create(recursive: true);
      final missingRefs = <MissingReference>[];
      final trialRows = await _db.select(_db.trials).get();
      var hasShellFile = false;
      for (final trial in trialRows) {
        final shellPath = trial.armLinkedShellPath;
        if (shellPath == null || shellPath.isEmpty) continue;
        final f = File(shellPath);
        if (await f.exists()) {
          hasShellFile = true;
          final ext = p.extension(shellPath);
          final safeExt = ext.isEmpty ? '.xlsx' : ext;
          final destName = 'trial_${trial.id}_shell$safeExt';
          await f.copy(p.join(shellsDir.path, destName));
        } else {
          missingRefs.add(MissingReference(
            trialId: trial.id,
            field: 'armLinkedShellPath',
            path: shellPath,
          ));
        }
      }
      if (!hasShellFile && await shellsDir.exists()) {
        await shellsDir.delete(recursive: true);
      }

      final trialCount =
          trialRows.where((t) => !t.isDeleted).length;
      final photoRows = await _db.select(_db.photos).get();
      final photoCount =
          photoRows.where((p) => !p.isDeleted).length;

      final estimatedSizeBytes = await directorySizeBytes(backupTemp);

      final deviceInfo =
          '${Platform.operatingSystem}, ${Platform.operatingSystemVersion}';
      final meta = BackupMeta(
        appName: 'Agnexis',
        appVersion: kAppVersion,
        schemaVersion: _db.schemaVersion,
        backupDate: DateTime.now().toUtc(),
        deviceInfo: deviceInfo,
        trialCount: trialCount,
        photoCount: photoCount,
        estimatedSizeBytes: estimatedSizeBytes,
        missingReferences: missingRefs,
      );

      await File(p.join(backupTemp.path, 'backup_meta.json'))
          .writeAsString(meta.toJsonString());

      onProgress?.call('Creating backup file...');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath, level: ZipFileEncoder.GZIP);
      await encoder.addDirectory(backupTemp, includeDirName: false);
      await encoder.close();

      onProgress?.call('Encrypting...');
      final zipBytes = await File(zipPath).readAsBytes();
      final agnexisBytes = BackupEncryption.encrypt(zipBytes, password);

      final dateStamp =
          DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final agnexisFile =
          File(p.join(rootTemp.path, 'Agnexis_backup_$dateStamp.agnexis'));
      await agnexisFile.writeAsBytes(agnexisBytes);

      await deleteDirectoryIfExists(workRoot);

      return agnexisFile;
    } catch (e) {
      await deleteDirectoryIfExists(workRoot);
      if (e is BackupException) rethrow;
      throw BackupException('Backup failed: $e');
    }
  }
}
