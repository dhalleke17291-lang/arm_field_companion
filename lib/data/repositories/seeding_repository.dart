import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Repository for trial-level seeding events (one per trial, upsert by trial_id).
class SeedingRepository {
  final AppDatabase _db;

  SeedingRepository(this._db);

  /// Inserts a new row when no record exists for the given trial_id;
  /// updates the existing row when one already exists.
  /// Never creates a second row for the same trial (unique on trial_id).
  Future<void> upsertSeedingEvent(SeedingEventsCompanion companion) async {
    await _db.into(_db.seedingEvents).insert(
          companion,
          onConflict: DoUpdate<$SeedingEventsTable, SeedingEvent>(
            (_) => companion,
            target: [_db.seedingEvents.trialId],
          ),
        );
  }

  /// Returns the single seeding event for the trial, or null if none.
  Future<SeedingEvent?> getSeedingEventForTrial(int trialId) {
    return (_db.select(_db.seedingEvents)
          ..where((e) => e.trialId.equals(trialId)))
        .getSingleOrNull();
  }
}
