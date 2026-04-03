import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';
import 'assignment_repository.dart';

class TreatmentRepository {
  final AppDatabase _db;
  final AssignmentRepository? _assignmentRepository;

  TreatmentRepository(this._db, [this._assignmentRepository]);

  TreatmentsCompanion _withTreatmentLastEdit(
    TreatmentsCompanion base,
    int? performedByUserId,
  ) {
    if (performedByUserId == null) return base;
    return base.copyWith(
      lastEditedAt: Value(DateTime.now().toUtc()),
      lastEditedByUserId: Value(performedByUserId),
    );
  }

  TreatmentComponentsCompanion _withComponentLastEdit(
    TreatmentComponentsCompanion base,
    int? performedByUserId,
  ) {
    if (performedByUserId == null) return base;
    return base.copyWith(
      lastEditedAt: Value(DateTime.now().toUtc()),
      lastEditedByUserId: Value(performedByUserId),
    );
  }

  Future<List<Treatment>> getTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Stream<List<Treatment>> watchTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .watch();
  }

  Future<Treatment?> getTreatmentById(int id) {
    return (_db.select(_db.treatments)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Soft-deleted treatments for a trial (Recovery), newest deletion first.
  Future<List<Treatment>> getDeletedTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId) & t.isDeleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  Future<Treatment?> getDeletedTreatmentById(int id) {
    return (_db.select(_db.treatments)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  /// Assignment or legacy plot column; non-null even if the treatment row is soft-deleted.
  Future<int?> getEffectiveTreatmentIdForPlot(int plotPk) async {
    if (_assignmentRepository != null) {
      final a = await _assignmentRepository!.getForPlot(plotPk);
      if (a != null && a.treatmentId != null) return a.treatmentId;
    }
    final plot = await (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk) & p.isDeleted.equals(false)))
        .getSingleOrNull();
    return plot?.treatmentId;
  }

  Future<Treatment?> getTreatmentForPlot(int plotPk) async {
    final tid = await getEffectiveTreatmentIdForPlot(plotPk);
    if (tid == null) return null;
    return getTreatmentById(tid);
  }

  Future<List<TreatmentComponent>> getComponentsForTreatment(int treatmentId) {
    return (_db.select(_db.treatmentComponents)
          ..where((c) =>
              c.treatmentId.equals(treatmentId) & c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<int> insertTreatment({
    required int trialId,
    required String code,
    required String name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
    int? performedByUserId,
  }) async {
    await assertCanEditProtocolForTrialId(_db, trialId);
    final companion = _withTreatmentLastEdit(
      TreatmentsCompanion.insert(
        trialId: trialId,
        code: code,
        name: name,
        description: Value(description),
        treatmentType: Value(treatmentType),
        timingCode: Value(timingCode),
        eppoCode: Value(eppoCode),
      ),
      performedByUserId,
    );
    return _db.into(_db.treatments).insert(companion);
  }

  Future<void> updateTreatment(
    int id, {
    String? code,
    String? name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
    int? performedByUserId,
  }) async {
    final existing = await getTreatmentById(id);
    if (existing == null) {
      throw TreatmentNotFoundException(id);
    }
    await assertCanEditProtocolForTrialId(_db, existing.trialId);
    final base = TreatmentsCompanion(
      code: code != null ? Value(code) : const Value.absent(),
      name: name != null ? Value(name) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      treatmentType: treatmentType != null
          ? Value(treatmentType)
          : const Value.absent(),
      timingCode:
          timingCode != null ? Value(timingCode) : const Value.absent(),
      eppoCode: eppoCode != null ? Value(eppoCode) : const Value.absent(),
    );
    await (_db.update(_db.treatments)..where((t) => t.id.equals(id))).write(
          _withTreatmentLastEdit(base, performedByUserId),
        );
  }

  /// Soft-deletes treatment and all its components; assignment/plot FKs are unchanged.
  Future<void> softDeleteTreatment(int id,
      {String? deletedBy, int? deletedByUserId}) async {
    final existing = await getTreatmentById(id);
    if (existing == null) {
      throw TreatmentNotFoundException(id);
    }
    await assertCanEditProtocolForTrialId(_db, existing.trialId);
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      final deletedComponentsCount = await (_db
              .update(_db.treatmentComponents)
            ..where((c) =>
                c.treatmentId.equals(id) & c.isDeleted.equals(false)))
          .write(
        TreatmentComponentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );

      await (_db.update(_db.treatments)..where((t) => t.id.equals(id))).write(
        TreatmentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(existing.trialId),
              eventType: 'TREATMENT_DELETED',
              description: 'Treatment soft-deleted',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'treatment_name': existing.name,
                'deleted_components_count': deletedComponentsCount,
              })),
            ),
          );
    });
  }

  Future<TreatmentRestoreResult> restoreTreatment(int treatmentId,
      {String? restoredBy, int? restoredByUserId}) async {
    return _db.transaction(() async {
      final treatment = await getDeletedTreatmentById(treatmentId);
      if (treatment == null) {
        return TreatmentRestoreResult.failure(
          'This treatment was not found or is no longer deleted.',
        );
      }

      final trial = await (_db.select(_db.trials)
            ..where((t) => t.id.equals(treatment.trialId)))
          .getSingleOrNull();
      if (trial == null) {
        return TreatmentRestoreResult.failure(
          'Trial not found. This treatment cannot be restored.',
        );
      }
      if (trial.isDeleted) {
        return TreatmentRestoreResult.failure(
          'Restore the trial from Recovery before restoring this treatment.',
        );
      }
      if (!canEditProtocol(trial)) {
        return TreatmentRestoreResult.failure(protocolEditBlockedMessage(trial));
      }

      final restoredComponentsCount = await (_db
              .update(_db.treatmentComponents)
            ..where((c) =>
                c.treatmentId.equals(treatmentId) & c.isDeleted.equals(true)))
          .write(
        const TreatmentComponentsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await (_db.update(_db.treatments)..where((t) => t.id.equals(treatmentId)))
          .write(
        const TreatmentsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(treatment.trialId),
              eventType: 'TREATMENT_RESTORED',
              description: 'Treatment restored from Recovery',
              performedBy: Value(restoredBy),
              performedByUserId: Value(restoredByUserId),
              metadata: Value(jsonEncode({
                'treatment_name': treatment.name,
                'restored_components_count': restoredComponentsCount,
              })),
            ),
          );

      return TreatmentRestoreResult.ok();
    });
  }

  Future<int> insertComponent({
    required int treatmentId,
    required int trialId,
    required String productName,
    String? rate,
    String? rateUnit,
    String? applicationTiming,
    String? notes,
    int sortOrder = 0,
    double? activeIngredientPct,
    String? formulationType,
    String? manufacturer,
    String? registrationNumber,
    String? eppoCode,
    int? performedByUserId,
  }) async {
    await assertCanEditProtocolForTrialId(_db, trialId);
    return _db.transaction(() async {
      final rowId = await _db.into(_db.treatmentComponents).insert(
            _withComponentLastEdit(
              TreatmentComponentsCompanion.insert(
                treatmentId: treatmentId,
                trialId: trialId,
                productName: productName,
                rate: Value(rate),
                rateUnit: Value(rateUnit),
                applicationTiming: Value(applicationTiming),
                notes: Value(notes),
                sortOrder: Value(sortOrder),
                activeIngredientPct: Value(activeIngredientPct),
                formulationType: Value(formulationType),
                manufacturer: Value(manufacturer),
                registrationNumber: Value(registrationNumber),
                eppoCode: Value(eppoCode),
              ),
              performedByUserId,
            ),
          );
      if (performedByUserId != null) {
        await (_db.update(_db.treatments)..where((t) => t.id.equals(treatmentId)))
            .write(
          _withTreatmentLastEdit(
            const TreatmentsCompanion(),
            performedByUserId,
          ),
        );
      }
      return rowId;
    });
  }

  Future<TreatmentComponent?> _getActiveComponentById(int componentId) {
    return (_db.select(_db.treatmentComponents)
          ..where(
              (c) => c.id.equals(componentId) & c.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<TreatmentComponent?> getDeletedComponentById(int componentId) {
    return (_db.select(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId) & c.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  Future<void> softDeleteComponent(int componentId,
      {String? deletedBy, int? deletedByUserId}) async {
    final row = await _getActiveComponentById(componentId);
    if (row == null) return;
    await assertCanEditProtocolForTrialId(_db, row.trialId);
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.treatmentComponents)
            ..where((c) => c.id.equals(componentId)))
          .write(
        TreatmentComponentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          deletedBy: Value(deletedBy),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(row.trialId),
              eventType: 'TREATMENT_COMPONENT_DELETED',
              description: 'Treatment component soft-deleted',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'product_name': row.productName,
              })),
            ),
          );
    });
  }

  Future<TreatmentComponentRestoreResult> restoreComponent(int componentId,
      {String? restoredBy, int? restoredByUserId}) async {
    return _db.transaction(() async {
      final row = await getDeletedComponentById(componentId);
      if (row == null) {
        return TreatmentComponentRestoreResult.failure(
          'This component was not found or is no longer deleted.',
        );
      }

      final treatment = await (_db.select(_db.treatments)
            ..where((t) => t.id.equals(row.treatmentId)))
          .getSingleOrNull();
      if (treatment == null) {
        return TreatmentComponentRestoreResult.failure(
          'Parent treatment not found.',
        );
      }
      if (treatment.isDeleted) {
        return TreatmentComponentRestoreResult.failure(
          'Restore the treatment from Recovery before restoring this component.',
        );
      }

      final trial = await (_db.select(_db.trials)
            ..where((t) => t.id.equals(row.trialId)))
          .getSingleOrNull();
      if (trial == null) {
        return TreatmentComponentRestoreResult.failure(
          'Trial not found.',
        );
      }
      if (trial.isDeleted) {
        return TreatmentComponentRestoreResult.failure(
          'Restore the trial from Recovery before restoring this component.',
        );
      }
      if (!canEditProtocol(trial)) {
        return TreatmentComponentRestoreResult.failure(
          protocolEditBlockedMessage(trial),
        );
      }

      await (_db.update(_db.treatmentComponents)
            ..where((c) => c.id.equals(componentId)))
          .write(
        const TreatmentComponentsCompanion(
          isDeleted: Value(false),
          deletedAt: Value(null),
          deletedBy: Value(null),
        ),
      );

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(row.trialId),
              eventType: 'TREATMENT_COMPONENT_RESTORED',
              description: 'Treatment component restored from Recovery',
              performedBy: Value(restoredBy),
              performedByUserId: Value(restoredByUserId),
              metadata: Value(jsonEncode({
                'product_name': row.productName,
              })),
            ),
          );

      return TreatmentComponentRestoreResult.ok();
    });
  }
}

class TreatmentNotFoundException implements Exception {
  final int treatmentId;
  TreatmentNotFoundException(this.treatmentId);

  @override
  String toString() => 'Treatment with id $treatmentId not found.';
}

sealed class TreatmentRestoreResult {
  const TreatmentRestoreResult();

  factory TreatmentRestoreResult.ok() = TreatmentRestoreOk;

  factory TreatmentRestoreResult.failure(String reason) =
      TreatmentRestoreFailure;
}

final class TreatmentRestoreOk extends TreatmentRestoreResult {
  const TreatmentRestoreOk();
}

final class TreatmentRestoreFailure extends TreatmentRestoreResult {
  const TreatmentRestoreFailure(this.reason);

  final String reason;
}

sealed class TreatmentComponentRestoreResult {
  const TreatmentComponentRestoreResult();

  factory TreatmentComponentRestoreResult.ok() =
      TreatmentComponentRestoreOk;

  factory TreatmentComponentRestoreResult.failure(String reason) =
      TreatmentComponentRestoreFailure;
}

final class TreatmentComponentRestoreOk
    extends TreatmentComponentRestoreResult {
  const TreatmentComponentRestoreOk();
}

final class TreatmentComponentRestoreFailure
    extends TreatmentComponentRestoreResult {
  const TreatmentComponentRestoreFailure(this.reason);

  final String reason;
}
