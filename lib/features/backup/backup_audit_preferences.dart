import 'package:shared_preferences/shared_preferences.dart';

/// User preference: whether to clear the on-device audit log after a **successful**
/// encrypted backup. Default **off** — user must opt in.
class BackupAuditPreferences {
  BackupAuditPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _keyClearAfterBackup = 'backup_clear_audit_log_after_success';

  bool get clearAuditLogAfterSuccessfulBackup =>
      _prefs.getBool(_keyClearAfterBackup) ?? false;

  Future<void> setClearAuditLogAfterSuccessfulBackup(bool value) =>
      _prefs.setBool(_keyClearAfterBackup, value);
}
