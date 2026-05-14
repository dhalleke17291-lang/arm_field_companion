import 'package:intl/intl.dart';

import '../../../core/application_state.dart';
import '../../../core/database/app_database.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `emptyApplication` signals when a trial application event exists but
/// has zero [ApplicationPlotAssignments] rows — meaning the event was recorded
/// but no plot received treatment.
///
/// Trial-scoped: runs once per trial at session close. [sessionId] is null on
/// every raised signal because the problem belongs to the trial record, not a
/// specific session.
///
/// Fires at moment 3 (session close, still on site).
class EmptyApplicationWriter {
  EmptyApplicationWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  /// Check all application events for [trialId] and raise a signal for each
  /// one that has zero plot assignments.
  ///
  /// Skips events with status `'cancelled'` — those have been explicitly
  /// voided and should not surface as data-integrity signals.
  ///
  /// Dedup key: (applicationEventId stored as seType, signalType=emptyApplication).
  /// A second call for the same empty event returns the existing signal id
  /// without inserting a new row.
  Future<List<int>> checkAndRaiseForTrial({
    required int trialId,
    int? raisedBy,
  }) async {
    // ── Count total trial plots (for consequence text) ────────────────────────
    final allPlots = await (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId))
          ..where((p) => p.isDeleted.equals(false))
          ..where((p) => p.isGuardRow.equals(false))
          ..where((p) => p.excludeFromAnalysis.equals(false)))
        .get();
    final trialPlotCount = allPlots.length;

    // ── Load all non-cancelled application events for this trial ──────────────
    final events = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..where((e) => e.status.isNotValue(kAppStatusCancelled)))
        .get();

    if (events.isEmpty) return [];

    final raised = <int>[];

    for (final event in events) {
      // Count plot assignments for this event.
      final assignments = await (_db.select(_db.applicationPlotAssignments)
            ..where((a) => a.applicationEventId.equals(event.id)))
          .get();

      if (assignments.isNotEmpty) continue; // has plots — nothing to flag

      // ── Dedup: match (seType=event.id, signalType=emptyApplication) ──────────
      final existing =
          await _signals.findOpenEmptyApplicationSignalForEvent(
        trialId: trialId,
        applicationEventId: event.id,
      );
      if (existing != null) {
        raised.add(existing.id);
        continue;
      }

      // ── Build consequence text ─────────────────────────────────────────────
      final dateStr =
          DateFormat('d MMM yyyy').format(event.applicationDate);
      final plotWord = trialPlotCount == 1 ? 'plot' : 'plots';
      final consequenceText =
          'Application on $dateStr has 0 of $trialPlotCount $plotWord assigned. '
          'The application event exists but no plot received treatment. '
          'Either the assignment was lost or the event should be deleted.';

      final id = await _signals.raiseSignal(
        trialId: trialId,
        sessionId: null,
        plotId: null,
        signalType: SignalType.emptyApplication,
        moment: SignalMoment.three,
        severity: SignalSeverity.critical,
        referenceContext: SignalReferenceContext(
          seType: event.id,
          reliabilityTier: 'HIGH',
        ),
        consequenceText: consequenceText,
        raisedBy: raisedBy,
      );
      raised.add(id);
    }

    return raised;
  }
}
