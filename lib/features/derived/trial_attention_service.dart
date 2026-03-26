import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/workspace/workspace_config.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../sessions/session_repository.dart';
import '../plots/plot_repository.dart';
import '../ratings/rating_repository.dart';

bool _seedingRecordedNeedsAttention(SeedingEvent e) =>
    e.status == 'pending';

bool _trialApplicationIsPending(TrialApplicationEvent a) =>
    a.status == 'pending';

/// Severity of an attention item.
enum AttentionSeverity { high, medium, low, info }

/// Type of attention item.
enum AttentionType {
  openSession,
  applicationsPending,
  seedingPending,
  seedingMissing,
  plotsUnassigned,
  noSessionsYet,
  plotsPartiallyRated,
  setupIncomplete,
  dataCollectionComplete,
}

/// A single attention item for a trial.
class AttentionItem {
  const AttentionItem({
    required this.type,
    required this.label,
    required this.severity,
    this.count,
    this.onTap,
  });

  final AttentionType type;
  final String label;
  final AttentionSeverity severity;
  final int? count;
  final VoidCallback? onTap;
}

/// Reads existing repositories and returns attention items for a trial.
/// Read-only; never writes.
class TrialAttentionService {
  const TrialAttentionService({
    required this.studyType,
    required this.seedingRepository,
    required this.applicationRepository,
    required this.sessionRepository,
    required this.plotRepository,
    required this.assignmentRepository,
    required this.ratingRepository,
  });

  final StudyType studyType;
  final SeedingRepository seedingRepository;
  final ApplicationRepository applicationRepository;
  final SessionRepository sessionRepository;
  final PlotRepository plotRepository;
  final AssignmentRepository assignmentRepository;
  final RatingRepository ratingRepository;

  AttentionSeverity _seedingPendingSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.medium,
        StudyType.variety => AttentionSeverity.medium,
        StudyType.general => AttentionSeverity.low,
      };

  AttentionSeverity get _openSessionSeverity => AttentionSeverity.medium;

  AttentionSeverity _noSessionsYetSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.medium,
        StudyType.variety => AttentionSeverity.medium,
        StudyType.general => AttentionSeverity.low,
      };

  /// When [applicationsPending] is included (variety suppressed upstream).
  AttentionSeverity _applicationsPendingSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.high,
        StudyType.general => AttentionSeverity.low,
        StudyType.variety => AttentionSeverity.low,
      };

  AttentionSeverity _plotsUnassignedSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.medium,
        StudyType.variety => AttentionSeverity.medium,
        StudyType.general => AttentionSeverity.low,
      };

  AttentionSeverity _plotsPartiallyRatedSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.high,
        StudyType.variety => AttentionSeverity.medium,
        StudyType.general => AttentionSeverity.medium,
      };

  AttentionSeverity _setupIncompleteNoPlotsSeverity() => switch (studyType) {
        StudyType.glp => AttentionSeverity.high,
        StudyType.efficacy => AttentionSeverity.medium,
        StudyType.variety => AttentionSeverity.low,
        StudyType.general => AttentionSeverity.low,
      };

  Future<List<AttentionItem>> getAttentionItems(int trialId) async {
    final items = <AttentionItem>[];

    // SEEDING
    final seedingEvent =
        await seedingRepository.getSeedingEventForTrial(trialId);
    if (seedingEvent == null) {
      final seedingMissingSeverity = studyType == StudyType.glp
          ? AttentionSeverity.high
          : AttentionSeverity.medium;
      items.add(AttentionItem(
        type: AttentionType.seedingMissing,
        label: 'Seeding not recorded yet',
        severity: seedingMissingSeverity,
      ));
    } else if (_seedingRecordedNeedsAttention(seedingEvent)) {
      items.add(AttentionItem(
        type: AttentionType.seedingPending,
        label: 'Seeding recorded — mark complete?',
        severity: _seedingPendingSeverity(),
      ));
    }

    // SESSIONS — getSessionsForTrial already filters isDeleted=false
    final sessions = await sessionRepository.getSessionsForTrial(trialId);
    final openSessions =
        sessions.where((s) => s.endedAt == null).toList();
    final completedSessions =
        sessions.where((s) => s.endedAt != null).toList();

    if (openSessions.isNotEmpty) {
      items.add(AttentionItem(
        type: AttentionType.openSession,
        label: 'Session in progress — resume?',
        severity: _openSessionSeverity,
      ));
    }

    if (completedSessions.isEmpty && openSessions.isEmpty) {
      items.add(AttentionItem(
        type: AttentionType.noSessionsYet,
        label: 'No sessions started yet',
        severity: _noSessionsYetSeverity(),
      ));
    }

    // APPLICATIONS (variety workspace de-emphasizes applications tab)
    if (studyType != StudyType.variety) {
      final applications =
          await applicationRepository.getApplicationsForTrial(trialId);
      final pending =
          applications.where(_trialApplicationIsPending).toList();

      if (pending.isNotEmpty) {
        items.add(AttentionItem(
          type: AttentionType.applicationsPending,
          label:
              '${pending.length} application${pending.length == 1 ? '' : 's'} pending',
          severity: _applicationsPendingSeverity(),
          count: pending.length,
        ));
      }
    }

    // PLOTS
    final plots = await plotRepository.getPlotsForTrial(trialId);
    final totalPlotCount = plots.length;

    if (totalPlotCount == 0) {
      items.add(AttentionItem(
        type: AttentionType.setupIncomplete,
        label: 'No plots set up yet',
        severity: _setupIncompleteNoPlotsSeverity(),
      ));
    } else {
      final assignments =
          await assignmentRepository.getForTrial(trialId);
      final unassigned =
          assignments.where((a) => a.treatmentId == null).length;

      if (unassigned > 0) {
        items.add(AttentionItem(
          type: AttentionType.plotsUnassigned,
          label:
              '$unassigned plot${unassigned == 1 ? '' : 's'} not assigned',
          severity: _plotsUnassignedSeverity(),
          count: unassigned,
        ));
      }

      // RATINGS
      final ratedCount =
          await ratingRepository.getRatedPlotCountForTrial(trialId);

      if (ratedCount < totalPlotCount && completedSessions.isNotEmpty) {
        items.add(AttentionItem(
          type: AttentionType.plotsPartiallyRated,
          label: '$ratedCount of $totalPlotCount plots rated',
          severity: _plotsPartiallyRatedSeverity(),
          count: ratedCount,
        ));
      }

      if (ratedCount == totalPlotCount && totalPlotCount > 0) {
        items.add(AttentionItem(
          type: AttentionType.dataCollectionComplete,
          label: 'All $totalPlotCount plots rated',
          severity: AttentionSeverity.info,
          count: totalPlotCount,
        ));
      }
    }

    // Sort: high → medium → low → info
    items.sort(
        (a, b) => a.severity.index.compareTo(b.severity.index));

    return items;
  }
}
