import 'package:arm_field_companion/features/backup/backup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupMeta', () {
    test('serializes and deserializes', () {
      final meta = BackupMeta(
        appName: 'Agnexis',
        appVersion: '1.0.0',
        schemaVersion: 45,
        backupDate: DateTime.utc(2026, 4, 9, 14, 30),
        deviceInfo: 'test',
        trialCount: 3,
        photoCount: 10,
        estimatedSizeBytes: 1000,
        missingReferences: const [
          MissingReference(
            trialId: 1,
            field: 'armLinkedShellPath',
            path: '/x.xlsx',
          ),
        ],
      );
      final json = meta.toJson();
      final back = BackupMeta.fromJson(json);
      expect(back.appName, meta.appName);
      expect(back.schemaVersion, meta.schemaVersion);
      expect(back.trialCount, meta.trialCount);
      expect(back.missingReferences.length, 1);
      expect(back.missingReferences.first.trialId, 1);
    });

    test('fromJson uses defaults for missing optional fields', () {
      final back = BackupMeta.fromJson({
        'schema_version': 40,
        'backup_date': '2020-01-01T00:00:00.000Z',
      });
      expect(back.appName, 'Agnexis');
      expect(back.appVersion, '1.0.0');
      expect(back.schemaVersion, 40);
      expect(back.trialCount, 0);
      expect(back.photoCount, 0);
      expect(back.missingReferences, isEmpty);
    });
  });
}
