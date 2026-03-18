import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class PlotRepository {
  final AppDatabase _db;

  PlotRepository(this._db);

  Future<List<Plot>> getPlotsForTrial(int trialId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.asc(p.rep),
            (p) => OrderingTerm.asc(p.plotSortIndex),
            (p) => OrderingTerm.asc(p.plotId),
          ]))
        .get();
  }

  Stream<List<Plot>> watchPlotsForTrial(int trialId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([
            (p) => OrderingTerm.asc(p.rep),
            (p) => OrderingTerm.asc(p.plotSortIndex),
            (p) => OrderingTerm.asc(p.plotId),
          ]))
        .watch();
  }

  Future<Plot?> getPlotByPk(int plotPk) {
    return (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk) & p.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<Plot?> getPlotByPlotId(int trialId, String plotId) {
    return (_db.select(_db.plots)
          ..where((p) =>
              p.trialId.equals(trialId) &
              p.plotId.equals(plotId) &
              p.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<int> insertPlot({
    required int trialId,
    required String plotId,
    int? plotSortIndex,
    int? rep,
    int? treatmentId,
    String? row,
    String? column,
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
    bool isGuardRow = false,
  }) {
    return _db.into(_db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            plotSortIndex: Value(plotSortIndex),
            rep: Value(rep),
            treatmentId: Value(treatmentId),
            row: Value(row),
            column: Value(column),
            plotLengthM: Value(plotLengthM),
            plotWidthM: Value(plotWidthM),
            plotAreaM2: Value(plotAreaM2),
            harvestLengthM: Value(harvestLengthM),
            harvestWidthM: Value(harvestWidthM),
            harvestAreaM2: Value(harvestAreaM2),
            plotDirection: Value(plotDirection),
            soilSeries: Value(soilSeries),
            plotNotes: Value(plotNotes),
            isGuardRow: Value(isGuardRow),
          ),
        );
  }

  /// Guard row flag (v1: no workflow effect).
  Future<void> updatePlotGuardRow(int plotPk, bool isGuardRow) async {
    await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk)))
        .write(PlotsCompanion(isGuardRow: Value(isGuardRow)));
  }

  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async {
    await _db.transaction(() async {
      for (final plot in plots) {
        await _db.into(_db.plots).insert(plot);
      }
    });
  }

  Future<List<Plot>> getPlotsPage({
    required int trialId,
    required int offset,
    int limit = 50,
    int? repFilter,
    int? treatmentFilter,
  }) {
    final query = _db.select(_db.plots)
      ..where((p) {
        Expression<bool> condition =
            p.trialId.equals(trialId) & p.isDeleted.equals(false);
        if (repFilter != null) {
          condition = condition & p.rep.equals(repFilter);
        }
        if (treatmentFilter != null) {
          condition = condition & p.treatmentId.equals(treatmentFilter);
        }
        return condition;
      })
      ..orderBy([
        (p) => OrderingTerm.asc(p.rep),
        (p) => OrderingTerm.asc(p.plotSortIndex),
        (p) => OrderingTerm.asc(p.plotId),
      ])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<List<int>> getRepsForTrial(int trialId) async {
    final plots = await getPlotsForTrial(trialId);
    return plots.map((p) => p.rep).whereType<int>().toSet().toList()..sort();
  }

  /// Updates notes for a single plot.
  Future<void> updatePlotNotes(int plotPk, String? notes) async {
    await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk)))
        .write(PlotsCompanion(notes: Value(notes)));
  }

  /// Updates plot dimension and field-detail fields. Omitted params are left unchanged.
  Future<void> updatePlotDetails(
    int plotPk, {
    double? plotLengthM,
    double? plotWidthM,
    double? plotAreaM2,
    double? harvestLengthM,
    double? harvestWidthM,
    double? harvestAreaM2,
    String? plotDirection,
    String? soilSeries,
    String? plotNotes,
  }) async {
    await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk))).write(
      PlotsCompanion(
        plotLengthM: plotLengthM != null ? Value(plotLengthM) : const Value.absent(),
        plotWidthM: plotWidthM != null ? Value(plotWidthM) : const Value.absent(),
        plotAreaM2: plotAreaM2 != null ? Value(plotAreaM2) : const Value.absent(),
        harvestLengthM: harvestLengthM != null
            ? Value(harvestLengthM)
            : const Value.absent(),
        harvestWidthM: harvestWidthM != null
            ? Value(harvestWidthM)
            : const Value.absent(),
        harvestAreaM2: harvestAreaM2 != null
            ? Value(harvestAreaM2)
            : const Value.absent(),
        plotDirection:
            plotDirection != null ? Value(plotDirection) : const Value.absent(),
        soilSeries:
            soilSeries != null ? Value(soilSeries) : const Value.absent(),
        plotNotes:
            plotNotes != null ? Value(plotNotes) : const Value.absent(),
      ),
    );
  }

  /// Updates treatment assignment for a single plot.
  /// [assignmentSource]: 'imported' | 'manual' | null (unknown).
  @Deprecated(
      'Use AssignmentRepository for assignment updates. This updates Plot only and is legacy.')
  Future<void> updatePlotTreatment(
    int plotPk,
    int? treatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async {
    await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk))).write(
      PlotsCompanion(
        treatmentId: Value(treatmentId),
        assignmentSource: assignmentSource != null
            ? Value(assignmentSource)
            : const Value.absent(),
        assignmentUpdatedAt: assignmentUpdatedAt != null
            ? Value(assignmentUpdatedAt)
            : const Value.absent(),
      ),
    );
  }

  /// Updates treatment assignments for multiple plots in one transaction.
  /// [assignmentSource]: e.g. 'manual' when user bulk-assigns.
  @Deprecated(
      'Use AssignmentRepository.upsertBulk for assignment updates. This updates Plot only and is legacy.')
  Future<void> updatePlotsTreatmentsBulk(
    Map<int, int?> plotPkToTreatmentId, {
    String? assignmentSource,
    DateTime? assignmentUpdatedAt,
  }) async {
    final at = assignmentUpdatedAt ?? DateTime.now().toUtc();
    await _db.transaction(() async {
      for (final entry in plotPkToTreatmentId.entries) {
        await (_db.update(_db.plots)..where((p) => p.id.equals(entry.key)))
            .write(PlotsCompanion(
          treatmentId: Value(entry.value),
          assignmentSource: assignmentSource != null
              ? Value(assignmentSource)
              : const Value.absent(),
          assignmentUpdatedAt:
              assignmentSource != null ? Value(at) : const Value.absent(),
        ));
      }
    });
  }

  /// Soft-delete plot only. Rating records for this plot are unchanged.
  /// [deletedByUserId] optional; stored on audit event as [performedByUserId].
  Future<void> softDeletePlot(int plotPk,
      {String? deletedBy, int? deletedByUserId}) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      final plot = await (_db.select(_db.plots)
            ..where((p) => p.id.equals(plotPk)))
          .getSingleOrNull();
      if (plot == null) return;

      await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk))).write(
        PlotsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(plot.trialId),
              plotPk: Value(plotPk),
              eventType: 'PLOT_DELETED',
              description: 'Plot deleted and moved to Recovery',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'plot_id': plot.plotId,
                'rep': plot.rep,
              })),
            ),
          );
    });
  }

  /// Recovery: soft-deleted plots for a trial, newest deletion first.
  Future<List<Plot>> getDeletedPlotsForTrial(int trialId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(true))
          ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
        .get();
  }

  /// Recovery: all soft-deleted plots, newest deletion first.
  Future<List<Plot>> getAllDeletedPlots() {
    return (_db.select(_db.plots)
          ..where((p) => p.isDeleted.equals(true))
          ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
        .get();
  }

  /// Recovery: single soft-deleted plot by primary key, or null.
  Future<Plot?> getDeletedPlotByPk(int plotPk) {
    return (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk) & p.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  /// Restores a soft-deleted plot when trial is active and no active plot shares the same plotId.
  Future<PlotRestoreResult> restorePlot(int plotPk,
      {String? restoredBy, int? restoredByUserId}) async {
    return _db.transaction(() async {
      final plot = await getDeletedPlotByPk(plotPk);
      if (plot == null) {
        return PlotRestoreResult.failure(
          'This plot was not found or is no longer deleted.',
        );
      }

      final trial = await (_db.select(_db.trials)
            ..where((t) => t.id.equals(plot.trialId)))
          .getSingleOrNull();
      if (trial == null) {
        return PlotRestoreResult.failure(
          'Trial not found. This plot cannot be restored.',
        );
      }
      if (trial.isDeleted) {
        return PlotRestoreResult.failure(
          'Restore the trial from Recovery before restoring this plot.',
        );
      }

      final conflictingActive = await (_db.select(_db.plots)
            ..where((p) =>
                p.trialId.equals(plot.trialId) &
                p.plotId.equals(plot.plotId) &
                p.isDeleted.equals(false)))
          .get();
      if (conflictingActive.isNotEmpty) {
        return PlotRestoreResult.failure(
          'An active plot with the same plot ID already exists in this trial. '
          'Remove or rename it before restoring.',
        );
      }

      await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk))).write(
        const PlotsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(plot.trialId),
              plotPk: Value(plotPk),
              eventType: 'PLOT_RESTORED',
              description: 'Plot restored from Recovery',
              performedBy: Value(restoredBy),
              performedByUserId: Value(restoredByUserId),
              metadata: Value(jsonEncode({
                'plot_id': plot.plotId,
                'rep': plot.rep,
              })),
            ),
          );

      return PlotRestoreResult.ok();
    });
  }
}

/// Result of [PlotRepository.restorePlot].
class PlotRestoreResult {
  const PlotRestoreResult._({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory PlotRestoreResult.ok() =>
      const PlotRestoreResult._(success: true);

  factory PlotRestoreResult.failure(String message) =>
      PlotRestoreResult._(success: false, errorMessage: message);
}

class PlotNotFoundException implements Exception {
  final int plotPk;
  PlotNotFoundException(this.plotPk);

  @override
  String toString() => 'Plot with pk $plotPk not found.';
}
