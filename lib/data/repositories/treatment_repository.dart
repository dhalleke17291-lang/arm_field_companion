import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
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
          ..where((p) => p.id.equals(plotPk)))
        .getSingleOrNull();
    if (plot == null || plot.treatmentId == null) return null;
    return getTreatmentById(plot.treatmentId!);
  }

  Future<List<TreatmentComponent>> getComponentsForTreatment(
      int treatmentId) {
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
  }) {
    return _db.into(_db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: code,
            name: name,
            description: Value(description),
          ),
        );
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
          ),
        );
  }
}

class TreatmentNotFoundException implements Exception {
  final int treatmentId;
  TreatmentNotFoundException(this.treatmentId);

  @override
  String toString() => 'Treatment with id $treatmentId not found.';
}
