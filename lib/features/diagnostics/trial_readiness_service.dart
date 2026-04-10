import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'trial_readiness.dart';

/// Runs trial readiness checks using existing providers and trial-scoped DB reads.
class TrialReadinessService {
  Future<TrialReadinessReport> runChecks(String trialId, Ref ref) async {
    final trialPk = int.parse(trialId);
    final checks = <TrialReadinessCheck>[];

    final trialRepo = ref.read(trialRepositoryProvider);
    final plotRepo = ref.read(plotRepositoryProvider);
    final treatmentRepo = ref.read(treatmentRepositoryProvider);
    final assignmentRepo = ref.read(assignmentRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final ratingRepo = ref.read(ratingRepositoryProvider);
    final seedingRepo = ref.read(seedingRepositoryProvider);
    final applicationRepo = ref.read(applicationRepositoryProvider);

    final trial = await trialRepo.getTrialById(trialPk);
    if (trial == null) {
      checks.add(const TrialReadinessCheck(
        code: 'trial_not_found',
        label: 'Trial not found',
        severity: TrialCheckSeverity.blocker,
      ));
      return TrialReadinessReport(checks: checks);
    }

    final isStandalone =
        trial.workspaceType.trim().toLowerCase() == 'standalone';

    final plots = await plotRepo.getPlotsForTrial(trialPk);
    final dataPlots = plots.where((p) => !p.isGuardRow).toList();
    final dataPlotsCount = dataPlots.length;
    if (plots.isEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'no_plots',
        label: 'No plots defined',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'plots_ok',
        label: 'Plots defined',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final treatments = await treatmentRepo.getTreatmentsForTrial(trialPk);
    if (treatments.isEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'no_treatments',
        label: 'No treatments defined',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'treatments_ok',
        label: 'Treatments defined',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final legacyAssessments =
        await ref.read(assessmentsForTrialProvider(trialPk).future);
    final trialAssessmentRepo = ref.read(trialAssessmentRepositoryProvider);
    final trialAssessments = await trialAssessmentRepo.getForTrial(trialPk);
    final hasAssessments = legacyAssessments.isNotEmpty || trialAssessments.isNotEmpty;
    if (!hasAssessments) {
      checks.add(const TrialReadinessCheck(
        code: 'no_assessments',
        label: 'No assessments defined',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'assessments_ok',
        label: 'Assessments defined',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final assignments = await assignmentRepo.getForTrial(trialPk);
    final hasAnyAssignment =
        assignments.isNotEmpty && assignments.any((a) => a.treatmentId != null);
    if (!hasAnyAssignment) {
      checks.add(const TrialReadinessCheck(
        code: 'no_assignments',
        label: 'No plots have treatment assignments',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'assignments_ok',
        label: 'Plot assignments present',
        severity: TrialCheckSeverity.pass,
      ));
    }

    if (plots.isNotEmpty) {
      final plotPkToAssignmentTreatment = <int, int?>{};
      for (final a in assignments) {
        plotPkToAssignmentTreatment[a.plotId] = a.treatmentId;
      }
      var plotsWithoutTreatmentCount = 0;
      for (final p in dataPlots) {
        final effective =
            plotPkToAssignmentTreatment[p.id] ?? p.treatmentId;
        if (effective == null) plotsWithoutTreatmentCount++;
      }
      if (plotsWithoutTreatmentCount > 0) {
        checks.add(TrialReadinessCheck(
          code: 'plots_without_treatment',
          label:
              '$plotsWithoutTreatmentCount plot(s) have no treatment assigned',
          detail: 'Assign treatments to all plots before '
              'export to ensure correct column mapping.',
          severity: TrialCheckSeverity.warning,
        ));
      } else {
        checks.add(const TrialReadinessCheck(
          code: 'plots_without_treatment',
          label: 'All plots have treatments assigned',
          severity: TrialCheckSeverity.pass,
        ));
      }
    }

    final sessions = await sessionRepo.getSessionsForTrial(trialPk);
    if (sessions.isEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'no_sessions',
        label: 'No rating sessions recorded',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'sessions_ok',
        label: 'Sessions exist',
        severity: TrialCheckSeverity.pass,
      ));
    }

    int totalRatings = 0;
    for (final session in sessions) {
      totalRatings +=
          (await ratingRepo.getCurrentRatingsForSession(session.id)).length;
    }
    if (totalRatings == 0) {
      checks.add(const TrialReadinessCheck(
        code: 'no_ratings',
        label: 'No ratings recorded',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'ratings_ok',
        label: 'Ratings recorded',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final seeding = await seedingRepo.getSeedingEventForTrial(trialPk);
    if (seeding == null) {
      checks.add(TrialReadinessCheck(
        code: 'no_seeding',
        label: 'Seeding event not recorded',
        severity:
            isStandalone ? TrialCheckSeverity.info : TrialCheckSeverity.warning,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'seeding_ok',
        label: 'Seeding event recorded',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final applications = await applicationRepo.getApplicationsForTrial(trialPk);
    if (applications.isEmpty) {
      checks.add(TrialReadinessCheck(
        code: 'no_applications',
        label: 'No application events recorded',
        severity:
            isStandalone ? TrialCheckSeverity.info : TrialCheckSeverity.warning,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'applications_ok',
        label: 'Application events recorded',
        severity: TrialCheckSeverity.pass,
      ));
    }

    // Only applied applications define the execution timeline.
    // Pending applications are planned but not yet executed.
    final appliedApplications =
        applications.where((a) => a.status == 'applied').toList();
    final firstAppDate = appliedApplications.isEmpty
        ? null
        : appliedApplications
            .map((e) => e.applicationDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    if (firstAppDate != null) {
      final sessionsBeforeFirst =
          sessions.where((s) => s.startedAt.isBefore(firstAppDate)).toList();
      if (sessionsBeforeFirst.isNotEmpty) {
        final names = sessionsBeforeFirst.map((s) => s.name).join(', ');
        checks.add(TrialReadinessCheck(
          code: 'session_before_application',
          label: 'Session recorded before first application',
          detail: names,
          severity: TrialCheckSeverity.warning,
        ));
      } else {
        checks.add(const TrialReadinessCheck(
          code: 'sessions_after_app_ok',
          label: 'All sessions after first application',
          severity: TrialCheckSeverity.pass,
        ));
      }
    }

    final ratedCount =
        await ref.read(ratedPlotsCountForTrialProvider(trialPk).future);
    final unratedCount =
        (dataPlotsCount - ratedCount).clamp(0, dataPlotsCount);
    if (unratedCount > 0) {
      checks.add(TrialReadinessCheck(
        code: 'unrated_plots',
        label: '$unratedCount plots have no ratings',
        severity: TrialCheckSeverity.warning,
      ));
    } else if (dataPlotsCount > 0) {
      checks.add(const TrialReadinessCheck(
        code: 'all_rated_ok',
        label: 'All plots rated',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final ratedByAssessment =
        await ratingRepo.getRatedDataPlotCountsPerLegacyAssessment(trialPk);
    final pairs = await ref
        .read(trialAssessmentsWithDefinitionsForTrialProvider(trialPk).future);
    final linkedLegacyIds = <int>{};
    for (final (ta, _) in pairs) {
      final lid = await trialAssessmentRepo.resolveLegacyAssessmentId(ta);
      if (lid != null) linkedLegacyIds.add(lid);
    }
    final assessmentTargets = <({int stableId, String name, int? legacyId})>[];
    for (final (ta, def) in pairs) {
      final name = ta.displayNameOverride?.trim().isNotEmpty == true
          ? ta.displayNameOverride!.trim()
          : def.name;
      final lid = await trialAssessmentRepo.resolveLegacyAssessmentId(ta);
      assessmentTargets.add((stableId: ta.id, name: name, legacyId: lid));
    }
    for (final a in legacyAssessments) {
      if (linkedLegacyIds.contains(a.id)) continue;
      assessmentTargets
          .add((stableId: -a.id, name: a.name, legacyId: a.id));
    }

    for (final t in assessmentTargets) {
      final lid = t.legacyId;
      final ratedFor = lid != null ? (ratedByAssessment[lid] ?? 0) : 0;
      final unratedForAssessment = dataPlotsCount - ratedFor;
      if (dataPlotsCount > 0) {
        if (unratedForAssessment > 0) {
          checks.add(TrialReadinessCheck(
            code: 'assessment_incomplete_${t.stableId}',
            label: '${t.name}: $ratedFor/$dataPlotsCount plots rated',
            detail:
                '$unratedForAssessment plots still need rating for this assessment.',
            severity: TrialCheckSeverity.warning,
          ));
        } else {
          checks.add(TrialReadinessCheck(
            code: 'assessment_complete_${t.stableId}',
            label: '${t.name}: all plots rated',
            severity: TrialCheckSeverity.pass,
          ));
        }
      }
    }

    if (assessmentTargets.isNotEmpty &&
        dataPlotsCount > 0 &&
        assessmentTargets.every((t) {
          final lid = t.legacyId;
          final ratedFor = lid != null ? (ratedByAssessment[lid] ?? 0) : 0;
          return ratedFor >= dataPlotsCount;
        })) {
      checks.add(const TrialReadinessCheck(
        code: 'all_assessments_complete',
        label: 'All assessments complete on all plots',
        severity: TrialCheckSeverity.pass,
      ));
    }

    bool anyTreatmentNoComponents = false;
    for (final t in treatments) {
      final comps = await treatmentRepo.getComponentsForTreatment(t.id);
      if (comps.isEmpty) {
        anyTreatmentNoComponents = true;
        break;
      }
    }
    if (anyTreatmentNoComponents) {
      checks.add(const TrialReadinessCheck(
        code: 'missing_components',
        label: 'One or more treatments have no components',
        severity: TrialCheckSeverity.warning,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'components_ok',
        label: 'All treatments have components',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final assessmentIdsInSessions = <int, String>{};
    for (final session in sessions) {
      final sessionAssessments =
          await sessionRepo.getSessionAssessments(session.id);
      for (final a in sessionAssessments) {
        assessmentIdsInSessions[a.id] = a.name;
      }
    }
    final usedAssessmentIds = <int>{};
    for (final session in sessions) {
      final ratings = await ratingRepo.getCurrentRatingsForSession(session.id);
      for (final r in ratings) {
        usedAssessmentIds.add(r.assessmentId);
      }
    }
    final unusedAssessments = assessmentIdsInSessions.entries
        .where((e) => !usedAssessmentIds.contains(e.key))
        .map((e) => e.value)
        .toList();
    if (unusedAssessments.isNotEmpty) {
      for (final name in unusedAssessments) {
        checks.add(TrialReadinessCheck(
          code: 'unused_assessment',
          label: 'Assessment defined but never used: $name',
          severity: TrialCheckSeverity.warning,
        ));
      }
    } else if (assessmentIdsInSessions.isNotEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'assessments_used_ok',
        label: 'All assessments used',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final anyAppIncomplete = applications.any((a) {
      final noProduct = a.productName == null || a.productName!.trim().isEmpty;
      final noRate = a.rate == null;
      return noProduct || noRate;
    });
    if (anyAppIncomplete) {
      checks.add(const TrialReadinessCheck(
        code: 'incomplete_application',
        label: 'Application event has incomplete details',
        severity: TrialCheckSeverity.warning,
      ));
    } else if (applications.isNotEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'applications_complete_ok',
        label: 'All application events complete',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final db = ref.read(databaseProvider);
    final rc = db.ratingCorrections;
    final rr = db.ratingRecords;
    final correctionsQuery = db.select(rc).join([
      drift.innerJoin(rr, rr.id.equalsExp(rc.ratingId)),
    ])
      ..where(rr.trialId.equals(trialPk) & rc.reason.equals(''));
    final correctionsMissingReasonRows = await correctionsQuery.get();
    final correctionsMissingReasonCount = correctionsMissingReasonRows.length;
    if (correctionsMissingReasonCount > 0) {
      checks.add(TrialReadinessCheck(
        code: 'corrections_missing_reason',
        label:
            '$correctionsMissingReasonCount correction(s) have no reason recorded',
        detail: 'GLP compliance requires a reason for every '
            'rating correction. Review corrections in '
            'the audit log.',
        severity: TrialCheckSeverity.blocker,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'corrections_missing_reason',
        label: 'All corrections have reasons recorded',
        severity: TrialCheckSeverity.pass,
      ));
    }

    return TrialReadinessReport(checks: checks);
  }
}
