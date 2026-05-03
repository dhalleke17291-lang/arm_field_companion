import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';
import 'assignment_repository.dart';

class TreatmentRepository {
  final AppDatabase _db;
  final AssignmentRepository? _assignmentRepository;

  TreatmentRepository(this._db, [this._assignmentRepository]);

  Future<List<Treatment>> getTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where(
              (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Stream<List<Treatment>> watchTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where(
              (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .watch();
  }

  Future<Treatment?> getTreatmentById(int id) {
    return (_db.select(_db.treatments)..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Returns a non-deleted treatment that belongs to [trialId].
  Future<Treatment?> getTreatmentForTrial(
      int treatmentId, int trialId) async {
    return (_db.select(_db.treatments)
          ..where((t) =>
              t.id.equals(treatmentId) &
              t.trialId.equals(trialId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<Treatment?> getTreatmentForPlot(int plotPk) async {
    if (_assignmentRepository != null) {
      final a = await _assignmentRepository!.getForPlot(plotPk);
      if (a != null && a.treatmentId != null) {
        return getTreatmentById(a.treatmentId!);
      }
    }
    final plot = await (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk)))
        .getSingleOrNull();
    if (plot == null || plot.treatmentId == null) return null;
    return getTreatmentById(plot.treatmentId!);
  }

  /// Returns just the treatment id for a plot (via assignment or legacy field).
  Future<int?> getEffectiveTreatmentIdForPlot(int plotPk) async {
    if (_assignmentRepository != null) {
      final a = await _assignmentRepository!.getForPlot(plotPk);
      if (a != null && a.treatmentId != null) return a.treatmentId;
    }
    final plot = await (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk)))
        .getSingleOrNull();
    return plot?.treatmentId;
  }

  Future<List<TreatmentComponent>> getComponentsForTreatment(
      int treatmentId) {
    return (_db.select(_db.treatmentComponents)
          ..where((c) =>
              c.treatmentId.equals(treatmentId) & c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Looks up the trialId for a treatment by id.
  Future<int?> _trialIdForTreatment(int treatmentId) async {
    final t = await getTreatmentById(treatmentId);
    return t?.trialId;
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
    return _db.into(_db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: code,
            name: name,
            description: Value(description),
            treatmentType: Value(treatmentType),
            timingCode: Value(timingCode),
            eppoCode: Value(eppoCode),
            lastEditedByUserId: Value(performedByUserId),
            lastEditedAt: Value(DateTime.now()),
          ),
        );
  }

  /// One protocol check, then many inserts in a single transaction (e.g. shell import).
  Future<Map<int, int>> insertTreatmentsBulkForNumbers({
    required int trialId,
    required List<int> sortedTrtNumbers,
  }) async {
    await assertCanEditProtocolForTrialId(_db, trialId);
    final now = DateTime.now();
    final result = <int, int>{};
    for (final trt in sortedTrtNumbers) {
      final tid = await _db.into(_db.treatments).insert(
            TreatmentsCompanion.insert(
              trialId: trialId,
              code: '$trt',
              name: 'Treatment $trt',
              lastEditedAt: Value(now),
            ),
          );
      result[trt] = tid;
    }
    return result;
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
    final trialId = await _trialIdForTreatment(id);
    if (trialId != null) await assertCanEditProtocolForTrialId(_db, trialId);
    await (_db.update(_db.treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
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
        lastEditedByUserId: performedByUserId != null
            ? Value(performedByUserId)
            : const Value.absent(),
        lastEditedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes a treatment and its components (sets isDeleted flag).
  Future<void> softDeleteTreatment(
    int id, {
    String? deletedBy,
    int? deletedByUserId,
  }) async {
    final trialId = await _trialIdForTreatment(id);
    if (trialId != null) await assertCanEditProtocolForTrialId(_db, trialId);
    final now = DateTime.now();
    await (_db.update(_db.treatments)..where((t) => t.id.equals(id))).write(
      TreatmentsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ),
    );
    // Soft-delete child components too
    await (_db.update(_db.treatmentComponents)
          ..where((c) => c.treatmentId.equals(id)))
        .write(
      TreatmentComponentsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        deletedBy: Value(deletedBy),
      ),
    );
  }

  /// Soft-deletes a single treatment component.
  Future<void> softDeleteComponent(
    int componentId, {
    String? deletedBy,
    int? deletedByUserId,
  }) async {
    final component = await (_db.select(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId)))
        .getSingleOrNull();
    if (component == null) return;
    await assertCanEditProtocolForTrialId(_db, component.trialId);
    await _db.transaction(() async {
      await (_db.update(_db.treatmentComponents)
            ..where((c) => c.id.equals(componentId)))
          .write(
        TreatmentComponentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          deletedBy: Value(deletedBy),
        ),
      );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(component.trialId),
              eventType: 'TREATMENT_COMPONENT_DELETED',
              description:
                  'Treatment component deleted: ${component.productName}',
              performedBy: Value(deletedBy),
              performedByUserId: Value(deletedByUserId),
              metadata: Value(jsonEncode({
                'component_id': componentId,
                'treatment_id': component.treatmentId,
                'trial_id': component.trialId,
                'product_name': component.productName,
              })),
            ),
          );
    });
  }

  /// Updates a treatment component in-place and records field-level changes
  /// in the audit trail.
  Future<void> updateComponent(
    int componentId, {
    String? productName,
    double? rate,
    String? rateUnit,
    String? applicationTiming,
    String? notes,
    int? sortOrder,
    double? activeIngredientPct,
    String? formulationType,
    String? manufacturer,
    String? registrationNumber,
    String? eppoCode,
    String? activeIngredientName,
    double? aiConcentration,
    String? aiConcentrationUnit,
    double? labelRate,
    String? labelRateUnit,
    bool? isTestProduct,
    String? pesticideCategory,
    int? performedByUserId,
    String? performedBy,
  }) async {
    final old = await (_db.select(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId) & c.isDeleted.equals(false)))
        .getSingleOrNull();
    if (old == null) return;
    await assertCanEditProtocolForTrialId(_db, old.trialId);

    // Build field-level diff for audit metadata.
    final changes = <Map<String, dynamic>>[];
    void diff(String field, dynamic oldVal, dynamic newVal) {
      if (newVal != null && newVal != oldVal) {
        changes.add({'field': field, 'old': oldVal, 'new': newVal});
      }
    }

    diff('productName', old.productName, productName);
    diff('rate', old.rate, rate);
    diff('rateUnit', old.rateUnit, rateUnit);
    diff('applicationTiming', old.applicationTiming, applicationTiming);
    diff('notes', old.notes, notes);
    diff('formulationType', old.formulationType, formulationType);
    diff('manufacturer', old.manufacturer, manufacturer);
    diff('registrationNumber', old.registrationNumber, registrationNumber);
    diff('eppoCode', old.eppoCode, eppoCode);
    diff('activeIngredientName', old.activeIngredientName, activeIngredientName);
    diff('isTestProduct', old.isTestProduct, isTestProduct);
    diff('pesticideCategory', old.pesticideCategory, pesticideCategory);

    await _db.transaction(() async {
      await (_db.update(_db.treatmentComponents)
            ..where((c) => c.id.equals(componentId)))
          .write(TreatmentComponentsCompanion(
        productName: productName != null ? Value(productName) : const Value.absent(),
        rate: rate != null ? Value(rate) : const Value.absent(),
        rateUnit: rateUnit != null ? Value(rateUnit) : const Value.absent(),
        applicationTiming: applicationTiming != null
            ? Value(applicationTiming)
            : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        activeIngredientPct: activeIngredientPct != null
            ? Value(activeIngredientPct)
            : const Value.absent(),
        formulationType: formulationType != null
            ? Value(formulationType)
            : const Value.absent(),
        manufacturer:
            manufacturer != null ? Value(manufacturer) : const Value.absent(),
        registrationNumber: registrationNumber != null
            ? Value(registrationNumber)
            : const Value.absent(),
        eppoCode: eppoCode != null ? Value(eppoCode) : const Value.absent(),
        activeIngredientName: activeIngredientName != null
            ? Value(activeIngredientName)
            : const Value.absent(),
        aiConcentration: aiConcentration != null
            ? Value(aiConcentration)
            : const Value.absent(),
        aiConcentrationUnit: aiConcentrationUnit != null
            ? Value(aiConcentrationUnit)
            : const Value.absent(),
        labelRate: labelRate != null ? Value(labelRate) : const Value.absent(),
        labelRateUnit:
            labelRateUnit != null ? Value(labelRateUnit) : const Value.absent(),
        isTestProduct:
            isTestProduct != null ? Value(isTestProduct) : const Value.absent(),
        pesticideCategory: pesticideCategory != null
            ? Value(pesticideCategory)
            : const Value.absent(),
        lastEditedByUserId: Value(performedByUserId),
        lastEditedAt: Value(DateTime.now()),
      ));

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(old.trialId),
              eventType: 'TREATMENT_COMPONENT_UPDATED',
              description:
                  'Treatment component updated: ${old.productName}',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'component_id': componentId,
                'treatment_id': old.treatmentId,
                'trial_id': old.trialId,
                'changes': changes,
              })),
            ),
          );
    });
  }

  /// Hard-deletes treatment and its components; clears plot/assignment references.
  Future<void> deleteTreatment(int id) async {
    await (_db.delete(_db.treatmentComponents)
          ..where((c) => c.treatmentId.equals(id)))
        .go();
    await (_db.update(_db.assignments)..where((a) => a.treatmentId.equals(id)))
        .write(const AssignmentsCompanion(treatmentId: Value(null)));
    await (_db.update(_db.plots)..where((p) => p.treatmentId.equals(id)))
        .write(const PlotsCompanion(treatmentId: Value(null)));
    await (_db.delete(_db.treatments)..where((t) => t.id.equals(id))).go();
  }

  /// Hard-deletes a single treatment component.
  Future<void> deleteComponent(int componentId) async {
    await (_db.delete(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId)))
        .go();
  }

  // ── Recovery (soft-deleted items) ──

  Future<List<Treatment>> getDeletedTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where(
              (t) => t.trialId.equals(trialId) & t.isDeleted.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Future<Treatment?> getDeletedTreatmentById(int id) {
    return (_db.select(_db.treatments)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  Future<TreatmentRestoreResult> restoreTreatment(
    int treatmentId, {
    String? restoredBy,
    int? restoredByUserId,
  }) async {
    final t = await getDeletedTreatmentById(treatmentId);
    if (t == null) return TreatmentRestoreResult.notFound;
    await (_db.update(_db.treatments)
          ..where((r) => r.id.equals(treatmentId)))
        .write(const TreatmentsCompanion(
      isDeleted: Value(false),
      deletedAt: Value(null),
      deletedBy: Value(null),
    ));
    // Restore child components
    await (_db.update(_db.treatmentComponents)
          ..where((c) => c.treatmentId.equals(treatmentId)))
        .write(const TreatmentComponentsCompanion(
      isDeleted: Value(false),
      deletedAt: Value(null),
      deletedBy: Value(null),
    ));
    return TreatmentRestoreResult.restored;
  }

  Future<TreatmentComponent?> getDeletedComponentById(int componentId) {
    return (_db.select(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId) & c.isDeleted.equals(true)))
        .getSingleOrNull();
  }

  Future<TreatmentComponentRestoreResult> restoreComponent(
    int componentId, {
    String? restoredBy,
    int? restoredByUserId,
  }) async {
    final c = await getDeletedComponentById(componentId);
    if (c == null) return TreatmentComponentRestoreResult.notFound;
    await (_db.update(_db.treatmentComponents)
          ..where((r) => r.id.equals(componentId)))
        .write(const TreatmentComponentsCompanion(
      isDeleted: Value(false),
      deletedAt: Value(null),
      deletedBy: Value(null),
    ));
    return TreatmentComponentRestoreResult.restored;
  }

  Future<int> insertComponent({
    required int treatmentId,
    required int trialId,
    required String productName,
    double? rate,
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
    String? performedBy,
    String? activeIngredientName,
    double? aiConcentration,
    String? aiConcentrationUnit,
    double? labelRate,
    String? labelRateUnit,
    bool? isTestProduct,
    String? pesticideCategory,
  }) async {
    await assertCanEditProtocolForTrialId(_db, trialId);
    return _db.transaction(() async {
      final id = await _db.into(_db.treatmentComponents).insert(
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
              activeIngredientName: Value(activeIngredientName),
              aiConcentration: Value(aiConcentration),
              aiConcentrationUnit: Value(aiConcentrationUnit),
              labelRate: Value(labelRate),
              labelRateUnit: Value(labelRateUnit),
              isTestProduct: Value(isTestProduct ?? false),
              pesticideCategory: Value(pesticideCategory),
              lastEditedByUserId: Value(performedByUserId),
              lastEditedAt: Value(DateTime.now()),
            ),
          );
      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              eventType: 'TREATMENT_COMPONENT_ADDED',
              description:
                  'Treatment component added: $productName',
              performedBy: Value(performedBy),
              performedByUserId: Value(performedByUserId),
              metadata: Value(jsonEncode({
                'component_id': id,
                'treatment_id': treatmentId,
                'trial_id': trialId,
                'product_name': productName,
                'rate': rate,
                'rate_unit': rateUnit,
              })),
            ),
          );
      return id;
    });
  }
}

enum TreatmentRestoreResult { restored, notFound }

enum TreatmentComponentRestoreResult { restored, notFound }

class TreatmentNotFoundException implements Exception {
  final int treatmentId;
  TreatmentNotFoundException(this.treatmentId);

  @override
  String toString() => 'Treatment with id $treatmentId not found.';
}
