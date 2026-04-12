import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Repository for trial-level seeding events (one per trial, upsert by trial_id).
class SeedingRepository {
  final AppDatabase _db;

  SeedingRepository(this._db);

  SeedingEventsCompanion _withLastEditIfUser(
    SeedingEventsCompanion base,
    int? performedByUserId,
  ) {
    if (performedByUserId == null) return base;
    return base.copyWith(
      lastEditedAt: Value(DateTime.now().toUtc()),
      lastEditedByUserId: Value(performedByUserId),
    );
  }

  /// Inserts a new row when no record exists for the given trial_id;
  /// updates the existing row when one already exists.
  /// Never creates a second row for the same trial (unique on trial_id).
  Future<void> upsertSeedingEvent(
    SeedingEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async {
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
    final fullWithEdit = _withLastEditIfUser(full, performedByUserId);
    await _db.transaction(() async {
      await _db.into(_db.seedingEvents).insert(
            fullWithEdit,
            onConflict: DoUpdate<$SeedingEventsTable, SeedingEvent>(
              (_) => fullWithEdit,
              target: [_db.seedingEvents.trialId],
            ),
          );

      if (!companion.trialId.present) return;
      final trialPk = companion.trialId.value;
      final row = await getSeedingEventForTrial(trialPk);
      if (row == null) return;

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(row.trialId),
              eventType: 'SEEDING_EVENT_UPSERTED',
              description: 'Seeding event saved',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'seeding_event_id': row.id,
                'trial_id': row.trialId,
                'status': row.status,
                'seeding_date': row.seedingDate.toIso8601String(),
              })),
            ),
          );
    });
  }

  /// Sets lifecycle to completed (seeding workflow).
  Future<void> markSeedingCompleted({
    required String id,
    required DateTime completedAt,
    String? performedBy,
    int? performedByUserId,
  }) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.seedingEvents)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();

      final completedCompanion = _withLastEditIfUser(
        SeedingEventsCompanion(
          status: const Value('completed'),
          completedAt: Value(completedAt),
        ),
        performedByUserId,
      );
      await (_db.update(_db.seedingEvents)..where((e) => e.id.equals(id)))
          .write(completedCompanion);

      if (existing == null) return;

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              eventType: 'SEEDING_EVENT_COMPLETED',
              description: 'Seeding event marked completed',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'seeding_event_id': id,
                'trial_id': existing.trialId,
                'status': 'completed',
                'completed_at': completedAt.toIso8601String(),
              })),
            ),
          );
    });
  }

  /// Returns the single seeding event for the trial, or null if none.
  Future<SeedingEvent?> getSeedingEventForTrial(int trialId) {
    return (_db.select(_db.seedingEvents)
          ..where((e) => e.trialId.equals(trialId)))
        .getSingleOrNull();
  }
}
