import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// [parentType] for rating sessions (stored in [WeatherSnapshot.parentType]).
const String kWeatherParentTypeRatingSession = 'rating_session';

class WeatherSnapshotRepository {
  WeatherSnapshotRepository(this._db);

  final AppDatabase _db;

  /// Inserts a new row, or updates the existing row for the same
  /// `(parent_type, parent_id)` while preserving [WeatherSnapshot.id] and `uuid`.
  Future<int> upsertWeatherSnapshot(WeatherSnapshotsCompanion companion) async {
    final parentType = companion.parentType.present
        ? companion.parentType.value
        : kWeatherParentTypeRatingSession;
    if (!companion.parentId.present) {
      throw ArgumentError('WeatherSnapshotsCompanion must include parentId');
    }
    final parentId = companion.parentId.value;
    final existing =
        await getWeatherSnapshotForParent(parentType, parentId);
    if (existing != null) {
      final forUpdate = companion.copyWith(
        uuid: const Value.absent(),
        id: const Value.absent(),
      );
      await updateWeatherSnapshot(existing.id, forUpdate);
      return existing.id;
    }
    return _db.into(_db.weatherSnapshots).insert(companion);
  }

  Future<WeatherSnapshot?> getWeatherSnapshotForParent(
    String parentType,
    int parentId,
  ) {
    return (_db.select(_db.weatherSnapshots)
          ..where((w) =>
              w.parentType.equals(parentType) & w.parentId.equals(parentId)))
        .getSingleOrNull();
  }

  Future<List<WeatherSnapshot>> getWeatherSnapshotsForTrial(int trialId) {
    return (_db.select(_db.weatherSnapshots)
          ..where((w) => w.trialId.equals(trialId))
          ..orderBy([(w) => OrderingTerm.asc(w.recordedAt)]))
        .get();
  }

  Future<void> deleteWeatherSnapshot(int id) {
    return (_db.delete(_db.weatherSnapshots)..where((w) => w.id.equals(id)))
        .go();
  }

  Future<void> updateWeatherSnapshot(
    int id,
    WeatherSnapshotsCompanion companion,
  ) {
    return (_db.update(_db.weatherSnapshots)..where((w) => w.id.equals(id)))
        .write(companion);
  }

  /// One snapshot per parent; emits null when none.
  Stream<WeatherSnapshot?> watchWeatherSnapshotForParent(
    String parentType,
    int parentId,
  ) {
    final q = _db.select(_db.weatherSnapshots)
      ..where((w) =>
          w.parentType.equals(parentType) & w.parentId.equals(parentId));
    return q.watch().map((rows) => rows.isEmpty ? null : rows.first);
  }
}
