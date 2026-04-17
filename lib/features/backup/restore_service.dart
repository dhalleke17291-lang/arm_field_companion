import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/database/app_database.dart';
import 'backup_encryption.dart';
import 'backup_file_helpers.dart';
import 'backup_models.dart';

/// Decrypts `.agnexis`, validates metadata, restores files. Caller must show
/// restart UI after [restore] succeeds.
///
/// V1: Linked shell paths in the DB are not rewritten; shells from the bundle are
/// copied under `restored_shells/` for manual re-link if needed.
class RestoreService {
  RestoreService(this._db);

  final AppDatabase _db;

  static const String _prefsPreRestoreSuffixKey = 'backup_pre_restore_suffix';

  /// Validates backup without modifying app data.
  Future<BackupMeta> validateBackup(File agnexisFile, String password) async {
    final bytes = await agnexisFile.readAsBytes();
    if (!BackupEncryption.isValidAgnexisFile(bytes)) {
      throw RestoreException('Not a valid Agnexis backup file');
    }
    Uint8List zipBytes;
    try {
      zipBytes = BackupEncryption.decrypt(bytes, password);
    } on BackupException catch (e) {
      throw RestoreException(e.message);
    }

    final rootTemp = await getTemporaryDirectory();
    final extractDir = Directory(p.join(rootTemp.path,
        'agnexis_validate_${DateTime.now().millisecondsSinceEpoch}'));
    try {
      await extractDir.create(recursive: true);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      await extractArchiveToDisk(archive, extractDir.path);

      final metaFile = File(p.join(extractDir.path, 'backup_meta.json'));
      if (!await metaFile.exists()) {
        throw RestoreException('Backup is missing backup_meta.json');
      }
      final meta = BackupMeta.fromJson(
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
      );

      if (meta.schemaVersion > _db.schemaVersion) {
        throw RestoreException(
          'This backup was created by a newer version of Agnexis (schema v${meta.schemaVersion}). '
          'Please update the app before restoring.',
        );
      }

      return meta;
    } finally {
      await deleteDirectoryIfExists(extractDir);
    }
  }

  /// Restores after [validateBackup]. Closes [_db]; do not use DB after this returns.
  ///
  /// Returns `true` when file replacement finished successfully (after [_db.close()]).
  /// Callers must not use the app database until process restart.
  Future<bool> restore(File agnexisFile, String password) async {
    await validateBackup(agnexisFile, password);

    final bytes = await agnexisFile.readAsBytes();
    Uint8List zipBytes;
    try {
      zipBytes = BackupEncryption.decrypt(bytes, password);
    } on BackupException catch (e) {
      throw RestoreException(e.message);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormatBackup.format(DateTime.now());
    final suffix = timestamp;

    final dbPath = p.join(docsDir.path, 'arm_field_companion.db');
    final photosDir = Directory(p.join(docsDir.path, 'photos'));
    final importsDir = Directory(p.join(docsDir.path, 'afc_imports'));

    await File(dbPath).copy(
        p.join(docsDir.path, 'arm_field_companion_pre_restore_$suffix.db'));

    if (await photosDir.exists()) {
      final pre = Directory(p.join(docsDir.path, 'photos_pre_restore_$suffix'));
      await deleteDirectoryIfExists(pre);
      await copyDirectory(photosDir, pre);
    }

    if (await importsDir.exists()) {
      final pre =
          Directory(p.join(docsDir.path, 'afc_imports_pre_restore_$suffix'));
      await deleteDirectoryIfExists(pre);
      await copyDirectory(importsDir, pre);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPreRestoreSuffixKey, suffix);

    await _db.close();

    final rootTemp = await getTemporaryDirectory();
    final extractDir = Directory(p.join(rootTemp.path,
        'agnexis_restore_${DateTime.now().millisecondsSinceEpoch}'));
    try {
      await extractDir.create(recursive: true);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      await extractArchiveToDisk(archive, extractDir.path);

      final restoredDb = File(p.join(extractDir.path, 'database.db'));
      if (!await restoredDb.exists()) {
        throw RestoreException('Backup is missing database.db');
      }

      for (final extra in [
        File(p.join(docsDir.path, 'arm_field_companion.db-wal')),
        File(p.join(docsDir.path, 'arm_field_companion.db-shm')),
      ]) {
        try {
          if (await extra.exists()) await extra.delete();
        } catch (e, st) {
          log(
            'Restore: optional WAL/SHM delete skipped',
            error: e,
            stackTrace: st,
          );
        }
      }
      final dbDest = File(dbPath);
      if (await dbDest.exists()) {
        await dbDest.delete();
      }
      await restoredDb.copy(dbPath);

      await deleteDirectoryIfExists(photosDir);
      final backedPhotos = Directory(p.join(extractDir.path, 'photos'));
      if (await backedPhotos.exists()) {
        await copyDirectory(backedPhotos, photosDir);
      }

      await deleteDirectoryIfExists(importsDir);
      final backedImports = Directory(p.join(extractDir.path, 'afc_imports'));
      if (await backedImports.exists()) {
        await copyDirectory(backedImports, importsDir);
      }

      final backedShells = Directory(p.join(extractDir.path, 'shells'));
      final outShells = Directory(p.join(docsDir.path, 'restored_shells'));
      if (await backedShells.exists()) {
        await deleteDirectoryIfExists(outShells);
        await copyDirectory(backedShells, outShells);
      }

      // Rewrite trials.armLinkedShellPath so restored shells are findable on
      // this device. Both absolute (from the source device) and relative
      // paths are replaced with the new absolute path under
      // docsDir/restored_shells/. Wrapped in a transaction — partial failure
      // rolls back, so DB never ends up in a mixed-path state.
      if (await outShells.exists()) {
        await _rewriteShellPaths(dbPath: dbPath, shellsDir: outShells);
      }
    } finally {
      await deleteDirectoryIfExists(extractDir);
    }
    return true;
  }

  /// Opens the restored DB directly (Drift _db is already closed at this
  /// point), scans trials with a non-null armLinkedShellPath, and rewrites
  /// each to the matching file in [shellsDir] if present.
  Future<void> _rewriteShellPaths({
    required String dbPath,
    required Directory shellsDir,
  }) async {
    // Index available shell files by trial id.
    final shellByTrial = <int, String>{};
    await for (final entity in shellsDir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // Expected name: trial_{id}_shell.{ext}
      final match =
          RegExp(r'^trial_(\d+)_shell\.[^.]+$').firstMatch(name);
      if (match == null) continue;
      final tid = int.tryParse(match.group(1)!);
      if (tid == null) continue;
      shellByTrial[tid] = entity.path;
    }
    if (shellByTrial.isEmpty) return;

    final db = sqlite.sqlite3.open(dbPath);
    try {
      db.execute('BEGIN TRANSACTION');
      final stmt = db.prepare(
        'UPDATE trials SET arm_linked_shell_path = ? WHERE id = ?',
      );
      try {
        for (final entry in shellByTrial.entries) {
          stmt.execute([entry.value, entry.key]);
        }
        db.execute('COMMIT');
      } catch (e) {
        db.execute('ROLLBACK');
        rethrow;
      } finally {
        stmt.dispose();
      }
    } finally {
      db.dispose();
    }
  }
}

/// Local date format helper to avoid importing intl in restore only for one line.
class DateFormatBackup {
  static String format(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$y$m${day}_$h$min$s';
  }
}
