import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import 'integrity_check_result.dart';

/// Read-only integrity checks. No data is modified.
class IntegrityCheckRepository {
  final AppDatabase _db;
  IntegrityCheckRepository(this._db);

  Future<List<IntegrityIssue>> runChecks() async {
    final issues = <IntegrityIssue>[];

    // Sessions without created_by_user_id (legacy data)
    final sessionsWithoutUser = await (_db.select(_db.sessions)
          ..where((s) => s.createdByUserId.isNull()))
        .get();
    if (sessionsWithoutUser.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'sessions_without_creator',
        summary: 'Sessions without user attribution',
        count: sessionsWithoutUser.length,
        detail: 'Legacy sessions created before user context was added.',
        severity: IntegritySeverity.informational,
      ));
    }

    // Plots with no treatment assigned
    final plotsWithoutTreatment = await (_db.select(_db.plots)
          ..where((p) => p.treatmentId.isNull()))
        .get();
    if (plotsWithoutTreatment.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'plots_without_treatment',
        summary: 'Plots without treatment assignment',
        count: plotsWithoutTreatment.length,
        detail: 'Plots that have no treatment linked.',
        severity: IntegritySeverity.warning,
      ));
    }

    // Closed sessions with zero current ratings
    final closedSessions = await (_db.select(_db.sessions)
          ..where((s) => s.endedAt.isNotNull()))
        .get();
    int closedWithZeroRatings = 0;
    final countExpr = _db.ratingRecords.id.count();
    for (final session in closedSessions) {
      final row = await (_db.selectOnly(_db.ratingRecords)
            ..addColumns([countExpr])
            ..where(_db.ratingRecords.sessionId.equals(session.id) &
                _db.ratingRecords.isCurrent.equals(true)))
          .getSingle();
      final count = row.read(countExpr) ?? 0;
      if (count == 0) closedWithZeroRatings++;
    }
    if (closedWithZeroRatings > 0) {
      issues.add(IntegrityIssue(
        code: 'closed_sessions_no_ratings',
        summary: 'Closed sessions with no ratings',
        count: closedWithZeroRatings,
        detail: 'Informational: session was closed but has no rating records.',
        severity: IntegritySeverity.informational,
      ));
    }

    // Corrections missing reason (data quality)
    final correctionsNoReason = await (_db.select(_db.ratingCorrections)
          ..where((c) => c.reason.equals('')))
        .get();
    if (correctionsNoReason.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'corrections_missing_reason',
        summary: 'Corrections with empty reason',
        count: correctionsNoReason.length,
        detail: 'Correction records should have a non-empty reason.',
        severity: IntegritySeverity.error,
      ));
    }

    // Corrections missing corrected_by_user_id
    final correctionsNoUser = await (_db.select(_db.ratingCorrections)
          ..where((c) => c.correctedByUserId.isNull()))
        .get();
    if (correctionsNoUser.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'corrections_missing_corrected_by',
        summary: 'Corrections without user attribution',
        count: correctionsNoUser.length,
        detail: 'Correction records should have corrected_by_user_id set.',
        severity: IntegritySeverity.warning,
      ));
    }

    // Ratings missing provenance (created_app_version) — informational for post-migration
    final ratingsNoProvenance = await (_db.select(_db.ratingRecords)
          ..where((r) => r.createdAppVersion.isNull()))
        .get();
    if (ratingsNoProvenance.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'ratings_missing_provenance',
        summary: 'Ratings without app version (legacy or pre-migration)',
        count: ratingsNoProvenance.length,
        detail: 'Records created before provenance capture; no action required.',
        severity: IntegritySeverity.informational,
      ));
    }

    // Trials with no plots (protocol incomplete)
    final trials = await _db.select(_db.trials).get();
    int trialsWithNoPlots = 0;
    final plotCountExpr = _db.plots.id.count();
    for (final trial in trials) {
      final row = await (_db.selectOnly(_db.plots)
            ..addColumns([plotCountExpr])
            ..where(_db.plots.trialId.equals(trial.id)))
          .getSingle();
      final n = row.read(plotCountExpr) ?? 0;
      if (n == 0) trialsWithNoPlots++;
    }
    if (trialsWithNoPlots > 0) {
      issues.add(IntegrityIssue(
        code: 'trials_with_no_plots',
        summary: 'Trials with no plots',
        count: trialsWithNoPlots,
        detail: 'Trial has no plot structure yet; add or import plots.',
        severity: IntegritySeverity.informational,
      ));
    }

    return issues;
  }
}
