import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class TrialRepository {
  final AppDatabase _db;

  TrialRepository(this._db);

  // Get all trials ordered by most recent
  Stream<List<Trial>> watchAllTrials() {
    return (_db.select(_db.trials)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // Get single trial by id
  Future<Trial?> getTrialById(int id) {
    return (_db.select(_db.trials)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Create new trial — checks for duplicate name first
  Future<int> createTrial({
    required String name,
    String? crop,
    String? location,
    String? season,
  }) async {
    // Duplicate name check — silent overwrite forbidden per spec
    final existing = await (_db.select(_db.trials)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();

    if (existing != null) {
      throw DuplicateTrialException(name);
    }

    return _db.into(_db.trials).insert(
          TrialsCompanion.insert(
            name: name,
            crop: Value(crop),
            location: Value(location),
            season: Value(season),
          ),
        );
  }

  // Update trial
  Future<bool> updateTrial(Trial trial) {
    return _db.update(_db.trials).replace(trial);
  }

  // Get trial with treatment and plot counts
  Future<TrialSummary> getTrialSummary(int trialId) async {
    final trial = await getTrialById(trialId);
    if (trial == null) throw TrialNotFoundException(trialId);

    final plotCount = await (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId)))
        .get()
        .then((list) => list.length);

    final treatmentCount = await (_db.select(_db.treatments)
          ..where((t) => t.trialId.equals(trialId)))
        .get()
        .then((list) => list.length);

    final assessmentCount = await (_db.select(_db.assessments)
          ..where((a) => a.trialId.equals(trialId)))
        .get()
        .then((list) => list.length);

    return TrialSummary(
      trial: trial,
      plotCount: plotCount,
      treatmentCount: treatmentCount,
      assessmentCount: assessmentCount,
    );
  }
}

// ─────────────────────────────────────────────
// VALUE OBJECTS
// ─────────────────────────────────────────────

class TrialSummary {
  final Trial trial;
  final int plotCount;
  final int treatmentCount;
  final int assessmentCount;

  const TrialSummary({
    required this.trial,
    required this.plotCount,
    required this.treatmentCount,
    required this.assessmentCount,
  });
}

// ─────────────────────────────────────────────
// EXCEPTIONS
// ─────────────────────────────────────────────

class DuplicateTrialException implements Exception {
  final String trialName;
  DuplicateTrialException(this.trialName);

  @override
  String toString() =>
      'Trial "$trialName" already exists. Rename or cancel import.';
}

class TrialNotFoundException implements Exception {
  final int trialId;
  TrialNotFoundException(this.trialId);

  @override
  String toString() => 'Trial with id $trialId not found.';
}
