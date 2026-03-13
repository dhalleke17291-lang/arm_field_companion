import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

enum DiagnosticSeverity { pass, warning, error }

class DiagnosticCheck {
  const DiagnosticCheck({
    required this.label,
    this.detail,
    required this.severity,
  });

  final String label;
  final String? detail;
  final DiagnosticSeverity severity;
}

class TrialReadinessResult {
  const TrialReadinessResult({required this.checks});

  final List<DiagnosticCheck> checks;

  bool get isExportBlocked =>
      checks.any((c) => c.severity == DiagnosticSeverity.error);
  bool get hasWarnings =>
      checks.any((c) => c.severity == DiagnosticSeverity.warning);
  int get passCount =>
      checks.where((c) => c.severity == DiagnosticSeverity.pass).length;
  int get warningCount =>
      checks.where((c) => c.severity == DiagnosticSeverity.warning).length;
  int get errorCount =>
      checks.where((c) => c.severity == DiagnosticSeverity.error).length;
}

/// Runs trial readiness checks using existing repositories. No schema changes.
class TrialDiagnosticsService {
  Future<TrialReadinessResult> runChecks(String trialId, Ref ref) async {
    final trialPk = int.parse(trialId);
    final checks = <DiagnosticCheck>[];

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
      checks.add(const DiagnosticCheck(
        label: 'Trial not found',
        severity: DiagnosticSeverity.error,
      ));
      return TrialReadinessResult(checks: checks);
    }

    final plots = await plotRepo.getPlotsForTrial(trialPk);
    if (plots.isEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'No plots — cannot export',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Plots defined',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final treatments = await treatmentRepo.getTreatmentsForTrial(trialPk);
    if (treatments.isEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'No treatments defined',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Treatments defined',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final assessments =
        await ref.read(assessmentsForTrialProvider(trialPk).future);
    if (assessments.isEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'No assessments defined',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Assessments defined',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final assignments = await assignmentRepo.getForTrial(trialPk);
    final hasAnyAssignment = assignments.isNotEmpty &&
        assignments.any((a) => a.treatmentId != null);
    if (!hasAnyAssignment) {
      checks.add(const DiagnosticCheck(
        label: 'No plots have treatment assignments',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Plot assignments present',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final sessions = await sessionRepo.getSessionsForTrial(trialPk);
    if (sessions.isEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'No rating sessions recorded',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Sessions exist',
        severity: DiagnosticSeverity.pass,
      ));
    }

    int totalRatings = 0;
    for (final session in sessions) {
      totalRatings +=
          (await ratingRepo.getCurrentRatingsForSession(session.id)).length;
    }
    if (totalRatings == 0) {
      checks.add(const DiagnosticCheck(
        label: 'No ratings recorded in any session',
        severity: DiagnosticSeverity.error,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Ratings recorded',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final seeding = await seedingRepo.getSeedingEventForTrial(trialPk);
    if (seeding == null) {
      checks.add(const DiagnosticCheck(
        label: 'Seeding event not recorded',
        severity: DiagnosticSeverity.warning,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Seeding event recorded',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final applications = await applicationRepo.getApplicationsForTrial(trialPk);
    if (applications.isEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'No application events recorded',
        severity: DiagnosticSeverity.warning,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'Application events recorded',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final firstAppDate = applications.isEmpty
        ? null
        : applications
            .map((e) => e.applicationDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    if (firstAppDate != null) {
      final sessionBeforeFirst =
          sessions.where((s) => s.startedAt.isBefore(firstAppDate)).toList();
      if (sessionBeforeFirst.isNotEmpty) {
        checks.add(const DiagnosticCheck(
          label: 'Session recorded before first application — check dates',
          severity: DiagnosticSeverity.warning,
        ));
      } else {
        checks.add(const DiagnosticCheck(
          label: 'All sessions after first application',
          severity: DiagnosticSeverity.pass,
        ));
      }
    }

    final ratedCount = await ref.read(ratedPlotsCountForTrialProvider(trialPk).future);
    final unratedCount = plots.length - ratedCount;
    if (unratedCount > 0) {
      checks.add(DiagnosticCheck(
        label: '$unratedCount plots have no ratings',
        severity: DiagnosticSeverity.warning,
      ));
    } else if (plots.isNotEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'All plots rated',
        severity: DiagnosticSeverity.pass,
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
      checks.add(const DiagnosticCheck(
        label: 'One or more treatments have no components',
        severity: DiagnosticSeverity.warning,
      ));
    } else {
      checks.add(const DiagnosticCheck(
        label: 'All treatments have components',
        severity: DiagnosticSeverity.pass,
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
        checks.add(DiagnosticCheck(
          label: 'Assessment defined but never used: $name',
          severity: DiagnosticSeverity.warning,
        ));
      }
    } else if (assessmentIdsInSessions.isNotEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'All assessments used',
        severity: DiagnosticSeverity.pass,
      ));
    }

    final anyAppIncomplete = applications.any((a) {
      final noProduct = a.productName == null || a.productName!.trim().isEmpty;
      final noRate = a.rate == null;
      return noProduct || noRate;
    });
    if (anyAppIncomplete) {
      checks.add(const DiagnosticCheck(
        label: 'Application event has incomplete product details',
        severity: DiagnosticSeverity.warning,
      ));
    } else if (applications.isNotEmpty) {
      checks.add(const DiagnosticCheck(
        label: 'All application events complete',
        severity: DiagnosticSeverity.pass,
      ));
    }

    return TrialReadinessResult(checks: checks);
  }
}
