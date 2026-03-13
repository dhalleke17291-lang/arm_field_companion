import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'trial_readiness.dart';

/// Runs trial readiness checks using existing providers only. No new queries.
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

    final plots = await plotRepo.getPlotsForTrial(trialPk);
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

    final assessments =
        await ref.read(assessmentsForTrialProvider(trialPk).future);
    if (assessments.isEmpty) {
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
      checks.add(const TrialReadinessCheck(
        code: 'no_seeding',
        label: 'Seeding event not recorded',
        severity: TrialCheckSeverity.warning,
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
      checks.add(const TrialReadinessCheck(
        code: 'no_applications',
        label: 'No application events recorded',
        severity: TrialCheckSeverity.warning,
      ));
    } else {
      checks.add(const TrialReadinessCheck(
        code: 'applications_ok',
        label: 'Application events recorded',
        severity: TrialCheckSeverity.pass,
      ));
    }

    final firstAppDate = applications.isEmpty
        ? null
        : applications
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
    final unratedCount = plots.length - ratedCount;
    if (unratedCount > 0) {
      checks.add(TrialReadinessCheck(
        code: 'unrated_plots',
        label: '$unratedCount plots have no ratings',
        severity: TrialCheckSeverity.warning,
      ));
    } else if (plots.isNotEmpty) {
      checks.add(const TrialReadinessCheck(
        code: 'all_rated_ok',
        label: 'All plots rated',
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

    return TrialReadinessReport(checks: checks);
  }
}
