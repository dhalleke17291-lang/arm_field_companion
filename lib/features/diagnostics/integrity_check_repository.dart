import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import 'integrity_check_result.dart';

/// Read-only integrity checks. No data is modified.
class IntegrityCheckRepository {
  final AppDatabase _db;
  IntegrityCheckRepository(this._db);

  Future<List<IntegrityIssue>> runChecks() async {
    final issues = <IntegrityIssue>[];

    // Sessions without created_by_user_id (legacy data); live sessions only.
    final sessionsWithoutUser = await (_db.select(_db.sessions)
          ..where((s) =>
              s.createdByUserId.isNull() & s.isDeleted.equals(false)))
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

    // Plots with no treatment assigned (Assignment-first, then Plot fallback).
    // Live plots only; assignments table has no soft-delete flag.
    final assignmentRows = await _db.select(_db.assignments).get();
    final plotIdToTreatmentId = {
      for (var a in assignmentRows) a.plotId: a.treatmentId
    };
    final allPlots = await (_db.select(_db.plots)
          ..where((p) => p.isDeleted.equals(false)))
        .get();
    final plotsWithoutTreatment = allPlots
        .where((p) => (plotIdToTreatmentId[p.id] ?? p.treatmentId) == null)
        .toList();
    if (plotsWithoutTreatment.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'plots_without_treatment',
        summary: 'Plots without treatment assignment',
        count: plotsWithoutTreatment.length,
        detail: 'Plots that have no treatment linked (Assignment or Plot).',
        severity: IntegritySeverity.warning,
      ));
    }

    // Closed sessions with zero current ratings (live sessions and ratings).
    final closedSessions = await (_db.select(_db.sessions)
          ..where(
              (s) => s.endedAt.isNotNull() & s.isDeleted.equals(false)))
        .get();
    int closedWithZeroRatings = 0;
    final countExpr = _db.ratingRecords.id.count();
    for (final session in closedSessions) {
      final row = await (_db.selectOnly(_db.ratingRecords)
            ..addColumns([countExpr])
            ..where(_db.ratingRecords.sessionId.equals(session.id) &
                _db.ratingRecords.isCurrent.equals(true) &
                _db.ratingRecords.isDeleted.equals(false)))
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

    // Ratings missing provenance (created_app_version) — live rows only.
    final ratingsNoProvenance = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.createdAppVersion.isNull() & r.isDeleted.equals(false)))
        .get();
    if (ratingsNoProvenance.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'ratings_missing_provenance',
        summary: 'Ratings without app version (legacy or pre-migration)',
        count: ratingsNoProvenance.length,
        detail:
            'Records created before provenance capture; no action required.',
        severity: IntegritySeverity.informational,
      ));
    }

    // Trials with no live plots (protocol incomplete); non-deleted trials only.
    final trials = await (_db.select(_db.trials)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    int trialsWithNoPlots = 0;
    final plotCountExpr = _db.plots.id.count();
    for (final trial in trials) {
      final row = await (_db.selectOnly(_db.plots)
            ..addColumns([plotCountExpr])
            ..where(_db.plots.trialId.equals(trial.id) &
                _db.plots.isDeleted.equals(false)))
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

    // Multiple is_current rows for the same logical key (trial, plot, assessment, session, sub-unit).
    final duplicateCurrentRows = await _db
        .customSelect(
          '''
SELECT trial_id, plot_pk, assessment_id, session_id,
       COALESCE(sub_unit_id, -1) AS sub_unit_key,
       COUNT(*) AS cnt
FROM rating_records
WHERE is_current = 1 AND is_deleted = 0
GROUP BY trial_id, plot_pk, assessment_id, session_id, COALESCE(sub_unit_id, -1)
HAVING COUNT(*) > 1
''',
          readsFrom: {_db.ratingRecords},
        )
        .get();
    if (duplicateCurrentRows.isNotEmpty) {
      final plotPks = duplicateCurrentRows
          .map((row) => row.read<int>('plot_pk'))
          .toSet()
          .toList()
        ..sort();
      final detail = StringBuffer()
        ..write(
          'Duplicate current rating rows for the same plot/assessment/session/sub-unit key. ',
        )
        ..write('Affected plot_pk values: ${plotPks.join(", ")}. ');
      for (final row in duplicateCurrentRows) {
        detail.write(
          '[trial=${row.read<int>("trial_id")} plot_pk=${row.read<int>("plot_pk")} '
          'assessment=${row.read<int>("assessment_id")} session=${row.read<int>("session_id")} '
          'sub_unit_key=${row.read<int>("sub_unit_key")} count=${row.read<int>("cnt")}] ',
        );
      }
      issues.add(IntegrityIssue(
        code: 'duplicate_current_ratings',
        summary: 'Duplicate current rating rows',
        count: duplicateCurrentRows.length,
        detail: detail.toString().trimRight(),
        severity: IntegritySeverity.error,
        isRepairable: true,
      ));
    }

    // Duplicate session_assessments rows (same session + assessment link).
    final duplicateSessionAssessmentGroups = await _db
        .customSelect(
          '''
SELECT session_id, assessment_id, COUNT(*) AS cnt
FROM session_assessments
GROUP BY session_id, assessment_id
HAVING COUNT(*) > 1
''',
          readsFrom: {_db.sessionAssessments},
        )
        .get();
    if (duplicateSessionAssessmentGroups.isNotEmpty) {
      final sessionIds = duplicateSessionAssessmentGroups
          .map((row) => row.read<int>('session_id'))
          .toSet()
          .toList()
        ..sort();
      final assessmentIds = duplicateSessionAssessmentGroups
          .map((row) => row.read<int>('assessment_id'))
          .toSet()
          .toList()
        ..sort();
      final detail = StringBuffer()
        ..write(
          'More than one session_assessments row for the same session_id and assessment_id. ',
        )
        ..write('Affected session_id values: ${sessionIds.join(", ")}. ')
        ..write('Affected assessment_id values: ${assessmentIds.join(", ")}. ');
      for (final row in duplicateSessionAssessmentGroups) {
        detail.write(
          '[session=${row.read<int>("session_id")} '
          'assessment=${row.read<int>("assessment_id")} count=${row.read<int>("cnt")}] ',
        );
      }
      issues.add(IntegrityIssue(
        code: 'duplicate_session_assessments',
        summary: 'Duplicate session assessment links',
        count: duplicateSessionAssessmentGroups.length,
        detail: detail.toString().trimRight(),
        severity: IntegritySeverity.error,
      ));
    }

    return issues;
  }

  Future<List<IntegrityIssue>> runChecksForTrial(int trialId) async {
    final issues = <IntegrityIssue>[];

    // 1. sessions_without_creator — ended sessions missing user attribution.
    final sessionsWithoutCreator = await (_db.select(_db.sessions)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.isDeleted.equals(false) &
              s.endedAt.isNotNull() &
              s.createdByUserId.isNull()))
        .get();
    if (sessionsWithoutCreator.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'sessions_without_creator',
        summary: 'Sessions without user attribution',
        count: sessionsWithoutCreator.length,
        detail: 'Legacy sessions created before user context was added.',
        severity: IntegritySeverity.informational,
      ));
    }

    // 2. plots_without_treatment
    final trialPlots = await (_db.select(_db.plots)
          ..where(
              (p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get();
    if (trialPlots.isNotEmpty) {
      final plotIds = trialPlots.map((p) => p.id).toList();
      final assignmentRows = await (_db.select(_db.assignments)
            ..where((a) => a.plotId.isIn(plotIds)))
          .get();
      final plotIdToTreatmentId = {
        for (var a in assignmentRows) a.plotId: a.treatmentId
      };
      final plotsWithoutTreatment = trialPlots
          .where((p) => (plotIdToTreatmentId[p.id] ?? p.treatmentId) == null)
          .toList();
      if (plotsWithoutTreatment.isNotEmpty) {
        issues.add(IntegrityIssue(
          code: 'plots_without_treatment',
          summary: 'Plots without treatment assignment',
          count: plotsWithoutTreatment.length,
          detail: 'Plots that have no treatment linked (Assignment or Plot).',
          severity: IntegritySeverity.warning,
        ));
      }
    }

    // 3. closed_sessions_no_ratings
    final closedSessions = await (_db.select(_db.sessions)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.endedAt.isNotNull() &
              s.isDeleted.equals(false)))
        .get();
    int closedWithZeroRatings = 0;
    final countExpr = _db.ratingRecords.id.count();
    for (final session in closedSessions) {
      final row = await (_db.selectOnly(_db.ratingRecords)
            ..addColumns([countExpr])
            ..where(_db.ratingRecords.sessionId.equals(session.id) &
                _db.ratingRecords.isCurrent.equals(true) &
                _db.ratingRecords.isDeleted.equals(false)))
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

    // 4. corrections_missing_reason
    final correctionsNoReason = await _db.customSelect(
      '''
SELECT rc.id
FROM rating_corrections rc
JOIN rating_records rr ON rr.id = rc.rating_id
WHERE rr.trial_id = ? AND rc.reason = ''
''',
      variables: [Variable.withInt(trialId)],
      readsFrom: {_db.ratingCorrections, _db.ratingRecords},
    ).get();
    if (correctionsNoReason.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'corrections_missing_reason',
        summary: 'Corrections with empty reason',
        count: correctionsNoReason.length,
        detail: 'Correction records should have a non-empty reason.',
        severity: IntegritySeverity.error,
      ));
    }

    // 5. corrections_missing_corrected_by
    final correctionsNoUser = await _db.customSelect(
      '''
SELECT rc.id
FROM rating_corrections rc
JOIN rating_records rr ON rr.id = rc.rating_id
WHERE rr.trial_id = ? AND rc.corrected_by_user_id IS NULL
''',
      variables: [Variable.withInt(trialId)],
      readsFrom: {_db.ratingCorrections, _db.ratingRecords},
    ).get();
    if (correctionsNoUser.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'corrections_missing_corrected_by',
        summary: 'Corrections without user attribution',
        count: correctionsNoUser.length,
        detail: 'Correction records should have corrected_by_user_id set.',
        severity: IntegritySeverity.warning,
      ));
    }

    // 6. ratings_missing_provenance — live current rows only.
    final ratingsNoProvenance = await (_db.select(_db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.isDeleted.equals(false) &
              r.isCurrent.equals(true) &
              r.createdAppVersion.isNull()))
        .get();
    if (ratingsNoProvenance.isNotEmpty) {
      issues.add(IntegrityIssue(
        code: 'ratings_missing_provenance',
        summary: 'Ratings without app version (legacy or pre-migration)',
        count: ratingsNoProvenance.length,
        detail:
            'Records created before provenance capture; no action required.',
        severity: IntegritySeverity.informational,
      ));
    }

    // 7. trials_with_no_plots — returns 1 issue if this trial has zero live plots.
    final plotCountExpr = _db.plots.id.count();
    final plotCountRow = await (_db.selectOnly(_db.plots)
          ..addColumns([plotCountExpr])
          ..where(_db.plots.trialId.equals(trialId) &
              _db.plots.isDeleted.equals(false)))
        .getSingle();
    final plotCount = plotCountRow.read(plotCountExpr) ?? 0;
    if (plotCount == 0) {
      issues.add(const IntegrityIssue(
        code: 'trials_with_no_plots',
        summary: 'Trial has no plots',
        count: 1,
        detail: 'Trial has no plot structure yet; add or import plots.',
        severity: IntegritySeverity.informational,
      ));
    }

    // 8. duplicate_current_ratings
    final duplicateCurrentRows = await _db.customSelect(
      '''
SELECT trial_id, plot_pk, assessment_id, session_id,
       COALESCE(sub_unit_id, -1) AS sub_unit_key,
       COUNT(*) AS cnt
FROM rating_records
WHERE trial_id = ? AND is_current = 1 AND is_deleted = 0
GROUP BY trial_id, plot_pk, assessment_id, session_id, COALESCE(sub_unit_id, -1)
HAVING COUNT(*) > 1
''',
      variables: [Variable.withInt(trialId)],
      readsFrom: {_db.ratingRecords},
    ).get();
    if (duplicateCurrentRows.isNotEmpty) {
      final plotPks = duplicateCurrentRows
          .map((row) => row.read<int>('plot_pk'))
          .toSet()
          .toList()
        ..sort();
      final detail = StringBuffer()
        ..write(
          'Duplicate current rating rows for the same plot/assessment/session/sub-unit key. ',
        )
        ..write('Affected plot_pk values: ${plotPks.join(", ")}. ');
      for (final row in duplicateCurrentRows) {
        detail.write(
          '[trial=${row.read<int>("trial_id")} plot_pk=${row.read<int>("plot_pk")} '
          'assessment=${row.read<int>("assessment_id")} session=${row.read<int>("session_id")} '
          'sub_unit_key=${row.read<int>("sub_unit_key")} count=${row.read<int>("cnt")}] ',
        );
      }
      issues.add(IntegrityIssue(
        code: 'duplicate_current_ratings',
        summary: 'Duplicate current rating rows',
        count: duplicateCurrentRows.length,
        detail: detail.toString().trimRight(),
        severity: IntegritySeverity.error,
        isRepairable: true,
      ));
    }

    // 9. duplicate_session_assessments
    final duplicateSaGroups = await _db.customSelect(
      '''
SELECT sa.session_id, sa.assessment_id, COUNT(*) AS cnt
FROM session_assessments sa
JOIN sessions s ON s.id = sa.session_id
WHERE s.trial_id = ? AND s.is_deleted = 0
GROUP BY sa.session_id, sa.assessment_id
HAVING COUNT(*) > 1
''',
      variables: [Variable.withInt(trialId)],
      readsFrom: {_db.sessionAssessments, _db.sessions},
    ).get();
    if (duplicateSaGroups.isNotEmpty) {
      final sessionIds = duplicateSaGroups
          .map((row) => row.read<int>('session_id'))
          .toSet()
          .toList()
        ..sort();
      final assessmentIds = duplicateSaGroups
          .map((row) => row.read<int>('assessment_id'))
          .toSet()
          .toList()
        ..sort();
      final detail = StringBuffer()
        ..write(
          'More than one session_assessments row for the same session_id and assessment_id. ',
        )
        ..write('Affected session_id values: ${sessionIds.join(", ")}. ')
        ..write(
            'Affected assessment_id values: ${assessmentIds.join(", ")}. ');
      for (final row in duplicateSaGroups) {
        detail.write(
          '[session=${row.read<int>("session_id")} '
          'assessment=${row.read<int>("assessment_id")} count=${row.read<int>("cnt")}] ',
        );
      }
      issues.add(IntegrityIssue(
        code: 'duplicate_session_assessments',
        summary: 'Duplicate session assessment links',
        count: duplicateSaGroups.length,
        detail: detail.toString().trimRight(),
        severity: IntegritySeverity.error,
      ));
    }

    return issues;
  }
}
