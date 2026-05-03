import 'dart:convert';
import 'dart:developer' show log;

import 'package:drift/drift.dart';
import '../../core/application_state.dart';
import '../../core/database/app_database.dart';
import '../../core/field_operation_date_rules.dart';
import '../../core/protocol_edit_blocked_exception.dart';

const Set<String> kApplicationAnnotationFields = {
  'growthStageCode',
  'growthStageBbchAtApplication',
  'windSpeed',
  'windDirection',
  'temperature',
  'humidity',
  'cloudCoverPct',
  'soilMoisture',
  'soilTemperature',
  'soilTempUnit',
  'soilDepth',
  'soilDepthUnit',
  'precipitation',
  'precipitationMm',
  'conditionsRecordedAt',
  'equipmentUsed',
  'applicationMethod',
  'nozzleType',
  'nozzleSpacingCm',
  'operatingPressure',
  'pressureUnit',
  'groundSpeed',
  'speedUnit',
  'boomHeightCm',
  'operatorName',
  'notes',
  'treatedArea',
  'treatedAreaUnit',
  'spraySolutionPh',
  'adjuvantName',
  'adjuvantRate',
  'adjuvantRateUnit',
  'waterVolume',
  'waterVolumeUnit',
};

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
      final changed = _actuallyChangedFields(companion, prior);
      if (changed.isEmpty) return;
      final structuralChanged =
          changed.where((f) => !kApplicationAnnotationFields.contains(f));
      if (structuralChanged.isNotEmpty) {
        throw ProtocolEditBlockedException(
          'Application is confirmed; structural fields cannot be changed: '
          '${structuralChanged.join(', ')}.',
        );
      }
      // Structural columns may be `.present` unchanged (UI mirrors full row);
      // [updateApplicationAnnotationsOnly] rejects any structural `.present`.
      final annotationCompanion = _onlyAnnotationFields(companion);
      return updateApplicationAnnotationsOnly(
        id,
        annotationCompanion,
        performedBy: performedBy,
        performedByUserId: performedByUserId,
      );
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

  /// Writes only annotation fields to a (possibly confirmed) application event.
  /// Throws [ArgumentError] if any structural column is `.present` on [companion].
  /// Audit metadata flags `annotation_only: true`.
  Future<void> updateApplicationAnnotationsOnly(
    String id,
    TrialApplicationEventsCompanion companion, {
    String? performedBy,
    int? performedByUserId,
  }) async {
    final prior = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (prior == null) return;

    final present = _presentFields(companion);
    final structural =
        present.where((f) => !kApplicationAnnotationFields.contains(f)).toList()
          ..sort();
    if (structural.isNotEmpty) {
      throw ArgumentError(
        'updateApplicationAnnotationsOnly received structural fields: '
        '${structural.join(', ')}.',
      );
    }

    final changed = _actuallyChangedFields(companion, prior);
    if (changed.isEmpty) return;

    final filtered = _onlyAnnotationFields(companion);
    final write = _withLastEditIfUser(filtered, performedByUserId);

    await _db.transaction(() async {
      await (_db.update(_db.trialApplicationEvents)
            ..where((e) => e.id.equals(id)))
          .write(write);
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
                  'changed_fields': changed.toList()..sort(),
                  'annotation_only': true,
                })),
              ),
            );
      } catch (e, st) {
        log(
          'APPLICATION_EVENT_UPDATED audit insert failed: $e\n$st',
          name: 'ApplicationRepository',
        );
      }
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

  /// Returns the set of column names where [c] has a `.present` value.
  /// Internal columns (`id`, `trialId`, `createdAt`, `lastEditedAt`,
  /// `lastEditedByUserId`) are excluded — they are managed by the repo.
  Set<String> _presentFields(TrialApplicationEventsCompanion c) {
    final out = <String>{};
    if (c.applicationDate.present) out.add('applicationDate');
    if (c.applicationTime.present) out.add('applicationTime');
    if (c.treatmentId.present) out.add('treatmentId');
    if (c.productName.present) out.add('productName');
    if (c.rate.present) out.add('rate');
    if (c.rateUnit.present) out.add('rateUnit');
    if (c.plotsTreated.present) out.add('plotsTreated');
    if (c.status.present) out.add('status');
    if (c.appliedAt.present) out.add('appliedAt');
    if (c.startedAt.present) out.add('startedAt');
    if (c.completedAt.present) out.add('completedAt');
    if (c.closedAt.present) out.add('closedAt');
    if (c.sessionName.present) out.add('sessionName');
    if (c.totalProductMixed.present) out.add('totalProductMixed');
    if (c.totalAreaSprayedHa.present) out.add('totalAreaSprayedHa');
    if (c.capturedLatitude.present) out.add('capturedLatitude');
    if (c.capturedLongitude.present) out.add('capturedLongitude');
    if (c.locationCapturedAt.present) out.add('locationCapturedAt');
    if (c.growthStageCode.present) out.add('growthStageCode');
    if (c.growthStageBbchAtApplication.present) {
      out.add('growthStageBbchAtApplication');
    }
    if (c.windSpeed.present) out.add('windSpeed');
    if (c.windDirection.present) out.add('windDirection');
    if (c.temperature.present) out.add('temperature');
    if (c.humidity.present) out.add('humidity');
    if (c.cloudCoverPct.present) out.add('cloudCoverPct');
    if (c.soilMoisture.present) out.add('soilMoisture');
    if (c.soilTemperature.present) out.add('soilTemperature');
    if (c.soilTempUnit.present) out.add('soilTempUnit');
    if (c.soilDepth.present) out.add('soilDepth');
    if (c.soilDepthUnit.present) out.add('soilDepthUnit');
    if (c.precipitation.present) out.add('precipitation');
    if (c.precipitationMm.present) out.add('precipitationMm');
    if (c.conditionsRecordedAt.present) out.add('conditionsRecordedAt');
    if (c.equipmentUsed.present) out.add('equipmentUsed');
    if (c.applicationMethod.present) out.add('applicationMethod');
    if (c.nozzleType.present) out.add('nozzleType');
    if (c.nozzleSpacingCm.present) out.add('nozzleSpacingCm');
    if (c.operatingPressure.present) out.add('operatingPressure');
    if (c.pressureUnit.present) out.add('pressureUnit');
    if (c.groundSpeed.present) out.add('groundSpeed');
    if (c.speedUnit.present) out.add('speedUnit');
    if (c.boomHeightCm.present) out.add('boomHeightCm');
    if (c.operatorName.present) out.add('operatorName');
    if (c.notes.present) out.add('notes');
    if (c.treatedArea.present) out.add('treatedArea');
    if (c.treatedAreaUnit.present) out.add('treatedAreaUnit');
    if (c.spraySolutionPh.present) out.add('spraySolutionPh');
    if (c.adjuvantName.present) out.add('adjuvantName');
    if (c.adjuvantRate.present) out.add('adjuvantRate');
    if (c.adjuvantRateUnit.present) out.add('adjuvantRateUnit');
    if (c.waterVolume.present) out.add('waterVolume');
    if (c.waterVolumeUnit.present) out.add('waterVolumeUnit');
    return out;
  }

  /// Column names whose values in [companion] actually differ from [existing].
  ///
  /// `.present` alone is insufficient: callers may rebuild a full companion
  /// with unchanged structural fields alongside real annotation edits.
  Set<String> _actuallyChangedFields(
    TrialApplicationEventsCompanion companion,
    TrialApplicationEvent existing,
  ) {
    final out = <String>{};
    bool diff<T>(Value<T> v, T priorVal) =>
        v.present && v.value != priorVal;
    final c = companion;
    final prior = existing;
    if (diff(c.applicationDate, prior.applicationDate)) {
      out.add('applicationDate');
    }
    if (diff(c.applicationTime, prior.applicationTime)) {
      out.add('applicationTime');
    }
    if (diff(c.treatmentId, prior.treatmentId)) out.add('treatmentId');
    if (diff(c.productName, prior.productName)) out.add('productName');
    if (diff(c.rate, prior.rate)) out.add('rate');
    if (diff(c.rateUnit, prior.rateUnit)) out.add('rateUnit');
    if (diff(c.plotsTreated, prior.plotsTreated)) out.add('plotsTreated');
    if (diff(c.status, prior.status)) out.add('status');
    if (diff(c.appliedAt, prior.appliedAt)) out.add('appliedAt');
    if (diff(c.startedAt, prior.startedAt)) out.add('startedAt');
    if (diff(c.completedAt, prior.completedAt)) out.add('completedAt');
    if (diff(c.closedAt, prior.closedAt)) out.add('closedAt');
    if (diff(c.sessionName, prior.sessionName)) out.add('sessionName');
    if (diff(c.totalProductMixed, prior.totalProductMixed)) {
      out.add('totalProductMixed');
    }
    if (diff(c.totalAreaSprayedHa, prior.totalAreaSprayedHa)) {
      out.add('totalAreaSprayedHa');
    }
    if (diff(c.capturedLatitude, prior.capturedLatitude)) {
      out.add('capturedLatitude');
    }
    if (diff(c.capturedLongitude, prior.capturedLongitude)) {
      out.add('capturedLongitude');
    }
    if (diff(c.locationCapturedAt, prior.locationCapturedAt)) {
      out.add('locationCapturedAt');
    }
    if (diff(c.growthStageCode, prior.growthStageCode)) {
      out.add('growthStageCode');
    }
    if (diff(c.growthStageBbchAtApplication,
        prior.growthStageBbchAtApplication)) {
      out.add('growthStageBbchAtApplication');
    }
    if (diff(c.windSpeed, prior.windSpeed)) out.add('windSpeed');
    if (diff(c.windDirection, prior.windDirection)) out.add('windDirection');
    if (diff(c.temperature, prior.temperature)) out.add('temperature');
    if (diff(c.humidity, prior.humidity)) out.add('humidity');
    if (diff(c.cloudCoverPct, prior.cloudCoverPct)) out.add('cloudCoverPct');
    if (diff(c.soilMoisture, prior.soilMoisture)) out.add('soilMoisture');
    if (diff(c.soilTemperature, prior.soilTemperature)) {
      out.add('soilTemperature');
    }
    if (diff(c.soilTempUnit, prior.soilTempUnit)) out.add('soilTempUnit');
    if (diff(c.soilDepth, prior.soilDepth)) out.add('soilDepth');
    if (diff(c.soilDepthUnit, prior.soilDepthUnit)) out.add('soilDepthUnit');
    if (diff(c.precipitation, prior.precipitation)) out.add('precipitation');
    if (diff(c.precipitationMm, prior.precipitationMm)) {
      out.add('precipitationMm');
    }
    if (diff(c.conditionsRecordedAt, prior.conditionsRecordedAt)) {
      out.add('conditionsRecordedAt');
    }
    if (diff(c.equipmentUsed, prior.equipmentUsed)) out.add('equipmentUsed');
    if (diff(c.applicationMethod, prior.applicationMethod)) {
      out.add('applicationMethod');
    }
    if (diff(c.nozzleType, prior.nozzleType)) out.add('nozzleType');
    if (diff(c.nozzleSpacingCm, prior.nozzleSpacingCm)) {
      out.add('nozzleSpacingCm');
    }
    if (diff(c.operatingPressure, prior.operatingPressure)) {
      out.add('operatingPressure');
    }
    if (diff(c.pressureUnit, prior.pressureUnit)) out.add('pressureUnit');
    if (diff(c.groundSpeed, prior.groundSpeed)) out.add('groundSpeed');
    if (diff(c.speedUnit, prior.speedUnit)) out.add('speedUnit');
    if (diff(c.boomHeightCm, prior.boomHeightCm)) out.add('boomHeightCm');
    if (diff(c.operatorName, prior.operatorName)) out.add('operatorName');
    if (diff(c.notes, prior.notes)) out.add('notes');
    if (diff(c.treatedArea, prior.treatedArea)) out.add('treatedArea');
    if (diff(c.treatedAreaUnit, prior.treatedAreaUnit)) {
      out.add('treatedAreaUnit');
    }
    if (diff(c.spraySolutionPh, prior.spraySolutionPh)) {
      out.add('spraySolutionPh');
    }
    if (diff(c.adjuvantName, prior.adjuvantName)) out.add('adjuvantName');
    if (diff(c.adjuvantRate, prior.adjuvantRate)) out.add('adjuvantRate');
    if (diff(c.adjuvantRateUnit, prior.adjuvantRateUnit)) {
      out.add('adjuvantRateUnit');
    }
    if (diff(c.waterVolume, prior.waterVolume)) out.add('waterVolume');
    if (diff(c.waterVolumeUnit, prior.waterVolumeUnit)) {
      out.add('waterVolumeUnit');
    }
    return out;
  }

  /// Returns a fresh companion containing only annotation-field values from [c].
  /// Structural columns are dropped via `Value.absent()`.
  TrialApplicationEventsCompanion _onlyAnnotationFields(
      TrialApplicationEventsCompanion c) {
    return TrialApplicationEventsCompanion(
      growthStageCode: c.growthStageCode,
      growthStageBbchAtApplication: c.growthStageBbchAtApplication,
      windSpeed: c.windSpeed,
      windDirection: c.windDirection,
      temperature: c.temperature,
      humidity: c.humidity,
      cloudCoverPct: c.cloudCoverPct,
      soilMoisture: c.soilMoisture,
      soilTemperature: c.soilTemperature,
      soilTempUnit: c.soilTempUnit,
      soilDepth: c.soilDepth,
      soilDepthUnit: c.soilDepthUnit,
      precipitation: c.precipitation,
      precipitationMm: c.precipitationMm,
      conditionsRecordedAt: c.conditionsRecordedAt,
      equipmentUsed: c.equipmentUsed,
      applicationMethod: c.applicationMethod,
      nozzleType: c.nozzleType,
      nozzleSpacingCm: c.nozzleSpacingCm,
      operatingPressure: c.operatingPressure,
      pressureUnit: c.pressureUnit,
      groundSpeed: c.groundSpeed,
      speedUnit: c.speedUnit,
      boomHeightCm: c.boomHeightCm,
      operatorName: c.operatorName,
      notes: c.notes,
      treatedArea: c.treatedArea,
      treatedAreaUnit: c.treatedAreaUnit,
      spraySolutionPh: c.spraySolutionPh,
      adjuvantName: c.adjuvantName,
      adjuvantRate: c.adjuvantRate,
      adjuvantRateUnit: c.adjuvantRateUnit,
      waterVolume: c.waterVolume,
      waterVolumeUnit: c.waterVolumeUnit,
    );
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
