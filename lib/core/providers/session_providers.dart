import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assessment_result_direction.dart';
import '../database/app_database.dart';
import '../plot_analysis_eligibility.dart';
import '../trial_operational_watch_merge.dart';
import '../trial_state.dart';
import '../../domain/evidence/evidence_anchor_repository.dart';
import '../../domain/intelligence/trial_intelligence_service.dart';
import '../../domain/models/trial_insight.dart';
import '../../domain/ratings/rating_integrity_guard.dart';
import '../../domain/signals/signal_providers.dart';
import '../../features/diagnostics/assessment_completion.dart';
import '../../features/plots/usecases/update_plot_assignment_usecase.dart';
import '../../features/ratings/rating_repository.dart';
import '../../features/ratings/usecases/amend_plot_rating_usecase.dart';
import '../../features/ratings/usecases/apply_correction_usecase.dart';
import '../../features/ratings/usecases/rating_lineage_usecase.dart';
import '../../features/ratings/usecases/save_rating_usecase.dart';
import '../../features/ratings/usecases/undo_rating_usecase.dart';
import '../../features/ratings/usecases/void_rating_usecase.dart';
import '../../features/sessions/domain/session_completeness_report.dart';
import '../../features/sessions/session_repository.dart';
import '../../features/sessions/session_timing_helper.dart';
import '../../features/sessions/usecases/close_session_usecase.dart';
import '../../features/sessions/usecases/compute_session_completeness_usecase.dart';
import '../../features/sessions/usecases/create_session_usecase.dart';
import '../../features/sessions/usecases/evaluate_session_close_policy_usecase.dart';
import '../../features/sessions/usecases/start_or_continue_rating_usecase.dart';
import 'infrastructure_providers.dart';
import 'trial_providers.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

/// Latest non-deleted session row by id (e.g. after BBCH update).
final sessionByIdProvider =
    FutureProvider.autoDispose.family<Session?, int>((ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).getSessionById(sessionId);
});

/// DAS/DAT from seeding + applied applications; BBCH from session.
final sessionTimingContextProvider = FutureProvider.autoDispose
    .family<SessionTimingContext, int>((ref, sessionId) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final session = await sessionRepo.getSessionById(sessionId);
  if (session == null) {
    return const SessionTimingContext();
  }
  final seeding = await ref
      .watch(seedingRepositoryProvider)
      .getSeedingEventForTrial(session.trialId);
  final applications = await ref
      .watch(applicationRepositoryProvider)
      .getApplicationsForTrial(session.trialId);
  return buildSessionTimingContext(
    sessionStartedAt: session.startedAt,
    cropStageBbch: session.cropStageBbch,
    seeding: seeding,
    applications: applications,
  );
});

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(databaseProvider));
});

final ratingIntegrityGuardProvider = Provider<RatingIntegrityGuard>((ref) {
  return RatingIntegrityGuard(
    ref.watch(plotRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
  );
});

final saveRatingUseCaseProvider = Provider<SaveRatingUseCase>((ref) {
  return SaveRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final amendPlotRatingUseCaseProvider = Provider<AmendPlotRatingUseCase>((ref) {
  return AmendPlotRatingUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(saveRatingUseCaseProvider),
    ref.watch(ratingRepositoryProvider),
    ref.watch(signalRepositoryProvider),
    ref.watch(databaseProvider),
  );
});

final undoRatingUseCaseProvider = Provider<UndoRatingUseCase>((ref) {
  return UndoRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final applyCorrectionUseCaseProvider = Provider<ApplyCorrectionUseCase>((ref) {
  return ApplyCorrectionUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final voidRatingUseCaseProvider = Provider<VoidRatingUseCase>((ref) {
  return VoidRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final ratingLineageUseCaseProvider = Provider<RatingLineageUseCase>((ref) {
  return RatingLineageUseCase(ref.watch(ratingRepositoryProvider));
});

/// Latest correction for a rating (for effective value display).
final latestCorrectionForRatingProvider =
    FutureProvider.autoDispose.family<RatingCorrection?, int>((ref, ratingId) {
  return ref
      .read(ratingRepositoryProvider)
      .getLatestCorrectionForRating(ratingId);
});

final createSessionUseCaseProvider = Provider<CreateSessionUseCase>((ref) {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final trialRepo = ref.watch(trialRepositoryProvider);
  return CreateSessionUseCase(
    sessionRepo,
    promoteTrialToActiveIfReady: (trialId) async {
      final t = await trialRepo.getTrialById(trialId);
      if (t != null &&
          (t.status == kTrialStatusReady || t.status == kTrialStatusDraft)) {
        await trialRepo.updateTrialStatus(trialId, kTrialStatusActive);
      }
    },
  );
});

final startOrContinueRatingUseCaseProvider =
    Provider<StartOrContinueRatingUseCase>((ref) {
  return StartOrContinueRatingUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
  );
});

/// [ComputeSessionCompletenessUseCase] for [SessionCompletenessReport].
///
/// [SessionCompletenessReport] is the authoritative **scientific / session**
/// completeness source (per session assessment, guard rows excluded, close gating).
final computeSessionCompletenessUseCaseProvider =
    Provider<ComputeSessionCompletenessUseCase>((ref) {
  return ComputeSessionCompletenessUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
  );
});

final evaluateSessionClosePolicyUseCaseProvider =
    Provider<EvaluateSessionClosePolicyUseCase>((ref) {
  return EvaluateSessionClosePolicyUseCase(
    ref.watch(computeSessionCompletenessUseCaseProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(weatherSnapshotRepositoryProvider),
  );
});

final closeSessionUseCaseProvider = Provider<CloseSessionUseCase>((ref) {
  return CloseSessionUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(evaluateSessionClosePolicyUseCaseProvider),
    EvidenceAnchorRepository(ref.watch(databaseProvider)),
  );
});

final updatePlotAssignmentUseCaseProvider =
    Provider<UpdatePlotAssignmentUseCase>((ref) {
  return UpdatePlotAssignmentUseCase(
    ref.watch(databaseProvider),
    ref.watch(assignmentRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

/// Async [SessionCompletenessReport] for one session id.
///
/// Prefer this (or the use case above) for completeness and close readiness.
/// [ratedPlotPksProvider] is **navigation / progress** only (any current rating
/// per plot) and must not be treated as scientific completeness.
final sessionCompletenessReportProvider = FutureProvider.autoDispose
    .family<SessionCompletenessReport, int>((ref, sessionId) async {
  return ref
      .read(computeSessionCompletenessUseCaseProvider)
      .execute(sessionId: sessionId);
});

/// True when this trial has any row in rating_records, photos, or plot_flags.
/// Field notes are intentionally excluded and do not lock assignments.
/// Used for assignment lock: empty sessions do NOT lock. Auto-updates when data changes.
final trialHasSessionDataProvider =
    StreamProvider.autoDispose.family<bool, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchTrialHasSessionData(trialId);
});

/// Soft-deleted sessions across all trials (Recovery). Newest [deletedAt] first.
final deletedSessionsProvider =
    FutureProvider.autoDispose<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).getAllDeletedSessions();
});

/// Soft-deleted sessions for one trial (Recovery trial-scoped).
final deletedSessionsForTrialRecoveryProvider =
    FutureProvider.autoDispose.family<List<Session>, int>((ref, trialId) {
  return ref
      .watch(sessionRepositoryProvider)
      .getDeletedSessionsForTrial(trialId);
});

final openSessionProvider =
    StreamProvider.family<Session?, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchOpenSession(trialId);
});

/// All non-deleted sessions across all trials, most recent first.
final allActiveSessionsProvider =
    FutureProvider.autoDispose<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).getAllActiveSessions();
});

final sessionAssessmentsProvider =
    StreamProvider.family<List<Assessment>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  return (db.select(db.sessionAssessments)
        ..where((sa) => sa.sessionId.equals(sessionId))
        ..orderBy([
          (sa) => drift.OrderingTerm.asc(sa.sortOrder),
          (sa) => drift.OrderingTerm.asc(sa.id),
        ]))
      .watch()
      .asyncMap((_) => sessionRepo.getSessionAssessments(sessionId));
});

final sessionAssessmentRowsProvider =
    StreamProvider.family<List<SessionAssessment>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.sessionAssessments)
        ..where((sa) => sa.sessionId.equals(sessionId))
        ..orderBy([
          (sa) => drift.OrderingTerm.asc(sa.sortOrder),
          (sa) => drift.OrderingTerm.asc(sa.id),
        ]))
      .watch();
});

/// Plot PKs with at least one **current** rating in the session (any assessment).
/// Excludes guard rows ([Plot.isGuardRow]) — same semantics as rating walk order.
///
/// **Navigation / plot-queue progress** only—not [SessionCompletenessReport] /
/// per-assessment completeness. Use [sessionCompletenessReportProvider] for
/// scientific session completeness and close gating.
final ratedPlotPksProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .watch()
      .asyncMap((ratings) async {
    if (ratings.isEmpty) return <int>{};
    final pks = ratings.map((r) => r.plotPk).toSet();
    final plotRows =
        await (db.select(db.plots)..where((p) => p.id.isIn(pks))).get();
    final guardPks =
        plotRows.where((p) => p.isGuardRow).map((p) => p.id).toSet();
    return pks.difference(guardPks);
  });
});

class CurrentRatingParams {
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;
  final int? subUnitId;

  const CurrentRatingParams({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    this.subUnitId,
  });

  @override
  bool operator ==(Object other) =>
      other is CurrentRatingParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk &&
      other.assessmentId == assessmentId &&
      other.sessionId == sessionId &&
      other.subUnitId == subUnitId;

  @override
  int get hashCode =>
      Object.hash(trialId, plotPk, assessmentId, sessionId, subUnitId);
}

final currentRatingProvider =
    StreamProvider.family<RatingRecord?, CurrentRatingParams>((ref, params) {
  return ref.watch(ratingRepositoryProvider).watchCurrentRating(
        trialId: params.trialId,
        plotPk: params.plotPk,
        assessmentId: params.assessmentId,
        sessionId: params.sessionId,
        subUnitId: params.subUnitId,
      );
});

final sessionRatingsProvider =
    StreamProvider.family<List<RatingRecord>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .watch();
});

/// Session IDs among the trial's sessions that have any rating correction (one batch per trial).
final sessionIdsWithCorrectionsForTrialProvider =
    FutureProvider.autoDispose.family<Set<int>, int>((ref, trialId) async {
  final sessions = ref.watch(sessionsForTrialProvider(trialId)).valueOrNull ??
      const <Session>[];
  final ids = sessions.map((s) => s.id).toList();
  if (ids.isEmpty) return {};
  return ref.read(ratingRepositoryProvider).getSessionIdsWithCorrections(ids);
});

/// Plot PKs with at least one correction in the given session (single query per session).
final plotPksWithCorrectionsForSessionProvider =
    StreamProvider.autoDispose.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingCorrections)
        ..where((c) => c.sessionId.equals(sessionId) & c.plotPk.isNotNull()))
      .watch()
      .map((rows) => {
            for (final c in rows)
              if (c.plotPk != null) c.plotPk!
          });
});

/// Number of plots rated in this session (current ratings only).
final ratingCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set = await ref.watch(ratedPlotPksProvider(sessionId).future);
  return set.length;
});

/// Number of current, non-deleted amended ratings for a trial.
final amendedRatingCountForTrialProvider =
    StreamProvider.autoDispose.family<int, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(trialId) &
            r.amended.equals(true) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .watch()
      .map((rows) => rows.length);
});

/// Set of plot IDs that have at least one flag in this session (for session/queue UI).
final flaggedPlotIdsForSessionProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.plotFlags)..where((f) => f.sessionId.equals(sessionId)))
      .watch()
      .map((list) => list.map((f) => f.plotPk).toSet());
});

/// Number of plots flagged in this session.
final flagCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set =
      await ref.watch(flaggedPlotIdsForSessionProvider(sessionId).future);
  return set.length;
});

/// Number of photos in this session.
final photoCountForSessionProvider =
    StreamProvider.autoDispose.family<int, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.photos)..where((p) => p.sessionId.equals(sessionId)))
      .watch()
      .map((list) => list.length);
});

/// Distinct **data** plots (non–guard) with at least one current rating — matches
/// [RatingRepository.getRatedPlotCountForTrial].
final ratedPlotsCountForTrialProvider =
    StreamProvider.autoDispose.family<int, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) =>
      ref.read(ratingRepositoryProvider).getRatedPlotCountForTrial(trialId));
});

/// All current, non-deleted rating records for a trial (across all sessions).
final allSessionRatingsForTrialProvider =
    FutureProvider.autoDispose.family<List<RatingRecord>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(trialId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .get();
});

/// Per–trial-assessment progress: distinct data plots with a **current** rating
/// for that legacy assessment id. Keys are [TrialAssessment.id] or negative
/// legacy [Assessment.id] for unlinked rows. See [AssessmentCompletion].
final trialAssessmentCompletionProvider = StreamProvider.autoDispose
    .family<Map<int, AssessmentCompletion>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final ratingRepo = ref.read(ratingRepositoryProvider);
    final plots = await ref.read(plotsForTrialProvider(trialId).future);
    final totalDataPlots = plots.where((p) => !p.isGuardRow).length;
    final analyzablePlotCount = plots.where(isAnalyzablePlot).length;
    final excludedFromAnalysisCount = totalDataPlots - analyzablePlotCount;
    final counts =
        await ratingRepo.getRatedDataPlotCountsPerLegacyAssessment(trialId);
    final pairs = await ref
        .read(trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);
    final legacy = await ref.read(assessmentsForTrialProvider(trialId).future);
    final taRepo = ref.read(trialAssessmentRepositoryProvider);
    final out = <int, AssessmentCompletion>{};
    final linkedLegacy = <int>{};
    for (final (ta, def) in pairs) {
      final lid = await taRepo.resolveLegacyAssessmentId(ta);
      if (lid != null) linkedLegacy.add(lid);
      final rated = lid != null ? (counts[lid] ?? 0) : 0;
      final name = ta.displayNameOverride?.trim().isNotEmpty == true
          ? ta.displayNameOverride!.trim()
          : def.name;
      out[ta.id] = AssessmentCompletion(
        trialAssessmentId: ta.id,
        assessmentName: name,
        ratedPlotCount: rated,
        analyzablePlotCount: analyzablePlotCount,
        totalDataPlots: totalDataPlots,
        excludedFromAnalysisCount: excludedFromAnalysisCount,
      );
    }
    for (final a in legacy) {
      if (linkedLegacy.contains(a.id)) continue;
      final rated = counts[a.id] ?? 0;
      out[-a.id] = AssessmentCompletion(
        trialAssessmentId: -a.id,
        assessmentName: a.name,
        ratedPlotCount: rated,
        analyzablePlotCount: analyzablePlotCount,
        totalDataPlots: totalDataPlots,
        excludedFromAnalysisCount: excludedFromAnalysisCount,
      );
    }
    return out;
  });
});

// ---------------------------------------------------------------------------
// Intelligence
// ---------------------------------------------------------------------------

final trialIntelligenceServiceProvider =
    Provider<TrialIntelligenceService>((ref) {
  return TrialIntelligenceService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    weatherSnapshotRepository: ref.watch(weatherSnapshotRepositoryProvider),
  );
});

final trialInsightsProvider = FutureProvider.autoDispose
    .family<List<TrialInsight>, int>((ref, trialId) async {
  final treatments =
      await ref.watch(treatmentsForTrialProvider(trialId).future);
  final assessmentPairs = await ref
      .watch(trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);
  final assessmentNames = <int, String>{
    for (final pair in assessmentPairs)
      if (pair.$1.legacyAssessmentId != null)
        pair.$1.legacyAssessmentId!: _cleanAssessmentName(
          pair.$1.displayNameOverride?.trim().isNotEmpty == true
              ? pair.$1.displayNameOverride!
              : pair.$2.name,
          pair.$1.sortOrder,
        ),
  };
  final assessmentDirections = <int, ResultDirection>{
    for (final pair in assessmentPairs)
      if (pair.$1.legacyAssessmentId != null)
        pair.$1.legacyAssessmentId!:
            ResultDirection.fromString(pair.$2.resultDirection),
  };
  final trial = await ref.watch(trialProvider(trialId).future);
  return ref.watch(trialIntelligenceServiceProvider).computeInsights(
      trialId: trialId,
      treatments: treatments,
      assessmentNames: assessmentNames,
      assessmentDirections: assessmentDirections,
      trialIsClosed: trial?.status == kTrialStatusClosed);
});

String _cleanAssessmentName(String raw, int sortOrder) {
  final cleaned = raw
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'—\s*TA\d+'), '')
      .trim();
  return cleaned.isNotEmpty ? cleaned : 'Assessment ${sortOrder + 1}';
}
