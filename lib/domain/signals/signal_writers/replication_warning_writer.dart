import '../../../core/database/app_database.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `replicationWarning` signals when a treatment has fewer than
/// three rated plots in a session.
///
/// Fires at moment 3 (session close, still on site).
class ReplicationWarningWriter {
  ReplicationWarningWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  Future<List<int>> checkAndRaiseForSession({
    required int trialId,
    required int sessionId,
    int? raisedBy,
  }) async {
    // All non-deleted treatments for this trial.
    final treatments = await (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId))
          ..where((t) => t.isDeleted.equals(false)))
        .get();

    if (treatments.isEmpty) return [];

    // All plots for this trial with a treatment assignment.
    final allPlots = await (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId))
          ..where((p) => p.isDeleted.equals(false))
          ..where((p) => p.isGuardRow.equals(false))
          ..where((p) => p.excludeFromAnalysis.equals(false)))
        .get();

    // Rated plot PKs in this session (current, non-deleted, any assessment).
    final ratedRows = await (_db.select(_db.ratingRecords)
          ..where((r) => r.sessionId.equals(sessionId))
          ..where((r) => r.isCurrent.equals(true))
          ..where((r) => r.isDeleted.equals(false)))
        .get();
    final ratedPlotPks = ratedRows.map((r) => r.plotPk).toSet();
    if (ratedPlotPks.isEmpty) return [];

    // Build assignments-first treatment map (ARM) with plots.treatmentId fallback.
    final asgn = await (_db.select(_db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .get();
    final plotToTreatment = <int, int>{};
    for (final a in asgn) {
      if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
    }
    for (final p in allPlots) {
      if (!plotToTreatment.containsKey(p.id) && p.treatmentId != null) {
        plotToTreatment[p.id] = p.treatmentId!;
      }
    }

    // Treatment → set of rated plot PKs.
    final ratedByTreatment = <int, Set<int>>{};
    for (final plot in allPlots) {
      final tId = plotToTreatment[plot.id];
      if (tId == null) continue;
      if (!ratedPlotPks.contains(plot.id)) continue;
      ratedByTreatment.putIfAbsent(tId, () => {}).add(plot.id);
    }

    final raised = <int>[];

    for (final treatment in treatments) {
      final count = ratedByTreatment[treatment.id]?.length ?? 0;
      if (count == 0) continue; // treatment not yet touched this session
      if (count >= 3) continue;

      // Dedup: skip if an open/deferred signal already exists for this
      // (session, treatment).
      final existing =
          await _signals.findOpenReplicationWarningForSessionTreatment(
        sessionId: sessionId,
        treatmentId: treatment.id,
      );
      if (existing != null) {
        raised.add(existing.id);
        continue;
      }

      final severity = count < 2 ? SignalSeverity.critical : SignalSeverity.review;
      final plotWord = count == 1 ? 'plot' : 'plots';

      final id = await _signals.raiseSignal(
        trialId: trialId,
        sessionId: sessionId,
        plotId: null,
        signalType: SignalType.replicationWarning,
        moment: SignalMoment.three,
        severity: severity,
        referenceContext: SignalReferenceContext(
          treatmentId: treatment.id,
          reliabilityTier: 'HIGH',
        ),
        consequenceText:
            '${treatment.name} has only $count rated $plotWord this session. '
            'Statistical comparison needs at least 3.',
        raisedBy: raisedBy,
      );
      raised.add(id);
    }

    return raised;
  }
}
