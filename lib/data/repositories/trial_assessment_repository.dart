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

  /// Applies ARM Rating Shell metadata on one trial assessment without
  /// [assertCanEditProtocolForTrialId]. Never modifies [armImportColumnIndex].
  ///
  /// Only non-empty [shell*] values are applied. Empty shell strings are ignored.
  /// Non-empty existing values are not replaced by empty shell values (callers
  /// should omit empty keys).
  /// Returns whether any column was written.
  Future<bool> applyArmShellLinkFields({
    required int id,
    String? pestCode,
    String? armShellColumnId,
    String? armShellRatingDate,
    String? seName,
    String? seDescription,
    String? armRatingType,
  }) async {
    final existing = await getById(id);
    if (existing == null) return false;

    String? mergePest(String? incoming) {
      if (incoming == null) return null;
      final s = incoming.trim();
      if (s.isEmpty) return null;
      final e = existing.pestCode?.trim() ?? '';
      if (e.isNotEmpty && e.toUpperCase() == s.toUpperCase()) return null;
      return s;
    }

    String? mergeText(String? current, String? incoming) {
      if (incoming == null) return null;
      final s = incoming.trim();
      if (s.isEmpty) return null;
      final c = current?.trim() ?? '';
      if (c.isNotEmpty && c == s) return null;
      return s;
    }

    final nextPest = mergePest(pestCode);
    final nextColId = mergeText(existing.armShellColumnId, armShellColumnId);
    final nextRatingDate =
        mergeText(existing.armShellRatingDate, armShellRatingDate);
    final nextSeName = mergeText(existing.seName, seName);
    final nextSeDesc = mergeText(existing.seDescription, seDescription);
    final nextRatingType = mergeText(existing.armRatingType, armRatingType);

    final companion = TrialAssessmentsCompanion(
      pestCode:
          nextPest == null ? const Value.absent() : Value(nextPest),
      armShellColumnId:
          nextColId == null ? const Value.absent() : Value(nextColId),
      armShellRatingDate: nextRatingDate == null
          ? const Value.absent()
          : Value(nextRatingDate),
      seName: nextSeName == null ? const Value.absent() : Value(nextSeName),
      seDescription:
          nextSeDesc == null ? const Value.absent() : Value(nextSeDesc),
      armRatingType: nextRatingType == null
          ? const Value.absent()
          : Value(nextRatingType),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    final touched = nextPest != null ||
        nextColId != null ||
        nextRatingDate != null ||
        nextSeName != null ||
        nextSeDesc != null ||
        nextRatingType != null;
    if (!touched) return false;

    await (_db.update(_db.trialAssessments)..where((t) => t.id.equals(id)))
        .write(companion);
    return true;
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
    /// ARM assessment code (e.g. CONTRO, AVEFA); stored in [TrialAssessments.pestCode].
    String? pestCode,
    int? armImportColumnIndex,
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
            pestCode: Value(pestCode),
            armImportColumnIndex: Value(armImportColumnIndex),
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
