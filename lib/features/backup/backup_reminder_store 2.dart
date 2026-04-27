import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable backup reminder modes.
enum BackupReminderMode {
  /// No reminders.
  off,

  /// Remind after every session close.
  afterSessionClose,

  /// Remind once per day (first app open after midnight).
  daily,

  /// Remind once per week.
  weekly,
}

/// Persists backup reminder preferences and last backup timestamp.
class BackupReminderStore {
  BackupReminderStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyMode = 'backup_reminder_mode';
  static const _keyLastBackup = 'backup_last_timestamp';
  static const _keyLastReminder = 'backup_last_reminder';

  BackupReminderMode get mode {
    final raw = _prefs.getString(_keyMode);
    if (raw == null) return BackupReminderMode.afterSessionClose;
    return BackupReminderMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => BackupReminderMode.off,
    );
  }

  Future<void> setMode(BackupReminderMode mode) async {
    await _prefs.setString(_keyMode, mode.name);
  }

  /// Records that a backup was just completed.
  Future<void> recordBackupCompleted() async {
    await _prefs.setInt(_keyLastBackup, DateTime.now().millisecondsSinceEpoch);
  }

  DateTime? get lastBackupTime {
    final ms = _prefs.getInt(_keyLastBackup);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Records that a reminder was just shown (prevents repeat prompts).
  Future<void> recordReminderShown() async {
    await _prefs.setInt(_keyLastReminder, DateTime.now().millisecondsSinceEpoch);
  }

  DateTime? get lastReminderTime {
    final ms = _prefs.getInt(_keyLastReminder);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Whether a backup reminder should be shown now.
  bool shouldRemind() {
    final m = mode;
    if (m == BackupReminderMode.off) return false;

    final now = DateTime.now();
    final lastBackup = lastBackupTime;
    final lastReminder = lastReminderTime;

    // Don't remind if we already reminded in the last hour
    if (lastReminder != null &&
        now.difference(lastReminder).inHours < 1) {
      return false;
    }

    switch (m) {
      case BackupReminderMode.afterSessionClose:
        // Always remind on session close (caller checks this mode directly)
        return true;

      case BackupReminderMode.daily:
        if (lastBackup == null) return true;
        return now.difference(lastBackup).inDays >= 1;

      case BackupReminderMode.weekly:
        if (lastBackup == null) return true;
        return now.difference(lastBackup).inDays >= 7;

      case BackupReminderMode.off:
        return false;
    }
  }

  /// Human-readable label for the last backup time.
  String get lastBackupLabel {
    final t = lastBackupTime;
    if (t == null) return 'Never';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}

String backupReminderModeLabel(BackupReminderMode mode) {
  switch (mode) {
    case BackupReminderMode.off:
      return 'Off';
    case BackupReminderMode.afterSessionClose:
      return 'After each session close';
    case BackupReminderMode.daily:
      return 'Daily';
    case BackupReminderMode.weekly:
      return 'Weekly';
  }
}
