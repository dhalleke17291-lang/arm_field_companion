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

  /// First trial assessment for this trial and library definition, if any.
  Future<TrialAssessment?> getByTrialAndDefinition(
    int trialId,
    int assessmentDefinitionId,
  ) async {
    return (_db.select(_db.trialAssessments)
          ..where((t) =>
              t.trialId.equals(trialId) &
              t.assessmentDefinitionId.equals(assessmentDefinitionId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Persists [Assessments.id] on the trial assessment row (ARM import / shell export).
  /// Does not use [assertCanEditProtocolForTrialId] — required after [markTrialAsArmLinked]
  /// when protocol edits are blocked.
  Future<void> updateLegacyAssessmentId(
    int taId,
    int legacyAssessmentId,
  ) async {
    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(taId)))
        .write(
      TrialAssessmentsCompanion(
        legacyAssessmentId: Value(legacyAssessmentId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Add a library definition to this trial (manual or protocol-driven).
  ///
  /// The ARM assessment code (pestCode) and ARM SE name / description /
  /// rating type live on [ArmAssessmentMetadata]; callers that need to
  /// persist an ARM code must insert the AAM row themselves. Unit 5d
  /// removed the four duplicate ARM columns from [TrialAssessments].
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
    /// Optional machine tag (e.g. curated library source id); not shown in rating UI.
    String? instructionOverride,
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
            instructionOverride: Value(instructionOverride),
          ),
        );
  }

  /// One protocol check, then many trial-assessment rows (e.g. shell import).
  Future<void> insertTrialAssessmentsBulk(
    List<TrialAssessmentsCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    final trialIds = <int>{};
    for (final r in rows) {
      if (!r.trialId.present) {
        throw StateError('Each companion must include trialId');
      }
      trialIds.add(r.trialId.value);
    }
    if (trialIds.length != 1) {
      throw StateError('insertTrialAssessmentsBulk requires one trial');
    }
    await assertCanEditProtocolForTrialId(_db, trialIds.single);
    for (final row in rows) {
      await _db.into(_db.trialAssessments).insert(row);
    }
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

  /// Legacy [Assessments.id] for this row: stored [TrialAssessment.legacyAssessmentId],
  /// else a row named `"$displayName — TA$id"` for this trial (after [getOrCreateLegacyAssessmentIdsForTrialAssessments]).
  Future<int?> resolveLegacyAssessmentId(TrialAssessment ta) async {
    if (ta.legacyAssessmentId != null) return ta.legacyAssessmentId;
    final def = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.equals(ta.assessmentDefinitionId)))
        .getSingleOrNull();
    if (def == null) return null;
    final displayName = ta.displayNameOverride ?? def.name;
    final uniqueName = '$displayName — TA${ta.id}';
    final existing = await (_db.select(_db.assessments)
          ..where(
              (a) => a.trialId.equals(ta.trialId) & a.name.equals(uniqueName)))
        .getSingleOrNull();
    return existing?.id;
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
      await (_db.update(_db.trialAssessments)
            ..where((t) => t.id.equals(taId)))
          .write(TrialAssessmentsCompanion(legacyAssessmentId: Value(id)));
      result.add(id);
    }
    return result;
  }
}
