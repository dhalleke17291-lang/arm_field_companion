import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/trial_state.dart';

/// Trial-specific selection from the assessment library.
/// Sessions only show assessments enabled here (or legacy Assessments).
class TrialAssessmentRepository {
  final AppDatabase _db;

  TrialAssessmentRepository(this._db);

  /// All trial assessments for a trial (joined with definition for display).
  Future<List<TrialAssessment>> getForTrial(int trialId) async {
    return (_db.select(_db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id)
          ]))
        .get();
  }

  Stream<List<TrialAssessment>> watchForTrial(int trialId) {
    return (_db.select(_db.trialAssessments)
          ..where((t) => t.trialId.equals(trialId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id)
          ]))
        .watch();
  }

  /// Trial assessments for trial with definition joined (for display).
  Stream<List<(TrialAssessment, AssessmentDefinition)>>
      watchForTrialWithDefinitions(int trialId) async* {
    await for (final list in watchForTrial(trialId)) {
      final pairs = <(TrialAssessment, AssessmentDefinition)>[];
      for (final ta in list) {
        final def = await (_db.select(_db.assessmentDefinitions)
              ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
            .getSingleOrNull();
        if (def != null) pairs.add((ta, def));
      }
      yield pairs;
    }
  }

  /// Trial assessment by id.
  Future<TrialAssessment?> getById(int id) async {
    return (_db.select(_db.trialAssessments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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
    await assertCanEditProtocolForTrialId(_db, trialId);
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
    final existing = await getById(id);
    if (existing == null) return;
    await assertCanEditProtocolForTrialId(_db, existing.trialId);

    final companion = TrialAssessmentsCompanion(
      id: Value(id),
      displayNameOverride: displayNameOverride == null
          ? const Value.absent()
          : Value(displayNameOverride),
      required: required_ == null ? const Value.absent() : Value(required_),
      defaultInSessions: defaultInSessions == null
          ? const Value.absent()
          : Value(defaultInSessions),
      sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
      timingMode: timingMode == null ? const Value.absent() : Value(timingMode),
      daysAfterPlanting: daysAfterPlanting == null
          ? const Value.absent()
          : Value(daysAfterPlanting),
      daysAfterTreatment: daysAfterTreatment == null
          ? const Value.absent()
          : Value(daysAfterTreatment),
      growthStage:
          growthStage == null ? const Value.absent() : Value(growthStage),
      methodOverride:
          methodOverride == null ? const Value.absent() : Value(methodOverride),
      instructionOverride: instructionOverride == null
          ? const Value.absent()
          : Value(instructionOverride),
      isActive: isActive == null ? const Value.absent() : Value(isActive),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<void> setSortOrder(int id, int sortOrder) async {
    final existing = await getById(id);
    if (existing == null) return;
    await assertCanEditProtocolForTrialId(_db, existing.trialId);

    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(id)))
        .write(
      TrialAssessmentsCompanion(
          sortOrder: Value(sortOrder),
          updatedAt: Value(DateTime.now().toUtc())),
    );
  }

  Future<void> delete(int id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await assertCanEditProtocolForTrialId(_db, existing.trialId);

    await (_db.delete(_db.trialAssessments)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Whether this trial already has this definition (avoid duplicate add).
  Future<bool> hasDefinitionForTrial(
      int trialId, int assessmentDefinitionId) async {
    final r = await (_db.select(_db.trialAssessments)
          ..where((t) =>
              t.trialId.equals(trialId) &
              t.assessmentDefinitionId.equals(assessmentDefinitionId)))
        .getSingleOrNull();
    return r != null;
  }

  /// Resolves trial assessment IDs to legacy Assessment IDs for session creation.
  /// Creates legacy Assessment rows (with unique name "DisplayName — TA{id}") when needed.
  Future<List<int>> getOrCreateLegacyAssessmentIdsForTrialAssessments(
    int trialId,
    List<int> trialAssessmentIds,
  ) async {
    if (trialAssessmentIds.isEmpty) return [];
    final result = <int>[];
    for (final taId in trialAssessmentIds) {
      final ta = await getById(taId);
      if (ta == null || ta.trialId != trialId) continue;
      final defs = await (_db.select(_db.assessmentDefinitions)
            ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
          .get();
      final def = defs.isNotEmpty ? defs.single : null;
      if (def == null) continue;
      final displayName = ta.displayNameOverride ?? def.name;
      final uniqueName = "$displayName — TA$taId";
      final existing = await (_db.select(_db.assessments)
            ..where(
                (a) => a.trialId.equals(trialId) & a.name.equals(uniqueName)))
          .getSingleOrNull();
      if (existing != null) {
        result.add(existing.id);
        continue;
      }
      final id = await _db.into(_db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: uniqueName,
              dataType: Value(def.dataType),
              unit: Value(def.unit),
              minValue: Value(def.scaleMin),
              maxValue: Value(def.scaleMax),
            ),
          );
      result.add(id);
    }
    return result;
  }
}
