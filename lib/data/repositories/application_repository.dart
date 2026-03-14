import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class ApplicationRepository {
  final AppDatabase _db;

  ApplicationRepository(this._db);

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

  Future<void> createApplication(TrialApplicationEventsCompanion companion) {
    final full = _withNewFields(companion);
    return _db.into(_db.trialApplicationEvents).insert(full);
  }

  Future<void> updateApplication(
      String id, TrialApplicationEventsCompanion companion) {
    final full = _withNewFields(companion);
    return (_db.update(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .write(full);
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

  Future<void> deleteApplication(String id) {
    return (_db.delete(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(id)))
        .go();
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
              ..where((p) => p.trialId.equals(trialId)))
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
