import 'dart:io';

/// Abstract interface for cloud backup providers.
/// Each provider (Google Drive, OneDrive, iCloud) implements this.
abstract class CloudBackupProvider {
  /// Human-readable name (e.g. "Google Drive", "OneDrive", "iCloud").
  String get displayName;

  /// Provider identifier for persistence (e.g. "google_drive", "onedrive", "icloud").
  String get providerId;

  /// Whether the user has authenticated with this provider.
  Future<bool> get isAuthenticated;

  /// Authenticate with the cloud provider. Returns true on success.
  Future<bool> authenticate();

  /// Sign out and clear stored credentials.
  Future<void> signOut();

  /// Upload a backup file to the user's cloud storage.
  /// Returns the remote file ID or path on success.
  Future<String> uploadBackup(File localFile);

  /// List available backup files in the cloud.
  /// Returns metadata for each backup (name, size, date).
  Future<List<CloudBackupFile>> listBackups();

  /// Download a backup file from the cloud to a local path.
  Future<File> downloadBackup(String remoteId, String localPath);

  /// Delete a remote backup file.
  Future<void> deleteBackup(String remoteId);
}

/// Metadata for a backup file stored in the cloud.
class CloudBackupFile {
  const CloudBackupFile({
    required this.remoteId,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String remoteId;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
}

/// Manages the user's chosen cloud backup provider.
/// Persists the choice so the app remembers across restarts.
enum CloudProviderType {
  googleDrive,
  oneDrive,
  iCloud,
  none,
}
