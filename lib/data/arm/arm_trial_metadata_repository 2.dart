import '../../core/database/app_database.dart';

/// Persistence for [ArmTrialMetadata] (Phase 0b).
///
/// **ARM-only** data path; core trials stay free of shell-link columns.
class ArmTrialMetadataRepository {
  ArmTrialMetadataRepository(this._db);

  final AppDatabase _db;

  Future<ArmTrialMetadataData?> getForTrial(int trialId) {
    return (_db.select(_db.armTrialMetadata)
          ..where((m) => m.trialId.equals(trialId)))
        .getSingleOrNull();
  }

  Stream<ArmTrialMetadataData?> watchForTrial(int trialId) {
    return (_db.select(_db.armTrialMetadata)
          ..where((m) => m.trialId.equals(trialId)))
        .watch()
        .map((rows) => rows.singleOrNull);
  }

  Future<void> upsert(ArmTrialMetadataCompanion row) {
    return _db.into(_db.armTrialMetadata).insertOnConflictUpdate(row);
  }

  Future<ArmTrialMetadataData?> getBySourceFilePath(String filePath) {
    return (_db.select(_db.armTrialMetadata)
          ..where((m) => m.armSourceFile.equals(filePath)))
        .getSingleOrNull();
  }
}
