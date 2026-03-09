import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Repository for the Assignments table (protocol-to-field mapping layer).
/// Resolution: Plot → Assignment → Treatment.
class AssignmentRepository {
  final AppDatabase _db;

  AssignmentRepository(this._db);

  /// Returns the assignment for a plot (by plot pk). One assignment per plot per trial.
  Future<Assignment?> getForPlot(int plotPk) async {
    return (_db.select(_db.assignments)
          ..where((a) => a.plotId.equals(plotPk)))
        .getSingleOrNull();
  }

  /// Returns the assignment for a (trial, plot) pair.
  Future<Assignment?> getForTrialAndPlot(int trialId, int plotPk) async {
    return (_db.select(_db.assignments)
          ..where((a) =>
              a.trialId.equals(trialId) & a.plotId.equals(plotPk)))
        .getSingleOrNull();
  }

  /// All assignments for a trial (for building plot → treatmentId maps in UI).
  Future<List<Assignment>> getForTrial(int trialId) async {
    return (_db.select(_db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .get();
  }

  /// Stream of assignments for a trial (reactive UI).
  Stream<List<Assignment>> watchForTrial(int trialId) {
    return (_db.select(_db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .watch();
  }

  /// Upserts one assignment: insert or update by (trialId, plotId).
  Future<void> upsert({
    required int trialId,
    required int plotId,
    int? treatmentId,
    int? replication,
    int? block,
    int? range,
    int? column,
    int? position,
    bool? isCheck,
    bool? isControl,
    String? assignmentSource,
    DateTime? assignedAt,
    int? assignedBy,
    String? notes,
  }) async {
    final existing = await getForTrialAndPlot(trialId, plotId);
    final now = DateTime.now().toUtc();
    if (existing != null) {
      await (_db.update(_db.assignments)
            ..where((a) =>
                a.trialId.equals(trialId) & a.plotId.equals(plotId)))
          .write(AssignmentsCompanion(
        treatmentId: Value(treatmentId),
        replication: Value(replication),
        block: Value(block),
        range: Value(range),
        column: Value(column),
        position: Value(position),
        isCheck: Value(isCheck),
        isControl: Value(isControl),
        assignmentSource: Value(assignmentSource),
        assignedAt: Value(assignedAt ?? now),
        assignedBy: Value(assignedBy),
        notes: Value(notes),
        updatedAt: Value(now),
      ));
    } else {
      await _db.into(_db.assignments).insert(AssignmentsCompanion.insert(
        trialId: trialId,
        plotId: plotId,
        treatmentId: Value(treatmentId),
        replication: Value(replication),
        block: Value(block),
        range: Value(range),
        column: Value(column),
        position: Value(position),
        isCheck: Value(isCheck),
        isControl: Value(isControl),
        assignmentSource: Value(assignmentSource),
        assignedAt: Value(assignedAt ?? now),
        assignedBy: Value(assignedBy),
        notes: Value(notes),
      ));
    }
  }

  /// Bulk upsert: one assignment per plot.
  Future<void> upsertBulk({
    required int trialId,
    required Map<int, int?> plotPkToTreatmentId,
    String? assignmentSource,
    DateTime? assignedAt,
  }) async {
    final at = assignedAt ?? DateTime.now().toUtc();
    await _db.transaction(() async {
      for (final entry in plotPkToTreatmentId.entries) {
        await upsert(
          trialId: trialId,
          plotId: entry.key,
          treatmentId: entry.value,
          assignmentSource: assignmentSource,
          assignedAt: at,
        );
      }
    });
  }
}
