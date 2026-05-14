import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/ui/assessment_display_helper.dart';
import '../../../core/utils/check_treatment_helper.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../features/plots/utils/plot_analysis_utils.dart';
import '../signal_models.dart';
import '../signal_repository.dart';

/// Raises `checkBaselineVariability` signals when the untreated check treatment
/// has a CV > 50 % across replicates for an assessment in a session.
///
/// Fires at moment 3 (session close, still on site).
class CheckVariabilityWriter {
  CheckVariabilityWriter(this._db, this._signals);

  final AppDatabase _db;
  final SignalRepository _signals;

  /// CV threshold above which a signal is raised.
  static const double _cvThreshold = 0.50; // review after first pilot data

  /// Scans all previously-closed sessions for [trialId] plus [currentSessionId]
  /// (which may not yet be marked closed at the time this runs).
  /// Dedup in [checkAndRaiseForSession] prevents duplicate signals when a
  /// prior session-close already raised a signal for an older session.
  Future<List<int>> checkAndRaiseForAllClosedSessionsAndCurrent({
    required int trialId,
    required int currentSessionId,
    int? raisedBy,
  }) async {
    // If there is no check treatment in this trial, skip entirely.
    final allTreatments = await (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId)))
        .get();
    final checkTreatments =
        allTreatments.where(isCheckTreatment).toList();
    if (checkTreatments.isEmpty) return const [];

    final closedSessions = await (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId))
          ..where((s) => s.endedAt.isNotNull()))
        .get();

    final sessionIds = {
      ...closedSessions.map((s) => s.id),
      currentSessionId,
    };

    final raised = <int>[];
    for (final sid in sessionIds) {
      final ids = await checkAndRaiseForSession(
        trialId: trialId,
        sessionId: sid,
        checkTreatments: checkTreatments,
        raisedBy: raisedBy,
      );
      raised.addAll(ids);
    }
    return raised;
  }

  Future<List<int>> checkAndRaiseForSession({
    required int trialId,
    required int sessionId,
    List<Treatment>? checkTreatments,
    int? raisedBy,
  }) async {
    // Resolve check treatments if not already supplied.
    final checks = checkTreatments ??
        (await (_db.select(_db.treatments)
                  ..where((t) => t.trialId.equals(trialId)))
                .get())
            .where(isCheckTreatment)
            .toList();
    if (checks.isEmpty) return const [];

    final session = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    final sessionLabel = _formatSessionLabel(session);

    final sessionAssessments = await (_db.select(_db.sessionAssessments)
          ..where((sa) => sa.sessionId.equals(sessionId)))
        .get();

    final raised = <int>[];
    final taRepo = TrialAssessmentRepository(_db);

    for (final sa in sessionAssessments) {
      final displayCtx =
          await taRepo.displayContextForLegacyAssessmentId(sa.assessmentId);
      final String seName;
      if (displayCtx != null) {
        seName = AssessmentDisplayHelper.compactName(
            displayCtx.ta, def: displayCtx.def);
      } else {
        final assessment = await (_db.select(_db.assessments)
              ..where((a) => a.id.equals(sa.assessmentId)))
            .getSingleOrNull();
        seName = assessment?.name ?? 'Assessment ${sa.assessmentId}';
      }

      for (final checkTreatment in checks) {
        // Build plot-pk → treatmentId map for check plots only.
        final checkPlotIds = (await (_db.select(_db.plots)
                  ..where((p) => p.trialId.equals(trialId))
                  ..where((p) => p.treatmentId.equals(checkTreatment.id)))
                .get())
            .map((p) => p.id)
            .toSet();

        if (checkPlotIds.isEmpty) continue;

        // Also capture plots assigned via the assignments table.
        final assignedPks = (await (_db.select(_db.assignments)
                  ..where((a) => a.treatmentId.equals(checkTreatment.id))
                  ..where((a) => a.plotId.isIn(checkPlotIds.toList())))
                .get())
            .map((a) => a.plotId)
            .toSet();
        final allCheckPks = {...checkPlotIds, ...assignedPks};

        // Ratings for check plots in this session + assessment.
        final ratings = await (_db.select(_db.ratingRecords)
              ..where((r) => r.sessionId.equals(sessionId))
              ..where((r) => r.assessmentId.equals(sa.assessmentId))
              ..where((r) => r.plotPk.isIn(allCheckPks.toList()))
              ..where((r) => r.isCurrent.equals(true))
              ..where((r) => r.isDeleted.equals(false))
              ..where((r) => r.numericValue.isNotNull()))
            .get();

        if (ratings.length < 2) continue;

        final values = ratings.map((r) => r.numericValue!).toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        if (mean == 0) continue; // CV undefined when mean is zero

        final sd = computeSD(values);
        final cv = sd / mean;

        if (cv <= _cvThreshold) continue;

        // Dedup: skip if an open/deferred signal already exists for this
        // (session, assessment column, check treatment).
        final seKey = sa.assessmentId.toString();
        final existing = await _signals
            .findOpenCheckVariabilitySignalForSessionAssessmentTreatment(
          sessionId: sessionId,
          seType: seKey,
          treatmentId: checkTreatment.id,
        );
        if (existing != null) {
          raised.add(existing.id);
          continue;
        }

        final cvPct = (cv * 100).toStringAsFixed(1);
        final replicateCount = ratings.length;

        final id = await _signals.raiseSignal(
          trialId: trialId,
          sessionId: sessionId,
          plotId: null,
          signalType: SignalType.checkBaselineVariability,
          moment: SignalMoment.three,
          severity: SignalSeverity.review,
          referenceContext: SignalReferenceContext(
            seType: seKey,
            treatmentId: checkTreatment.id,
            reliabilityTier: 'MEDIUM',
          ),
          consequenceText: 'In $sessionLabel, ${checkTreatment.name} has '
              'CV=$cvPct% across $replicateCount replicates for $seName. '
              'Check baseline is unreliable; results comparing other treatments '
              'to it may not be trustworthy.',
          raisedBy: raisedBy,
        );
        raised.add(id);
      }
    }

    return raised;
  }

  String _formatSessionLabel(Session? session) {
    if (session == null) return 'this session';
    final parsed = DateTime.tryParse(session.sessionDateLocal);
    final dateStr = parsed != null
        ? DateFormat('d MMM yyyy').format(parsed)
        : session.sessionDateLocal;
    return '${session.name} ($dateStr)';
  }
}
