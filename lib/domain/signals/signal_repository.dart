import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
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

  static const Set<String> _openStatuses = {
    'open',
    'deferred',
    'investigating',
  };

  static const Set<String> _terminalStatuses = {
    'resolved',
    'expired',
    'suppressed',
  };

  static int _severityRank(String severity) => switch (severity) {
        'critical' => 0,
        'review' => 1,
        'info' => 2,
        _ => 99,
      };

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

  Future<List<SignalDecisionEvent>> getDecisionHistory(int signalId) async {
    return (_db.select(_db.signalDecisionEvents)
          ..where((e) => e.signalId.equals(signalId))
          ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
        .get();
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

  Future<void> expireAllOpenSignalsForTrial(int trialId, {String? note}) async {
    final unresolved = await getUnresolvedSignalsBeforeExport(trialId);
    for (final s in unresolved) {
      await expireSignal(s.id, note: note);
    }
  }

  /// Used by [ScaleViolationWriter] — finds an existing open violation.
  Future<Signal?> findOpenScaleViolationForPlotSession({
    required int sessionId,
    required int plotId,
  }) async {
    return (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) => s.plotId.equals(plotId))
          ..where((s) => s.signalType.equals(SignalType.scaleViolation.dbValue))
          ..where((s) => s.status.equals(SignalStatus.open.dbValue)))
        .getSingleOrNull();
  }

  /// Used by [AovErrorVarianceWriter] — finds an existing open/deferred signal
  /// for the given session + assessment column (matched by seType in context).
  Future<Signal?> findOpenAovSignalForSessionAssessmentTreatment({
    required int sessionId,
    required String seType,
    required int treatmentId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where(
              (s) => s.signalType.equals(SignalType.aovPrediction.dbValue))
          ..where((s) =>
              s.status.isIn([SignalStatus.open.dbValue, SignalStatus.deferred.dbValue])))
        .get();
    return rows.where((s) {
      try {
        final ctx = SignalReferenceContext.decodeJson(s.referenceContext);
        return ctx.seType == seType && ctx.treatmentId == treatmentId;
      } catch (_) {
        return false;
      }
    }).firstOrNull;
  }

  /// Used by [ReplicationWarningWriter] — finds an existing open/deferred
  /// signal for the given session + treatment.
  Future<Signal?> findOpenReplicationWarningForSessionTreatment({
    required int sessionId,
    required int treatmentId,
  }) async {
    final rows = await (_db.select(_db.signals)
          ..where((s) => s.sessionId.equals(sessionId))
          ..where((s) =>
              s.signalType.equals(SignalType.replicationWarning.dbValue))
          ..where((s) =>
              s.status.isIn([SignalStatus.open.dbValue, SignalStatus.deferred.dbValue])))
        .get();
    return rows.where((s) {
      try {
        final ctx = SignalReferenceContext.decodeJson(s.referenceContext);
        return ctx.treatmentId == treatmentId;
      } catch (_) {
        return false;
      }
    }).firstOrNull;
  }
}
