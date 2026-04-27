import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/assignment_repository.dart';
import '../plots/plot_repository.dart';
import '../trials/standalone/plot_generation_engine.dart';

/// One trial's RCBD audit result.
class RcbdLayoutAuditResult {
  const RcbdLayoutAuditResult({
    required this.trialId,
    required this.trialName,
    required this.report,
  });

  final int trialId;
  final String trialName;
  final RcbdValidationReport report;

  bool get hasHardViolations => report.hardViolations.isNotEmpty;
  bool get hasSoftViolations => report.softViolations.isNotEmpty;
  bool get hasAnyIssue => hasHardViolations || hasSoftViolations;
}

/// Aggregate report for a full DB scan.
class RcbdLayoutScanReport {
  const RcbdLayoutScanReport({
    required this.trialsScanned,
    required this.affectedTrials,
  });

  /// Total standalone RCBD trials examined (including clean ones).
  final int trialsScanned;

  /// Only trials with hard or soft violations. Empty when all clean.
  final List<RcbdLayoutAuditResult> affectedTrials;

  bool get isClean => affectedTrials.isEmpty;
}

/// Read-only scan of all standalone RCBD trials in the local database.
///
/// Scope: trials where `workspaceType = 'standalone'` AND
/// `experimentalDesign = 'RCBD'`. ARM-imported and protocol-CSV-imported
/// trials are explicitly skipped — their layouts come from the source
/// system, not from [PlotGenerationEngine].
///
/// Use case: detect trials that may have been generated before the RCBD
/// hard-constraint fix landed (canonical first rep, duplicate reps, etc.)
/// so the user can re-randomize before going to the field.
class ScanRcbdLayoutsUseCase {
  ScanRcbdLayoutsUseCase({
    required AppDatabase db,
    required PlotRepository plotRepository,
    required AssignmentRepository assignmentRepository,
  })  : _db = db,
        _plotRepo = plotRepository,
        _assignmentRepo = assignmentRepository;

  final AppDatabase _db;
  final PlotRepository _plotRepo;
  final AssignmentRepository _assignmentRepo;

  /// Scans the DB; returns aggregate report with total scanned + only
  /// the affected trials. Trials skipped due to missing assignments or
  /// fewer than 2 reps still count toward [trialsScanned].
  Future<RcbdLayoutScanReport> execute() async {
    final trials = await (_db.select(_db.trials)
          ..where((t) =>
              t.workspaceType.equals('standalone') &
              t.experimentalDesign.equals(PlotGenerationEngine.designRcbd) &
              t.isDeleted.equals(false)))
        .get();

    final affected = <RcbdLayoutAuditResult>[];
    for (final trial in trials) {
      final auditResult = await _auditTrial(trial);
      if (auditResult != null && auditResult.hasAnyIssue) {
        affected.add(auditResult);
      }
    }
    return RcbdLayoutScanReport(
      trialsScanned: trials.length,
      affectedTrials: affected,
    );
  }

  Future<RcbdLayoutAuditResult?> _auditTrial(Trial trial) async {
    final plots = await _plotRepo.getPlotsForTrial(trial.id);
    final dataPlots = plots.where((p) => !p.isGuardRow).toList();
    if (dataPlots.isEmpty) return null;

    final assignments = await _assignmentRepo.getForTrial(trial.id);
    final treatmentByPlot = {
      for (final a in assignments)
        if (a.treatmentId != null) a.plotId: a.treatmentId!,
    };

    // Build sorted list of distinct treatment IDs → 0-based index map.
    final distinctTreatmentIds = treatmentByPlot.values.toSet().toList()
      ..sort();
    if (distinctTreatmentIds.length < 2) return null;
    final treatmentIndex = {
      for (var i = 0; i < distinctTreatmentIds.length; i++)
        distinctTreatmentIds[i]: i,
    };

    // Group data plots by rep, sort each by plotSortIndex.
    final byRep = <int, List<Plot>>{};
    for (final p in dataPlots) {
      final rep = p.rep ?? 0;
      byRep.putIfAbsent(rep, () => []).add(p);
    }
    for (final list in byRep.values) {
      list.sort((a, b) => (a.plotSortIndex ?? 0).compareTo(b.plotSortIndex ?? 0));
    }
    final sortedReps = byRep.keys.toList()..sort();
    if (sortedReps.length < 2) return null;

    // Build int matrix [rep][col] = treatmentIndex.
    final matrix = <List<int>>[];
    for (final rep in sortedReps) {
      final row = <int>[];
      for (final p in byRep[rep]!) {
        final tid = treatmentByPlot[p.id];
        if (tid == null) {
          // Unassigned plot — can't audit this trial reliably.
          return null;
        }
        row.add(treatmentIndex[tid]!);
      }
      matrix.add(row);
    }

    final report = validateRcbdLayout(matrix, distinctTreatmentIds.length);
    return RcbdLayoutAuditResult(
      trialId: trial.id,
      trialName: trial.name,
      report: report,
    );
  }
}
