import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_passphrase_store.dart';
import 'backup_service.dart';

/// Silently creates a local backup after session close.
/// Uses the cached passphrase from keychain. If no passphrase is cached,
/// skips silently — the user hasn't set up backups yet.
///
/// Backups are saved to a dedicated auto-backup directory. Only the most
/// recent 3 auto-backups are kept to avoid filling storage.
class AutoBackupService {
  AutoBackupService(this._backupService, this._passphraseStore);

  final BackupService _backupService;
  final BackupPassphraseStore _passphraseStore;

  static const int _maxAutoBackups = 3;

  Future<void> performAutoBackup() async {
    try {
      final passphrase = await _passphraseStore.retrieve();
      if (passphrase == null || passphrase.isEmpty) return;

      final backup = await _backupService.createBackup(passphrase);

      final dir = await _autoBackupDir();
      final dest = File(
          '${dir.path}/${backup.uri.pathSegments.last}');
      await backup.copy(dest.path);

      await _pruneOldBackups(dir);
    } catch (_) {
      // Auto-backup failure is non-fatal. The user still has the
      // reminder flow and manual backup as fallback.
    }
  }

  Future<Directory> _autoBackupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/auto_backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _pruneOldBackups(Directory dir) async {
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.agnexis'))
        .cast<File>()
        .toList();
    if (files.length <= _maxAutoBackups) return;

    files.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in files.skip(_maxAutoBackups)) {
      try {
        await old.delete();
      } catch (_) {}
    }
  }
}
