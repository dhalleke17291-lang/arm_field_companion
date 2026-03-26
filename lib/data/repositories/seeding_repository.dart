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
    final full = companion.copyWith(
      variety: companion.variety.present
          ? Value(companion.variety.value)
          : const Value.absent(),
      seedTreatment: companion.seedTreatment.present
          ? Value(companion.seedTreatment.value)
          : const Value.absent(),
      germinationPct: companion.germinationPct.present
          ? Value(companion.germinationPct.value)
          : const Value.absent(),
      emergenceDate: companion.emergenceDate.present
          ? Value(companion.emergenceDate.value)
          : const Value.absent(),
      emergencePct: companion.emergencePct.present
          ? Value(companion.emergencePct.value)
          : const Value.absent(),
      plantingMethod: companion.plantingMethod.present
          ? Value(companion.plantingMethod.value)
          : const Value.absent(),
    );
    await _db.into(_db.seedingEvents).insert(
          full,
          onConflict: DoUpdate<$SeedingEventsTable, SeedingEvent>(
            (_) => full,
            target: [_db.seedingEvents.trialId],
          ),
        );
  }

  /// Sets lifecycle to completed (seeding workflow).
  Future<void> markSeedingCompleted({
    required String id,
    required DateTime completedAt,
  }) {
    return (_db.update(_db.seedingEvents)..where((e) => e.id.equals(id))).write(
          SeedingEventsCompanion(
            status: const Value('completed'),
            completedAt: Value(completedAt),
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
