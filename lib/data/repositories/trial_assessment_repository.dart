import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

/// Trial-specific selection from the assessment library.
/// Sessions only show assessments enabled here (or legacy Assessments).
class TrialAssessmentRepository {
  final AppDatabase _db;

  TrialAssessmentRepository(this._db);

  /// All trial assessments for a trial (joined with definition for display).
  Future<List<TrialAssessment>> getForTrial(int trialId) async {
    return (_db.select(_db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Stream<List<TrialAssessment>> watchForTrial(int trialId) {
    return (_db.select(_db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  /// Trial assessments for trial with definition joined (for display).
  Stream<List<(TrialAssessment, AssessmentDefinition)>> watchForTrialWithDefinitions(int trialId) async* {
    await for (final list in watchForTrial(trialId)) {
      final pairs = <(TrialAssessment, AssessmentDefinition)>[];
      for (final ta in list) {
        final def = await (_db.select(_db.assessmentDefinitions)..where((d) => d.id.equals(ta.assessmentDefinitionId))).getSingleOrNull();
        if (def != null) pairs.add((ta, def));
      }
      yield pairs;
    }
  }

  /// Trial assessment by id.
  Future<TrialAssessment?> getById(int id) async {
    return (_db.select(_db.trialAssessments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Add a library definition to this trial (manual or protocol-driven).
  Future<int> addToTrial({
    required int trialId,
    required int assessmentDefinitionId,
    String? displayNameOverride,
    bool required_ = false,
    bool selectedFromProtocol = false,
    bool selectedManually = true,
    bool defaultInSessions = true,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    return _db.into(_db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: assessmentDefinitionId,
            displayNameOverride: Value(displayNameOverride),
            required: Value(required_),
            selectedFromProtocol: Value(selectedFromProtocol),
            selectedManually: Value(selectedManually),
            defaultInSessions: Value(defaultInSessions),
            sortOrder: Value(sortOrder),
            isActive: Value(isActive),
          ),
        );
  }

  /// Update trial-specific settings.
  Future<void> update(
    int id, {
    String? displayNameOverride,
    bool? required_,
    bool? defaultInSessions,
    int? sortOrder,
    String? timingMode,
    int? daysAfterPlanting,
    int? daysAfterTreatment,
    String? growthStage,
    String? methodOverride,
    String? instructionOverride,
    bool? isActive,
  }) async {
    final companion = TrialAssessmentsCompanion(
      id: Value(id),
      displayNameOverride: displayNameOverride == null ? const Value.absent() : Value(displayNameOverride),
      required: required_ == null ? const Value.absent() : Value(required_),
      defaultInSessions: defaultInSessions == null ? const Value.absent() : Value(defaultInSessions),
      sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
      timingMode: timingMode == null ? const Value.absent() : Value(timingMode),
      daysAfterPlanting: daysAfterPlanting == null ? const Value.absent() : Value(daysAfterPlanting),
      daysAfterTreatment: daysAfterTreatment == null ? const Value.absent() : Value(daysAfterTreatment),
      growthStage: growthStage == null ? const Value.absent() : Value(growthStage),
      methodOverride: methodOverride == null ? const Value.absent() : Value(methodOverride),
      instructionOverride: instructionOverride == null ? const Value.absent() : Value(instructionOverride),
      isActive: isActive == null ? const Value.absent() : Value(isActive),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> setSortOrder(int id, int sortOrder) async {
    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(id))).write(
          TrialAssessmentsCompanion(sortOrder: Value(sortOrder), updatedAt: Value(DateTime.now().toUtc())),
        );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.trialAssessments)..where((t) => t.id.equals(id))).go();
  }

  /// Whether this trial already has this definition (avoid duplicate add).
  Future<bool> hasDefinitionForTrial(int trialId, int assessmentDefinitionId) async {
    final r = await (_db.select(_db.trialAssessments)
          ..where((t) =>
              t.trialId.equals(trialId) & t.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .getSingleOrNull();
    return r != null;
  }
}
