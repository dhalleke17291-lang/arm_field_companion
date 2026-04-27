import 'dart:convert';
import 'dart:developer' show log;

import 'package:drift/drift.dart';
import '../../core/application_state.dart';
import '../../core/database/app_database.dart';
import '../../core/field_operation_date_rules.dart';

class ApplicationRepository {
  final AppDatabase _db;

  ApplicationRepository(this._db);

  Future<DateTime?> _seedingDateForTrial(int trialId) async {
    final row = await (_db.select(_db.seedingEvents)
          ..where((s) => s.trialId.equals(trialId)))
        .getSingleOrNull();
    return row?.seedingDate;
  }

  Future<void> _assertApplicationEventDate({
    required int trialId,
    required DateTime applicationDate,
  }) async {
    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingleOrNull();
    if (trial == null) {
      throw OperationalDateRuleException('Trial not found');
    }
    final seedingDate = await _seedingDateForTrial(trialId);
    final err = validateApplicationEventDate(
      applicationDate: applicationDate,
      trialCreatedAt: trial.createdAt,
      seedingDate: seedingDate,
    );
    if (err != null) {
      throw OperationalDateRuleException(err);
    }
  }

  // ── Trial application events (trial_application_events table) ────────────
  // days_after_seeding is never stored; derived at read time from application_date minus seeding date.

  Stream<List<TrialApplicationEvent>> watchApplicationsForTrial(int trialId) {
    return (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.asc(e.applicationDate)]))
        .watch();
  }

  Future<List<TrialApplicationEvent>> getApplicationsForTrial(int trialId) {
    return (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.asc(e.applicationDate)]))
        .get();
  }

  Future<String> createApplication(
    TrialApplicationEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    if (!companion.trialId.present || !companion.applicationDate.present) {
      throw OperationalDateRuleException(
          'Trial id and application date are required');
    }
    await _assertApplicationEventDate(
      trialId: companion.trialId.value,
      applicationDate: companion.applicationDate.value,
    );
    final full = _withLastEditIfUser(
      _withNewFields(companion),
      performedByUserId,
    );
    return _db.transaction(() async {
      final row =
          await _db.into(_db.trialApplicationEvents).insertReturning(full);
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(row.trialId),
              eventType: 'TRIAL_APPLICATION_EVENT_CREATED',
              description: 'Trial application event created',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'trial_application_event_id': row.id,
                'trial_id': row.trialId,
                'status': row.status,
                'application_date': row.applicationDate.toIso8601String(),
              })),
            ),
          );
      return row.id;
    });
  }

  Future<void> updateApplication(
    String id,
    TrialApplicationEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final prior = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (prior == null) return;

    final bool isConfirmed = prior.appliedAt != null ||
        prior.status == kAppStatusApplied ||
        prior.status == 'complete';

    if (isConfirmed) {
      // ALCOA+ lock: silently ignore execution fields; allow only annotations.
      final locked = _withLastEditIfUser(
        TrialApplicationEventsCompanion(
          operatorName: companion.operatorName,
          notes: companion.notes,
          windSpeed: companion.windSpeed,
          windDirection: companion.windDirection,
          temperature: companion.temperature,
          humidity: companion.humidity,
          cloudCoverPct: companion.cloudCoverPct,
          soilMoisture: companion.soilMoisture,
          soilTemperature: companion.soilTemperature,
          soilTempUnit: companion.soilTempUnit,
          soilDepth: companion.soilDepth,
          soilDepthUnit: companion.soilDepthUnit,
          precipitation: companion.precipitation,
          precipitationMm: companion.precipitationMm,
          conditionsRecordedAt: companion.conditionsRecordedAt,
        ),
        performedByUserId,
      );
      final changedFields = <String, dynamic>{};
      if (locked.operatorName.present &&
          locked.operatorName.value != prior.operatorName) {
        changedFields['operatorName'] = locked.operatorName.value;
      }
      if (locked.notes.present && locked.notes.value != prior.notes) {
        changedFields['notes'] = locked.notes.value;
      }
      if (locked.windSpeed.present &&
          locked.windSpeed.value != prior.windSpeed) {
        changedFields['windSpeed'] = locked.windSpeed.value;
      }
      if (locked.windDirection.present &&
          locked.windDirection.value != prior.windDirection) {
        changedFields['windDirection'] = locked.windDirection.value;
      }
      if (locked.temperature.present &&
          locked.temperature.value != prior.temperature) {
        changedFields['temperature'] = locked.temperature.value;
      }
      if (locked.humidity.present && locked.humidity.value != prior.humidity) {
        changedFields['humidity'] = locked.humidity.value;
      }
      if (locked.cloudCoverPct.present &&
          locked.cloudCoverPct.value != prior.cloudCoverPct) {
        changedFields['cloudCoverPct'] = locked.cloudCoverPct.value;
      }
      if (locked.soilMoisture.present &&
          locked.soilMoisture.value != prior.soilMoisture) {
        changedFields['soilMoisture'] = locked.soilMoisture.value;
      }
      if (locked.soilTemperature.present &&
          locked.soilTemperature.value != prior.soilTemperature) {
        changedFields['soilTemperature'] = locked.soilTemperature.value;
      }
      if (locked.precipitation.present &&
          locked.precipitation.value != prior.precipitation) {
        changedFields['precipitation'] = locked.precipitation.value;
      }
      if (locked.precipitationMm.present &&
          locked.precipitationMm.value != prior.precipitationMm) {
        changedFields['precipitationMm'] = locked.precipitationMm.value;
      }
      if (locked.conditionsRecordedAt.present &&
          locked.conditionsRecordedAt.value != prior.conditionsRecordedAt) {
        changedFields['conditionsRecordedAt'] =
            locked.conditionsRecordedAt.value?.toIso8601String();
      }
      await _db.transaction(() async {
        await (_db.update(_db.trialApplicationEvents)
              ..where((e) => e.id.equals(id)))
            .write(locked);
        if (changedFields.isNotEmpty) {
          try {
            await _db.into(_db.auditEvents).insert(
                  AuditEventsCompanion.insert(
                    trialId: Value(prior.trialId),
                    eventType: 'APPLICATION_EVENT_UPDATED',
                    description: 'Application annotation updated',
                    performedBy: Value(performedBy),
                    performedByUserId: Value(performedByUserId),
                    metadata: Value(jsonEncode({
                      'trial_application_event_id': id,
                      'trial_id': prior.trialId,
                      'changed_fields': changedFields,
                    })),
                  ),
                );
          } catch (e, st) {
            log(
              'APPLICATION_EVENT_UPDATED audit insert failed: $e\n$st',
              name: 'ApplicationRepository',
            );
          }
        }
      });
      return;
    }

    final effectiveDate = companion.applicationDate.present
        ? companion.applicationDate.value
        : prior.applicationDate;
    await _assertApplicationEventDate(
      trialId: prior.trialId,
      applicationDate: effectiveDate,
    );
    final full = _withLastEditIfUser(
      _withNewFields(companion),
      performedByUserId,
    );
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(full);
      final row = await (_db.select(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(row.trialId),
              eventType: 'TRIAL_APPLICATION_EVENT_UPDATED',
              description: 'Trial application event updated',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'trial_application_event_id': row.id,
                'trial_id': row.trialId,
                'status': row.status,
                'application_date': row.applicationDate.toIso8601String(),
              })),
            ),
          );
    });
  }

  /// Sets lifecycle to applied (trial application sheet workflow).
  Future<void> markApplicationApplied({
    required String id,
    required DateTime appliedAt,
    String? performedBy,
    int? performedByUserId,
  }) async {
    final existing = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;
    assertValidApplicationTransition(existing.status, kAppStatusApplied);
    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(existing.trialId)))
        .getSingleOrNull();
    if (trial == null) {
      throw OperationalDateRuleException('Trial not found');
    }
    final seedingDate = await _seedingDateForTrial(existing.trialId);
    final appliedErr = validateAppliedDateTime(
      appliedAt: appliedAt,
      trialCreatedAt: trial.createdAt,
      seedingDate: seedingDate,
    );
    if (appliedErr != null) {
      throw OperationalDateRuleException(appliedErr);
    }
    final clockErr = validateAppliedTimestampNotInFuture(appliedAt);
    if (clockErr != null) {
      throw OperationalDateRuleException(clockErr);
    }

    await _db.transaction(() async {

      final appliedCompanion = _withLastEditIfUser(
        TrialApplicationEventsCompanion(
          status: const Value('applied'),
          appliedAt: Value(appliedAt),
        ),
        performedByUserId,
      );
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(appliedCompanion);

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              eventType: 'TRIAL_APPLICATION_EVENT_APPLIED',
              description: 'Trial application event marked applied',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'trial_application_event_id': id,
                'trial_id': existing.trialId,
                'status': 'applied',
                'applied_at': appliedAt.toIso8601String(),
              })),
            ),
          );
    });
  }

  /// Marks application as complete — researcher confirms all data entered.
  /// Fields still editable but changes are logged.
  Future<void> completeApplication(String id, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final prior = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (prior == null) return;
    assertValidApplicationTransition(prior.status, 'complete');
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(TrialApplicationEventsCompanion(
        completedAt: Value(DateTime.now().toUtc()),
        status: const Value('complete'),
      ));
      final existing = await (_db.select(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (existing != null) {
        await _db.into(_db.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(existing.trialId),
                eventType: 'TRIAL_APPLICATION_COMPLETED',
                description: 'Application session completed',
                performedBy: Value(performedBy),
                performedByUserId: Value(performedByUserId),
              ),
            );
      }
    });
  }

  /// Locks the application — no further edits without correction workflow.
  Future<void> closeApplication(String id, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final prior = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (prior == null) return;
    assertValidApplicationTransition(prior.status, kAppStatusClosed);
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(TrialApplicationEventsCompanion(
        closedAt: Value(DateTime.now().toUtc()),
        status: const Value('closed'),
      ));
      final existing = await (_db.select(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (existing != null) {
        await _db.into(_db.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(existing.trialId),
                eventType: 'TRIAL_APPLICATION_CLOSED',
                description: 'Application session closed',
                performedBy: Value(performedBy),
                performedByUserId: Value(performedByUserId),
              ),
            );
      }
    });
  }

  /// Cancels an application — valid from pending or applied.
  Future<void> cancelApplication(String id, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final prior = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (prior == null) return;
    assertValidApplicationTransition(prior.status, kAppStatusCancelled);
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(const TrialApplicationEventsCompanion(
        status: Value('cancelled'),
      ));
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(prior.trialId),
              eventType: 'TRIAL_APPLICATION_CANCELLED',
              description: 'Application cancelled',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'trial_application_event_id': id,
                'trial_id': prior.trialId,
                'previous_status': prior.status,
              })),
            ),
          );
    });
  }

  TrialApplicationEventsCompanion _withLastEditIfUser(
    TrialApplicationEventsCompanion base,
    int? performedByUserId,
  ) {
    if (performedByUserId == null) return base;
    return base.copyWith(
      lastEditedAt: Value(DateTime.now().toUtc()),
      lastEditedByUserId: Value(performedByUserId),
    );
  }

  TrialApplicationEventsCompanion _withNewFields(
      TrialApplicationEventsCompanion c) {
    return c.copyWith(
      applicationTime: c.applicationTime.present
          ? Value(c.applicationTime.value)
          : const Value.absent(),
      applicationMethod: c.applicationMethod.present
          ? Value(c.applicationMethod.value)
          : const Value.absent(),
      nozzleType: c.nozzleType.present
          ? Value(c.nozzleType.value)
          : const Value.absent(),
      nozzleSpacingCm: c.nozzleSpacingCm.present
          ? Value(c.nozzleSpacingCm.value)
          : const Value.absent(),
      operatingPressure: c.operatingPressure.present
          ? Value(c.operatingPressure.value)
          : const Value.absent(),
      pressureUnit: c.pressureUnit.present
          ? Value(c.pressureUnit.value)
          : const Value.absent(),
      groundSpeed: c.groundSpeed.present
          ? Value(c.groundSpeed.value)
          : const Value.absent(),
      speedUnit: c.speedUnit.present
          ? Value(c.speedUnit.value)
          : const Value.absent(),
      adjuvantName: c.adjuvantName.present
          ? Value(c.adjuvantName.value)
          : const Value.absent(),
      adjuvantRate: c.adjuvantRate.present
          ? Value(c.adjuvantRate.value)
          : const Value.absent(),
      adjuvantRateUnit: c.adjuvantRateUnit.present
          ? Value(c.adjuvantRateUnit.value)
          : const Value.absent(),
      spraySolutionPh: c.spraySolutionPh.present
          ? Value(c.spraySolutionPh.value)
          : const Value.absent(),
      waterVolumeUnit: c.waterVolumeUnit.present
          ? Value(c.waterVolumeUnit.value)
          : const Value.absent(),
      cloudCoverPct: c.cloudCoverPct.present
          ? Value(c.cloudCoverPct.value)
          : const Value.absent(),
      soilMoisture: c.soilMoisture.present
          ? Value(c.soilMoisture.value)
          : const Value.absent(),
      treatedArea: c.treatedArea.present
          ? Value(c.treatedArea.value)
          : const Value.absent(),
      treatedAreaUnit: c.treatedAreaUnit.present
          ? Value(c.treatedAreaUnit.value)
          : const Value.absent(),
      plotsTreated: c.plotsTreated.present
          ? Value(c.plotsTreated.value)
          : const Value.absent(),
    );
  }

  Future<void> deleteApplication(String id) async {
    await (_db.delete(_db.trialApplicationProducts)
          ..where((p) => p.trialApplicationEventId.equals(id)))
        .go();
    await (_db.delete(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .go();
  }

  /// Writes weather to a confirmed application exactly once (null-check lock).
  /// Silent no-op if any of the 7 primary fields are already populated.
  Future<void> updateApplicationWeather({
    required String applicationId,
    required double? temperatureC,
    required double? humidityPct,
    required double? windSpeedKmh,
    required String? windDirection,
    required double? cloudCoverPct,
    required String? precipitation,
    required double? precipitationMm,
    String? soilMoisture,
    double? soilTemperature,
  }) async {
    final row = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(applicationId)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.temperature != null ||
        row.humidity != null ||
        row.windSpeed != null ||
        row.cloudCoverPct != null ||
        row.precipitation != null ||
        row.precipitationMm != null ||
        row.conditionsRecordedAt != null) {
      return;
    }
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(applicationId)))
          .write(TrialApplicationEventsCompanion(
        temperature: Value(temperatureC),
        humidity: Value(humidityPct),
        windSpeed: Value(windSpeedKmh),
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
                trialId: Value(row.trialId),
                eventType: 'APPLICATION_WEATHER_CAPTURED',
                description: 'Weather captured for confirmed application',
                metadata: Value(jsonEncode({
                  'trial_application_event_id': applicationId,
                  'trial_id': row.trialId,
                })),
              ),
            );
      } catch (e, st) {
        log('APPLICATION_WEATHER_CAPTURED audit insert failed: $e\n$st',
            name: 'ApplicationRepository');
      }
    });
  }

  /// Writes GPS to a confirmed application exactly once (null-check lock).
  /// Silent no-op if `capturedLatitude` is already set.
  Future<void> updateApplicationGps({
    required String applicationId,
    required double latitude,
    required double longitude,
  }) async {
    final row = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(applicationId)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.capturedLatitude != null) return;
    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(applicationId)))
          .write(TrialApplicationEventsCompanion(
        capturedLatitude: Value(latitude),
        capturedLongitude: Value(longitude),
        locationCapturedAt: Value(DateTime.now().toUtc()),
      ));
      try {
        await _db.into(_db.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(row.trialId),
                eventType: 'APPLICATION_GPS_CAPTURED',
                description: 'GPS captured for confirmed application',
                metadata: Value(jsonEncode({
                  'trial_application_event_id': applicationId,
                  'trial_id': row.trialId,
                  'latitude': latitude,
                  'longitude': longitude,
                })),
              ),
            );
      } catch (e, st) {
        log('APPLICATION_GPS_CAPTURED audit insert failed: $e\n$st',
            name: 'ApplicationRepository');
      }
    });
  }

  // ── Slot-based application events (application_events table) ─────────────

  Stream<List<ApplicationEvent>> watchEventsForTrial(int trialId) {
    return (_db.select(_db.applicationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.desc(e.applicationDate)]))
        .watch();
  }

  Future<List<ApplicationEvent>> getEventsForTrial(int trialId) {
    return (_db.select(_db.applicationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.desc(e.applicationDate)]))
        .get();
  }

  Future<int> insertEvent({
    required int trialId,
    int? sessionId,
    required int applicationNumber,
    String? timingLabel,
    required String method,
    required DateTime applicationDate,
    String? growthStage,
    String? operatorName,
    String? equipment,
    String? weather,
    String? notes,
  }) {
    return _db.into(_db.applicationEvents).insert(
          ApplicationEventsCompanion.insert(
            trialId: trialId,
            sessionId: Value(sessionId),
            applicationNumber: Value(applicationNumber),
            timingLabel: Value(timingLabel),
            method: Value(method),
            applicationDate: applicationDate,
            growthStage: Value(growthStage),
            operatorName: Value(operatorName),
            equipment: Value(equipment),
            weather: Value(weather),
            notes: Value(notes),
          ),
        );
  }

  // ── Plot Records ─────────────────────────────────────────

  Future<List<ApplicationPlotRecord>> getPlotRecordsForEvent(int eventId) {
    return (_db.select(_db.applicationPlotRecords)
          ..where((r) => r.eventId.equals(eventId)))
        .get();
  }

  Future<int> insertPlotRecord({
    required int eventId,
    required int plotPk,
    required int trialId,
    String status = 'applied',
    String? notes,
  }) {
    return _db.into(_db.applicationPlotRecords).insert(
          ApplicationPlotRecordsCompanion.insert(
            eventId: eventId,
            plotPk: plotPk,
            trialId: trialId,
            status: Value(status),
            notes: Value(notes),
          ),
        );
  }

  Future<int> getNextApplicationNumber(int trialId) async {
    final events = await getEventsForTrial(trialId);
    if (events.isEmpty) return 1;
    return events
            .map((e) => e.applicationNumber)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> markCompleted({
    required int eventId,
    required int trialId,
    required String completedBy,
    required bool coversEntireTrial,
    List<int>? specificPlotPks,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.applicationEvents)
            ..where((e) => e.id.equals(eventId)))
          .write(ApplicationEventsCompanion(
        status: const Value('completed'),
        completedAt: Value(DateTime.now()),
        completedBy: Value(completedBy.isEmpty ? null : completedBy),
        partialFlag: Value(!coversEntireTrial),
      ));

      List<int> plotPks;
      if (coversEntireTrial) {
        final plots = await (_db.select(_db.plots)
              ..where((p) =>
                  p.trialId.equals(trialId) & p.isDeleted.equals(false)))
            .get();
        plotPks = plots.map((p) => p.id).toList();
      } else {
        plotPks = specificPlotPks ?? [];
      }

      await (_db.delete(_db.applicationPlotRecords)
            ..where((r) => r.eventId.equals(eventId)))
          .go();

      for (final pk in plotPks) {
        await _db.into(_db.applicationPlotRecords).insert(
              ApplicationPlotRecordsCompanion.insert(
                eventId: eventId,
                plotPk: pk,
                trialId: trialId,
                status: const Value('applied'),
              ),
            );
      }
    });
  }

  Future<void> updateEvent(ApplicationEvent event) {
    return (_db.update(_db.applicationEvents)
          ..where((e) => e.id.equals(event.id)))
        .write(ApplicationEventsCompanion(
      timingLabel: Value(event.timingLabel),
      method: Value(event.method),
      applicationDate: Value(event.applicationDate),
      growthStage: Value(event.growthStage),
      operatorName: Value(event.operatorName),
      equipment: Value(event.equipment),
      weather: Value(event.weather),
      notes: Value(event.notes),
    ));
  }

  Future<void> deleteEvent(int eventId) async {
    await (_db.delete(_db.applicationPlotRecords)
          ..where((r) => r.eventId.equals(eventId)))
        .go();
    await (_db.delete(_db.applicationEvents)
          ..where((e) => e.id.equals(eventId)))
        .go();
  }
}
