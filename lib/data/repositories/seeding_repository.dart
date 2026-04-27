import 'dart:convert';
import 'dart:developer' show log;

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

    // ALCOA+ lock: after seeding is marked completed, only allow editable fields.
    if (existing != null && existing.completedAt != null) {
      // Validate emergence fields if they are being changed.
      if (companion.emergenceDate.present && companion.emergenceDate.value != null) {
        final emErr = validateEmergenceDate(
          seedingDate: existing.seedingDate,
          emergenceDate: companion.emergenceDate.value!,
        );
        if (emErr != null) throw OperationalDateRuleException(emErr);
      }
      final effectiveEmergencePct = companion.emergencePct.present
          ? companion.emergencePct.value
          : existing.emergencePct;
      final pctErr = validateEmergencePercent(effectiveEmergencePct);
      if (pctErr != null) throw OperationalDateRuleException(pctErr);

      final locked = _withLastEditIfUser(
        SeedingEventsCompanion(
          operatorName: companion.operatorName,
          notes: companion.notes,
          equipmentUsed: companion.equipmentUsed,
          emergenceDate: companion.emergenceDate,
          emergencePct: companion.emergencePct,
          temperatureC: companion.temperatureC,
          humidityPct: companion.humidityPct,
          windSpeedKmh: companion.windSpeedKmh,
          windDirection: companion.windDirection,
          cloudCoverPct: companion.cloudCoverPct,
          precipitation: companion.precipitation,
          precipitationMm: companion.precipitationMm,
          soilMoisture: companion.soilMoisture,
          soilTemperature: companion.soilTemperature,
          conditionsRecordedAt: companion.conditionsRecordedAt,
        ),
        performedByUserId,
      );

      final changedFields = <String, dynamic>{};
      if (companion.operatorName.present && companion.operatorName.value != existing.operatorName) {
        changedFields['operatorName'] = companion.operatorName.value;
      }
      if (companion.notes.present && companion.notes.value != existing.notes) {
        changedFields['notes'] = companion.notes.value;
      }
      if (companion.equipmentUsed.present && companion.equipmentUsed.value != existing.equipmentUsed) {
        changedFields['equipmentUsed'] = companion.equipmentUsed.value;
      }
      if (companion.emergenceDate.present && companion.emergenceDate.value != existing.emergenceDate) {
        changedFields['emergenceDate'] = companion.emergenceDate.value?.toIso8601String();
      }
      if (companion.emergencePct.present && companion.emergencePct.value != existing.emergencePct) {
        changedFields['emergencePct'] = companion.emergencePct.value;
      }
      if (companion.temperatureC.present && companion.temperatureC.value != existing.temperatureC) {
        changedFields['temperatureC'] = companion.temperatureC.value;
      }
      if (companion.humidityPct.present && companion.humidityPct.value != existing.humidityPct) {
        changedFields['humidityPct'] = companion.humidityPct.value;
      }
      if (companion.windSpeedKmh.present && companion.windSpeedKmh.value != existing.windSpeedKmh) {
        changedFields['windSpeedKmh'] = companion.windSpeedKmh.value;
      }
      if (companion.windDirection.present && companion.windDirection.value != existing.windDirection) {
        changedFields['windDirection'] = companion.windDirection.value;
      }
      if (companion.cloudCoverPct.present && companion.cloudCoverPct.value != existing.cloudCoverPct) {
        changedFields['cloudCoverPct'] = companion.cloudCoverPct.value;
      }
      if (companion.precipitation.present && companion.precipitation.value != existing.precipitation) {
        changedFields['precipitation'] = companion.precipitation.value;
      }
      if (companion.precipitationMm.present && companion.precipitationMm.value != existing.precipitationMm) {
        changedFields['precipitationMm'] = companion.precipitationMm.value;
      }
      if (companion.soilMoisture.present && companion.soilMoisture.value != existing.soilMoisture) {
        changedFields['soilMoisture'] = companion.soilMoisture.value;
      }
      if (companion.soilTemperature.present && companion.soilTemperature.value != existing.soilTemperature) {
        changedFields['soilTemperature'] = companion.soilTemperature.value;
      }

      await _db.transaction(() async {
        await (_db.update(_db.seedingEvents)
              ..where((e) => e.id.equals(existing.id)))
            .write(locked);
        if (changedFields.isNotEmpty) {
          try {
            await _db.into(_db.auditEvents).insert(
                  AuditEventsCompanion.insert(
                    trialId: Value(existing.trialId),
                    eventType: 'SEEDING_EVENT_UPDATED',
                    description: 'Completed seeding event updated',
                    performedBy: Value(performedBy),
                    performedByUserId: Value(performedByUserId),
                    metadata: Value(jsonEncode({
                      'seeding_event_id': existing.id,
                      'trial_id': existing.trialId,
                      'changedFields': changedFields,
                    })),
                  ),
                );
          } catch (e, st) {
            log('SEEDING_EVENT_UPDATED audit insert failed: $e\n$st',
                name: 'SeedingRepository');
          }
        }
      });
      return;
    }

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

  /// Writes weather to a completed seeding event exactly once (null-check lock).
  /// Silent no-op if temperatureC is already set.
  Future<void> updateSeedingWeather({
    required String seedingEventId,
    required double? temperatureC,
    required double? humidityPct,
    required double? windSpeedKmh,
    required String? windDirection,
    required double? cloudCoverPct,
    required String? precipitation,
    required double? precipitationMm,
    required String? soilMoisture,
    required double? soilTemperature,
  }) async {
    final existing = await (_db.select(_db.seedingEvents)
          ..where((e) => e.id.equals(seedingEventId)))
        .getSingleOrNull();
    if (existing == null) return;
    if (existing.temperatureC != null) return;
    await _db.transaction(() async {
      await (_db.update(_db.seedingEvents)
            ..where((e) => e.id.equals(seedingEventId)))
          .write(SeedingEventsCompanion(
        temperatureC: Value(temperatureC),
        humidityPct: Value(humidityPct),
        windSpeedKmh: Value(windSpeedKmh),
        windDirection: Value(windDirection),
        cloudCoverPct: Value(cloudCoverPct),
        precipitation: Value(precipitation),
        precipitationMm: Value(precipitationMm),
        soilMoisture: Value(soilMoisture),
        soilTemperature: Value(soilTemperature),
        conditionsRecordedAt: Value(DateTime.now().toUtc()),
      ));
      try {
        await _db.into(_db.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(existing.trialId),
                eventType: 'SEEDING_WEATHER_CAPTURED',
                description: 'Weather captured for completed seeding event',
                metadata: Value(jsonEncode({
                  'seeding_event_id': seedingEventId,
                  'trial_id': existing.trialId,
                  'source': 'api',
                  'temperatureC': temperatureC,
                  'precipitationMm': precipitationMm,
                  'completedAt': existing.completedAt?.toIso8601String(),
                })),
              ),
            );
      } catch (e, st) {
        log('SEEDING_WEATHER_CAPTURED audit insert failed: $e\n$st',
            name: 'SeedingRepository');
      }
    });
  }

  /// Writes GPS to a completed seeding event exactly once (null-check lock).
  /// Silent no-op if capturedLatitude is already set.
  Future<void> updateSeedingGps({
    required String seedingEventId,
    required double latitude,
    required double longitude,
  }) async {
    final existing = await (_db.select(_db.seedingEvents)
          ..where((e) => e.id.equals(seedingEventId)))
        .getSingleOrNull();
    if (existing == null) return;
    if (existing.capturedLatitude != null) return;
    await _db.transaction(() async {
      await (_db.update(_db.seedingEvents)
            ..where((e) => e.id.equals(seedingEventId)))
          .write(SeedingEventsCompanion(
        capturedLatitude: Value(latitude),
        capturedLongitude: Value(longitude),
        locationCapturedAt: Value(DateTime.now().toUtc()),
      ));
      try {
        await _db.into(_db.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(existing.trialId),
                eventType: 'SEEDING_GPS_CAPTURED',
                description: 'GPS captured for completed seeding event',
                metadata: Value(jsonEncode({
                  'seeding_event_id': seedingEventId,
                  'trial_id': existing.trialId,
                  'latitude': latitude,
                  'longitude': longitude,
                })),
              ),
            );
      } catch (e, st) {
        log('SEEDING_GPS_CAPTURED audit insert failed: $e\n$st',
            name: 'SeedingRepository');
      }
    });
  }
}
