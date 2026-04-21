import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/protocol_edit_blocked_exception.dart';
import '../../core/trial_state.dart';

/// Repository for the Assignments table (protocol-to-field mapping layer).
/// Resolution: Plot → Assignment → Treatment.
class AssignmentRepository {
  final AppDatabase _db;

  AssignmentRepository(this._db);

  /// Returns the assignment for a plot (by plot pk). One assignment per plot per trial.
  Future<Assignment?> getForPlot(int plotPk) async {
    return (_db.select(_db.assignments)..where((a) => a.plotId.equals(plotPk)))
        .getSingleOrNull();
  }

  /// Returns the assignment for a (trial, plot) pair.
  Future<Assignment?> getForTrialAndPlot(int trialId, int plotPk) async {
    return (_db.select(_db.assignments)
          ..where((a) => a.trialId.equals(trialId) & a.plotId.equals(plotPk)))
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

  Future<void> _assertAssignmentsEditable(int trialId) async {
    await assertCanEditProtocolForTrialId(_db, trialId);
    final trial = await loadTrialForProtocolCheck(_db, trialId);
    if (trial == null) {
      throw StateError('Trial not found');
    }
    // Standalone Active: [assertCanEditProtocolForTrialId] already enforced !sessionData.
    if (trialWorkspaceIsStandalone(trial.workspaceType) &&
        trial.status == kTrialStatusActive) {
      return;
    }
    final hasData = await trialHasAnySessionData(_db, trialId);
    if (isAssignmentsLocked(trial.status, hasData)) {
      throw ProtocolEditBlockedException(
        getAssignmentsLockMessage(trial.status, hasData),
      );
    }
  }

  Future<void> _persistAssignmentRow({
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
            ..where((a) => a.trialId.equals(trialId) & a.plotId.equals(plotId)))
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
    await _db.into(_db.auditEvents).insert(
          AuditEventsCompanion.insert(
            trialId: Value(trialId),
            plotPk: Value(plotId),
            eventType: 'TREATMENT_ASSIGNED',
            description: treatmentId != null
                ? 'Treatment $treatmentId assigned to plot $plotId'
                : 'Treatment unassigned from plot $plotId',
            performedBy: Value(assignmentSource),
            performedByUserId: Value(assignedBy),
          ),
        );
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
    await _assertAssignmentsEditable(trialId);
    await _persistAssignmentRow(
      trialId: trialId,
      plotId: plotId,
      treatmentId: treatmentId,
      replication: replication,
      block: block,
      range: range,
      column: column,
      position: position,
      isCheck: isCheck,
      isControl: isControl,
      assignmentSource: assignmentSource,
      assignedAt: assignedAt,
      assignedBy: assignedBy,
      notes: notes,
    );
  }

  /// Bulk upsert: one assignment per plot.
  Future<void> upsertBulk({
    required int trialId,
    required Map<int, int?> plotPkToTreatmentId,
    String? assignmentSource,
    DateTime? assignedAt,
  }) async {
    await _assertAssignmentsEditable(trialId);
    final at = assignedAt ?? DateTime.now().toUtc();
    for (final entry in plotPkToTreatmentId.entries) {
      await _persistAssignmentRow(
        trialId: trialId,
        plotId: entry.key,
        treatmentId: entry.value,
        assignmentSource: assignmentSource,
        assignedAt: at,
      );
    }

    // Summary audit event for bulk operation
    await _db.into(_db.auditEvents).insert(
          AuditEventsCompanion.insert(
            trialId: Value(trialId),
            eventType: 'TREATMENT_ASSIGNED_BULK',
            description:
                'Bulk assignment: ${plotPkToTreatmentId.length} plots updated',
            performedBy: Value(assignmentSource),
          ),
        );
  }
}
