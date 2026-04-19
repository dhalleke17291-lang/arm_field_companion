import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_audit_preferences.dart';
import 'backup_passphrase_store.dart';
import 'backup_service.dart';

/// Silently creates a local backup after session close.
/// Uses the cached passphrase from keychain. If no passphrase is cached,
/// skips silently — the user hasn't set up backups yet.
///
/// Backups are saved to a dedicated auto-backup directory. Only the most
/// recent 3 auto-backups are kept to avoid filling storage.
class AutoBackupStatus {
  const AutoBackupStatus({
    required this.enabled,
    this.lastBackupAt,
  });

  final bool enabled;
  final DateTime? lastBackupAt;

  String get label {
    if (!enabled) return 'Auto-backup disabled — no saved passphrase';
    if (lastBackupAt == null) return 'Auto-backup enabled — no backup yet';
    final ago = DateTime.now().difference(lastBackupAt!);
    if (ago.inMinutes < 5) return 'Auto-backup: just now';
    if (ago.inHours < 1) return 'Auto-backup: ${ago.inMinutes} min ago';
    if (ago.inHours < 24) return 'Auto-backup: ${ago.inHours}h ago';
    return 'Auto-backup: ${ago.inDays}d ago';
  }
}

class AutoBackupService {
  AutoBackupService(this._backupService, this._passphraseStore);

  final BackupService _backupService;
  final BackupPassphraseStore _passphraseStore;

  static const int _maxAutoBackups = 5;

  Future<AutoBackupStatus> getStatus() async {
    final hasCached = await _passphraseStore.hasCached();
    if (!hasCached) {
      return const AutoBackupStatus(enabled: false);
    }
    final dir = await _autoBackupDir();
    if (!await dir.exists()) {
      return const AutoBackupStatus(enabled: true);
    }
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.agnexis'))
        .cast<File>()
        .toList();
    if (files.isEmpty) {
      return const AutoBackupStatus(enabled: true);
    }
    files.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return AutoBackupStatus(
      enabled: true,
      lastBackupAt: files.first.lastModifiedSync(),
    );
  }

  Future<void> performAutoBackup() async {
    try {
      final passphrase = await _passphraseStore.retrieve();
      if (passphrase == null || passphrase.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final clearAudit =
          BackupAuditPreferences(prefs).clearAuditLogAfterSuccessfulBackup;
      final backup = await _backupService.createBackup(
        passphrase,
        clearAuditLogOnDeviceAfterSuccess: clearAudit,
      );

      final dir = await _autoBackupDir();
      final dest = File(
          '${dir.path}/${backup.uri.pathSegments.last}');
      await backup.copy(dest.path);

      await _pruneOldBackups(dir);
    } catch (_) {
      // Auto-backup failure is non-fatal.
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
