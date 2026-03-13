import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Repository for the hidden master assessment library (AssessmentDefinitions).
/// Not used directly in session UI; trials select from here via TrialAssessments.
class AssessmentDefinitionRepository {
  final AppDatabase _db;

  AssessmentDefinitionRepository(this._db);

  /// All active definitions, optionally filtered by category.
  Future<List<AssessmentDefinition>> getAll({
    String? category,
    bool activeOnly = true,
  }) async {
    var query = _db.select(_db.assessmentDefinitions);
    if (activeOnly) {
      query = query..where((d) => d.isActive.equals(true));
    }
    if (category != null && category.isNotEmpty) {
      query = query..where((d) => d.category.equals(category));
    }
    return (query
          ..orderBy([
            (d) => OrderingTerm.asc(d.category),
            (d) => OrderingTerm.asc(d.name)
          ]))
        .get();
  }

  /// Stream of all active definitions (e.g. for library picker).
  Stream<List<AssessmentDefinition>> watchAll({bool activeOnly = true}) {
    var query = _db.select(_db.assessmentDefinitions);
    if (activeOnly) {
      query = query..where((d) => d.isActive.equals(true));
    }
    return (query
          ..orderBy([
            (d) => OrderingTerm.asc(d.category),
            (d) => OrderingTerm.asc(d.name)
          ]))
        .watch();
  }

  Future<AssessmentDefinition?> getById(int id) async {
    return (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Distinct categories present in the library (for grouping the picker).
  Future<List<String>> getCategories() async {
    final rows = await (_db.selectOnly(_db.assessmentDefinitions)
          ..addColumns([_db.assessmentDefinitions.category])
          ..where(_db.assessmentDefinitions.isActive.equals(true)))
        .get();
    final categories = rows
        .map((r) => r.read(_db.assessmentDefinitions.category))
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  /// Create a custom definition (isSystem = false). Used for "custom" assessments.
  Future<int> insertCustom({
    required String code,
    required String name,
    required String category,
    String dataType = 'numeric',
    String? unit,
    double? scaleMin,
    double? scaleMax,
  }) async {
    return _db.into(_db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: code,
            name: name,
            category: category,
            dataType: Value(dataType),
            unit: Value(unit),
            scaleMin: Value(scaleMin),
            scaleMax: Value(scaleMax),
            isSystem: const Value(false),
            isActive: const Value(true),
          ),
        );
  }
}
