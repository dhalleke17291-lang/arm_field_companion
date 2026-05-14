import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'signal_decision_dto.dart';
import 'signal_models.dart';

class SignalRepository {
  SignalRepository._(this._resolveDb);

  factory SignalRepository(Ref ref) {
    return SignalRepository._(() => ref.read(databaseProvider));
  }

  factory SignalRepository.attach(AppDatabase database) {
    return SignalRepository._(() => database);
  }

  final AppDatabase Function() _resolveDb;

  AppDatabase get _db => _resolveDb();

  static final Set<String> _openStatuses = {
    SignalStatus.open.dbValue,
    SignalStatus.deferred.dbValue,
    SignalStatus.investigating.dbValue,
  };

  static final Set<String> _terminalStatuses = {
    SignalStatus.resolved.dbValue,
    SignalStatus.expired.dbValue,
    SignalStatus.suppressed.dbValue,
  };

  static int _severityRank(String severity) {
    if (severity == SignalSeverity.critical.dbValue) return 0;
    if (severity == SignalSeverity.review.dbValue) return 1;
    if (severity == SignalSeverity.info.dbValue) return 2;
    return 99;
  }

  static bool _ctxMatches(
    Signal s,
    bool Function(SignalReferenceContext) predicate,
  ) {
    try {
      return predicate(SignalReferenceContext.decodeJson(s.referenceContext));
    } catch (_) {
      return false;
    }
  }

  static void _sortOpenSignals(List<Signal> rows) {
    rows.sort((a, b) {
      final c = _severityRank(a.severity).compareTo(_severityRank(b.severity));
      if (c != 0) return c;
      return a.raisedAt.compareTo(b.raisedAt);
    });
  }

  Future<int> raiseSignal({
    required int trialId,
    int? sessionId,
    int? plotId,
    required SignalType signalType,
    required SignalMoment moment,
    required SignalSeverity severity,
    required SignalReferenceContext referenceContext,
    SignalMagnitudeContext? magnitudeContext,
    required String consequenceText,
    int? raisedBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.signals).insert(
          SignalsCompanion.insert(
            trialId: trialId,
            sessionId:
                sessionId != null ? Value(sessionId) : const Value.absent(),
            plotId: plotId != null ? Value(plotId) : const Value.absent(),
            signalType: signalType.dbValue,
            moment: moment.dbValue,
            severity: severity.dbValue,
            raisedAt: now,
            raisedBy:
                raisedBy != null ? Value(raisedBy) : const Value.absent(),
            referenceContext: referenceContext.encodeJson(),
            magnitudeContext: magnitudeContext != null
                ? Value(magnitudeContext.encodeJson())
                : const Value.absent(),
            consequenceText: consequenceText,
            status: Value(SignalStatus.open.dbValue),
            createdAt: now,
          ),
        );
  }

  /// Records a researcher decision on a signal.
  ///
  /// Sets [occurredAt] to [DateTime.now()] internally — callers cannot supply
  /// a timestamp, preventing backdating.
  ///
  /// Validation: [reason] must be non-empty for confirm, suppress, and
  /// investigate. Defer permits an empty reason (though one is encouraged).
  /// Throws [ArgumentError] if validation fails.
  Future<void> recordResearcherDecision({
    required int signalId,
    required SignalDecisionEventType eventType,
    required String reason,
    int? actorUserId,
  }) async {
    final requiresReason = eventType != SignalDecisionEventType.defer;
    if (requiresReason && reason.trim().isEmpty) {
      throw ArgumentError(
        'reason must be non-empty for ${eventType.dbValue} decisions.',
      );
    }
    final occurredAt = DateTime.now().millisecondsSinceEpoch;
    await recordDecisionEvent(
      signalId: signalId,
      eventType: eventType,
      occurredAt: occurredAt,
      actorUserId: actorUserId,
      note: reason.trim().isEmpty ? null : reason.trim(),
    );
  }

  Future<void> recordDecisionEvent({
    required int signalId,
    required SignalDecisionEventType eventType,
    required int occurredAt,
    int? actorUserId,
    String? note,
    int? followUpDueAt,
    Map<String, dynamic>? followUpContext,
  }) async {
    final resulting = resultingStatusForDecision(eventType).dbValue;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final followJson =
        followUpContext != null ? jsonEncode(followUpContext) : null;

    await _db.transaction(() async {
      await _db.into(_db.signalDecisionEvents).insert(
            SignalDecisionEventsCompanion.insert(
              signalId: signalId,
              eventType: eventType.dbValue,
              occurredAt: occurredAt,
              actorUserId: actorUserId != null
                  ? Value(actorUserId)
                  : const Value.absent(),
              note: note != null ? Value(note) : const Value.absent(),
              followUpDueAt: followUpDueAt != null
                  ? Value(followUpDueAt)
                  : const Value.absent(),
              followUpContext: followJson != null
                  ? Value(followJson)
                  : const Value.absent(),
              resultingStatus: resulting,
              createdAt: createdAt,
            ),
          );

      await (_db.update(_db.signals)..where((s) => s.id.equals(signalId)))
          .write(SignalsCompanion(status: Value(resulting)));
    });
  }

  Future<void> recordActionEffect({
    required int decisionEventId,
    required String entityType,
    required int entityId,
    required String fieldName,
    String? oldValue,
    String? newValue,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.actionEffects).insert(
          ActionEffectsCompanion.insert(
            decisionEventId: decisionEventId,
            entityType: entityType,
            entityId: entityId,
            fieldName: fieldName,
            oldValue:
                oldValue != null ? Value(oldValue) : const Value.absent(),
            newValue:
                newValue != null ? Value(newValue) : const Value.absent(),
            appliedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<List<Signal>> getOpenSignalsForSession(int sessionId) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    _sortOpenSignals(rows);
    return rows;
  }

  Future<List<Signal>> getOpenSignalsForTrial(int trialId) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.trialId.equals(trialId))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    _sortOpenSignals(rows);
    return rows;
  }

  Stream<List<Signal>> watchOpenSignalsForTrial(int trialId) {
    final query = _db.select(_db.signals)
      ..where((s) => s.trialId.equals(trialId))
      ..where((s) => s.status.isIn(_openStatuses.toList()));
    return query.watch().map((rows) {
      final sorted = [...rows];
      _sortOpenSignals(sorted);
      return sorted;
    });
  }

  Future<List<SignalDecisionEvent>> getDecisionHistory(int signalId) async {
    return (_db.select(_db.signalDecisionEvents)
          ..where((e) => e.signalId.equals(signalId))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
  }

  static const _cannedPhrases = [
    'Proceeded at session close',
    'Not shown at session close',
    'Trial closed — signals expired',
  ];

  /// Returns decision events for a signal as DTOs, with actorName resolved.
  Future<List<SignalDecisionDto>> getDecisionHistoryDtos(int signalId) async {
    final events = await (_db.select(_db.signalDecisionEvents)
          ..where((e) => e.signalId.equals(signalId))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
    return _toDecisionDtos(events);
  }

  /// Returns all researcher decision events for a trial, excluding canned
  /// system notes, ordered chronologically.
  Future<List<SignalDecisionDto>> getAllResearcherDecisionEventsForTrial(
      int trialId) async {
    final signals = await (_db.select(_db.signals)
          ..where((s) => s.trialId.equals(trialId)))
        .get();
    if (signals.isEmpty) return [];
    final signalIds = signals.map((s) => s.id).toList();
    final events = await (_db.select(_db.signalDecisionEvents)
          ..where((e) => e.signalId.isIn(signalIds))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
    final filtered = events.where((e) {
      final note = e.note;
      if (note == null || note.isEmpty) return false;
      return !_cannedPhrases.any((phrase) => note.contains(phrase));
    }).toList();
    return _toDecisionDtos(filtered);
  }

  Future<List<SignalDecisionDto>> _toDecisionDtos(
      List<SignalDecisionEvent> events) async {
    final userIds =
        events.map((e) => e.actorUserId).whereType<int>().toSet();
    final nameMap = <int, String>{};
    for (final uid in userIds) {
      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(uid)))
          .getSingleOrNull();
      if (user != null) nameMap[uid] = user.displayName;
    }
    return events
        .map((e) => SignalDecisionDto(
              id: e.id,
              signalId: e.signalId,
              eventType: e.eventType,
              occurredAt: e.occurredAt,
              actorName: e.actorUserId != null ? nameMap[e.actorUserId!] : null,
              note: e.note,
              resultingStatus: e.resultingStatus,
            ))
        .toList();
  }

  Future<List<Signal>> getUnresolvedSignalsBeforeExport(int trialId) async {
    return (_db.select(_db.signals)
          ..where((s) => s.trialId.equals(trialId))
          ..where((s) => s.status.isNotIn(_terminalStatuses.toList())))
        .get();
  }

  Future<void> expireSignal(int signalId, {String? note}) async {
    await recordDecisionEvent(
      signalId: signalId,
      eventType: SignalDecisionEventType.expire,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
      actorUserId: null,
      note: note,
      followUpDueAt: null,
      followUpContext: null,
    );
  }

  /// Drift live query filtered to decision events belonging to [trialId].
  ///
  /// Joins [SignalDecisionEvents] → [Signals] on signalId so only events for
  /// signals owned by this trial are returned. A closure-local ID-set guard
  /// suppresses re-emissions when any other trial's decision event causes the
  /// underlying SQLite table hook to fire but the filtered result hasn't changed
  /// (Drift fires on every table write regardless of the WHERE clause).
  Stream<List<SignalDecisionEvent>> watchDecisionEventsForTrial(int trialId) {
    Set<int>? lastIds;
    return (_db.select(_db.signalDecisionEvents).join([
      innerJoin(
        _db.signals,
        _db.signals.id.equalsExp(_db.signalDecisionEvents.signalId),
      ),
    ])
          ..where(_db.signals.trialId.equals(trialId)))
        .watch()
        .map((rows) =>
            rows.map((r) => r.readTable(_db.signalDecisionEvents)).toList())
        .where((items) {
          final ids = items.map((e) => e.id).toSet();
          if (lastIds != null &&
              ids.length == lastIds!.length &&
              ids.containsAll(lastIds!)) {
            return false; // result unchanged — suppress the emit
          }
          lastIds = ids;
          return true;
        });
  }

  Future<void> expireAllOpenSignalsForTrial(int trialId, {String? note}) async {
    final unresolved = await getUnresolvedSignalsBeforeExport(trialId);
    for (final s in unresolved) {
      await expireSignal(s.id, note: note);
    }
  }

  /// Used by [TimingWindowViolationWriter] — finds an existing open/deferred/
  /// investigating violation for the exact (session, plot, seType) triple.
  Future<Signal?> findOpenTimingWindowViolationForPlotSession({
    required int sessionId,
    required int plotId,
    required String seType,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.plotId.equals(plotId))
          ..where(
              (s) => s.signalType.equals(SignalType.causalContextFlag.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(s, (ctx) => ctx.seType == seType))
        .firstOrNull;
  }

  /// Used by [ScaleViolationWriter] — finds an existing open/deferred/
  /// investigating violation for the exact (session, plot, seType) triple.
  ///
  /// seType is stored in referenceContext JSON and must match exactly so that
  /// two different assessments on the same plot each get their own signal.
  Future<Signal?> findOpenScaleViolationForPlotSession({
    required int sessionId,
    required int plotId,
    required String seType,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.plotId.equals(plotId))
          ..where((s) => s.signalType.equals(SignalType.scaleViolation.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(s, (ctx) => ctx.seType == seType))
        .firstOrNull;
  }

  /// Used by [AovErrorVarianceWriter] — finds an existing open/deferred/
  /// investigating signal for the given session + assessment column
  /// (matched by seType in context).
  Future<Signal?> findOpenAovSignalForSessionAssessmentTreatment({
    required int sessionId,
    required String seType,
    required int treatmentId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where(
              (s) => s.signalType.equals(SignalType.aovPrediction.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(
            s, (ctx) => ctx.seType == seType && ctx.treatmentId == treatmentId))
        .firstOrNull;
  }

  /// Used by [ReplicationWarningWriter] — finds an existing open/deferred/
  /// investigating signal for the given session + treatment.
  Future<Signal?> findOpenReplicationWarningForSessionTreatment({
    required int sessionId,
    required int treatmentId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) =>
              s.signalType.equals(SignalType.replicationWarning.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(s, (ctx) => ctx.treatmentId == treatmentId))
        .firstOrNull;
  }

  /// Used by [CheckVariabilityWriter] — finds an existing open/deferred/
  /// investigating signal for the given session + assessment column
  /// (matched by seType in context) + treatmentId.
  Future<Signal?> findOpenCheckVariabilitySignalForSessionAssessmentTreatment({
    required int sessionId,
    required String seType,
    required int treatmentId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.signalType
              .equals(SignalType.checkBaselineVariability.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(
            s, (ctx) => ctx.seType == seType && ctx.treatmentId == treatmentId))
        .firstOrNull;
  }

  /// Used by [EmptyApplicationWriter] — finds an existing open/deferred/
  /// investigating signal for the given trial + application event id
  /// (matched by seType == applicationEventId in context).
  Future<Signal?> findOpenEmptyApplicationSignalForEvent({
    required int trialId,
    required String applicationEventId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.trialId.equals(trialId))
          ..where((s) =>
              s.signalType.equals(SignalType.emptyApplication.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where((s) => _ctxMatches(s, (ctx) => ctx.seType == applicationEventId))
        .firstOrNull;
  }

  /// Used by [RaterDriftWriter] — session-level attribution consistency;
  /// [SignalReferenceContext.seType] discriminator is `'session_attribution'`.
  Future<Signal?> findOpenRaterDriftSessionAttribution({
    required int sessionId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.signalType.equals(SignalType.raterDrift.dbValue))
          ..where((s) => s.status.isIn(_openStatuses.toList())))
        .get();
    return rows
        .where(
            (s) => _ctxMatches(s, (ctx) => ctx.seType == 'session_attribution'))
        .firstOrNull;
  }
}
