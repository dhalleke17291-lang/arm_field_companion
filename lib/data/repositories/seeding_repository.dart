import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/field_operation_date_rules.dart';

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
    if (!companion.trialId.present) {
      throw OperationalDateRuleException('Trial id is required for seeding');
    }
    final trialPk = companion.trialId.value;
    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(trialPk)))
        .getSingleOrNull();
    if (trial == null) {
      throw OperationalDateRuleException('Trial not found');
    }
    final existing = await getSeedingEventForTrial(trialPk);
    final DateTime effectiveSeeding;
    if (companion.seedingDate.present) {
      effectiveSeeding = companion.seedingDate.value;
    } else if (existing != null) {
      effectiveSeeding = existing.seedingDate;
    } else {
      throw OperationalDateRuleException('Seeding date is required');
    }
    final seedingErr = validateSeedingDate(
      seedingDate: effectiveSeeding,
      trialCreatedAt: trial.createdAt,
    );
    if (seedingErr != null) {
      throw OperationalDateRuleException(seedingErr);
    }

    DateTime? effectiveEmergence;
    if (companion.emergenceDate.present) {
      effectiveEmergence = companion.emergenceDate.value;
    } else {
      effectiveEmergence = existing?.emergenceDate;
    }
    if (effectiveEmergence != null) {
      final emErr = validateEmergenceDate(
        seedingDate: effectiveSeeding,
        emergenceDate: effectiveEmergence,
      );
      if (emErr != null) {
        throw OperationalDateRuleException(emErr);
      }
    }

    double? effectiveEmergencePct;
    if (companion.emergencePct.present) {
      effectiveEmergencePct = companion.emergencePct.value;
    } else {
      effectiveEmergencePct = existing?.emergencePct;
    }
    final pctErr = validateEmergencePercent(effectiveEmergencePct);
    if (pctErr != null) {
      throw OperationalDateRuleException(pctErr);
    }

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
    final completedErr = validateNotFutureUtc(completedAt);
    if (completedErr != null) {
      throw OperationalDateRuleException(completedErr);
    }
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
