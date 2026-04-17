import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around platform secure storage for the backup passphrase.
///
/// Pattern A — we cache the raw passphrase; each backup/restore runs PBKDF2
/// fresh with its own per-file salt. Zero file format change, iCloud Keychain
/// sync works out of the box on iOS for multi-device portability.
///
/// Never log or print the passphrase.
class BackupPassphraseStore {
  BackupPassphraseStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _keyPassphrase = 'backup_passphrase_v1';
  // Remembers the user's opt-in choice so we don't re-prompt on every backup.
  static const _keySaveChoice = 'backup_passphrase_save_choice_v1';

  /// Persist the passphrase in the platform keychain. Call after a
  /// successful backup or restore when the user has opted in.
  Future<void> save(String passphrase) async {
    await _storage.write(key: _keyPassphrase, value: passphrase);
    await _storage.write(key: _keySaveChoice, value: 'true');
  }

  /// Returns the cached passphrase, or null if none is stored.
  Future<String?> retrieve() async {
    return _storage.read(key: _keyPassphrase);
  }

  /// Clears both the cached passphrase and the opt-in choice.
  /// "Forget saved passphrase" action.
  Future<void> clear() async {
    await _storage.delete(key: _keyPassphrase);
    await _storage.delete(key: _keySaveChoice);
  }

  /// True when a passphrase is currently cached.
  Future<bool> hasCached() async {
    final v = await _storage.read(key: _keyPassphrase);
    return v != null && v.isNotEmpty;
  }

  /// True when the user has previously opted in to caching.
  /// Used to skip the "Save for next time?" checkbox on subsequent backups.
  Future<bool> hasOptedIn() async {
    final v = await _storage.read(key: _keySaveChoice);
    return v == 'true';
  }
}
