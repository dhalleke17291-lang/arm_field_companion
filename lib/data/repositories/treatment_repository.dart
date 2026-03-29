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
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Stream<List<Treatment>> watchTreatmentsForTrial(int trialId) {
    return (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .watch();
  }

  Future<Treatment?> getTreatmentById(int id) {
    return (_db.select(_db.treatments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Treatment?> getTreatmentForPlot(int plotPk) async {
    // Plot → Assignment → Treatment (ARM resolution)
    if (_assignmentRepository != null) {
      final a = await _assignmentRepository!.getForPlot(plotPk);
      if (a != null && a.treatmentId != null) {
        return getTreatmentById(a.treatmentId!);
      }
    }
    // Fallback: legacy Plot.treatmentId
    final plot = await (_db.select(_db.plots)
          ..where((p) => p.id.equals(plotPk) & p.isDeleted.equals(false)))
        .getSingleOrNull();
    if (plot == null || plot.treatmentId == null) return null;
    return getTreatmentById(plot.treatmentId!);
  }

  Future<List<TreatmentComponent>> getComponentsForTreatment(int treatmentId) {
    return (_db.select(_db.treatmentComponents)
          ..where((c) => c.treatmentId.equals(treatmentId))
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
          ),
        );
  }

  Future<void> updateTreatment(
    int id, {
    String? code,
    String? name,
    String? description,
    String? treatmentType,
    String? timingCode,
    String? eppoCode,
  }) async {
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
      ),
    );
  }

  /// Deletes treatment and its components; clears plot/assignment references.
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
  }) {
    return _db.into(_db.treatmentComponents).insert(
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
        );
  }

  Future<void> deleteComponent(int componentId) async {
    await (_db.delete(_db.treatmentComponents)
          ..where((c) => c.id.equals(componentId)))
        .go();
  }
}

class TreatmentNotFoundException implements Exception {
  final int treatmentId;
  TreatmentNotFoundException(this.treatmentId);

  @override
  String toString() => 'Treatment with id $treatmentId not found.';
}
