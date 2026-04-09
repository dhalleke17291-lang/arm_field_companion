import 'dart:convert';

/// Metadata stored in `backup_meta.json` inside the backup ZIP.
///
/// V1 limitations (see backup service / restore service):
/// - Full ZIP is read into memory for encryption (large backups use significant RAM).
/// - Linked shell paths in DB are not rewritten on restore; use [restored_shells] on disk.
class BackupMeta {
  const BackupMeta({
    required this.appName,
    required this.appVersion,
    required this.schemaVersion,
    required this.backupDate,
    required this.deviceInfo,
    required this.trialCount,
    required this.photoCount,
    required this.estimatedSizeBytes,
    this.missingReferences = const [],
  });

  final String appName;
  final String appVersion;
  final int schemaVersion;
  final DateTime backupDate;
  final String deviceInfo;
  final int trialCount;
  final int photoCount;
  final int estimatedSizeBytes;
  final List<MissingReference> missingReferences;

  factory BackupMeta.fromJson(Map<String, dynamic> json) {
    final missing = json['missing_references'];
    return BackupMeta(
      appName: json['app_name'] as String? ?? 'Agnexis',
      appVersion: json['app_version'] as String? ?? '1.0.0',
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
      backupDate: DateTime.tryParse(json['backup_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deviceInfo: json['device_info'] as String? ?? '',
      trialCount: (json['trial_count'] as num?)?.toInt() ?? 0,
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      estimatedSizeBytes:
          (json['estimated_size_bytes'] as num?)?.toInt() ?? 0,
      missingReferences: missing is List
          ? missing
              .map((e) => MissingReference.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'app_version': appVersion,
        'schema_version': schemaVersion,
        'backup_date': backupDate.toUtc().toIso8601String(),
        'device_info': deviceInfo,
        'trial_count': trialCount,
        'photo_count': photoCount,
        'estimated_size_bytes': estimatedSizeBytes,
        'missing_references':
            missingReferences.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class MissingReference {
  const MissingReference({
    required this.trialId,
    required this.field,
    required this.path,
  });

  final int trialId;
  final String field;
  final String path;

  factory MissingReference.fromJson(Map<String, dynamic> json) {
    return MissingReference(
      trialId: (json['trial_id'] as num?)?.toInt() ?? 0,
      field: json['field'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'trial_id': trialId,
        'field': field,
        'path': path,
      };
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RestoreException implements Exception {
  RestoreException(this.message);
  final String message;
  @override
  String toString() => message;
}
