import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/trial_purpose_repository.dart';
import 'mode_c_revelation_model.dart';
import 'trial_intent_inferrer.dart';

/// Reads trial structure from the DB and writes [TrialPurposes] rows.
///
/// ARM import path: writes an immediately-confirmed row with fields derived
/// from the ARM metadata. No claim is fabricated; claimBeingTested is null.
///
/// Standalone wizard path: writes a draft row via the pure inferrer.
class TrialIntentSeeder {
  TrialIntentSeeder(this._db, this._purposeRepo);

  final AppDatabase _db;
  final TrialPurposeRepository _purposeRepo;

  // ---------------------------------------------------------------------------
  // ARM import — confirmed seed
  // ---------------------------------------------------------------------------

  /// Seeds an immediately-confirmed [TrialPurposes] row from ARM structure.
  ///
  /// Guard: skips if a confirmed row already exists for [trialId].
  /// A draft-only row does NOT block seeding — the ARM import replaces it with
  /// a confirmed row derived from the actual ARM metadata.
  Future<void> seedFromArmImportConfirmed(int trialId) async {
    final confirmed = await _purposeRepo.getConfirmedTrialPurpose(trialId);
    if (confirmed != null) return;

    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingleOrNull();
    if (trial == null) return;

    final taRows = await (_db.select(_db.trialAssessments)
          ..where(
            (ta) => ta.trialId.equals(trialId) & ta.isActive.equals(true),
          ))
        .get();

    final treatmentRows = await (_db.select(_db.treatments)
          ..where(
            (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false),
          ))
        .get();

    final primaryEndpoint = await _armPrimaryEndpoint(taRows);
    final treatmentSummary = await _armTreatmentSummary(treatmentRows);
    final metaJson =
        '{"source":"arm_import","assessmentCount":${taRows.length},"treatmentCount":${treatmentRows.length}}';

    await _purposeRepo.createInitialTrialPurpose(
      trialId: trialId,
      status: 'confirmed',
      requiresConfirmation: 0,
      sourceMode: TrialPurposeSourceMode.armStructure,
      claimBeingTested: null,
      trialPurpose: trial.workspaceType,
      regulatoryContext: null,
      primaryEndpoint: primaryEndpoint,
      treatmentRoleSummary: treatmentSummary.isEmpty ? null : treatmentSummary,
      knownInterpretationFactors: null,
      inferredFieldsJson: metaJson,
    );
  }

  /// First ARM assessment (by armImportColumnIndex) formatted as "Name (unit)".
  /// Returns null when no ARM assessment metadata exists for this trial.
  Future<String?> _armPrimaryEndpoint(List<TrialAssessment> taRows) async {
    if (taRows.isEmpty) return null;

    final taIds = taRows.map((ta) => ta.id).toList();
    final aamRows = await (_db.select(_db.armAssessmentMetadata)
          ..where((a) => a.trialAssessmentId.isIn(taIds)))
        .get();
    if (aamRows.isEmpty) return null;

    aamRows.sort((a, b) =>
        (a.armImportColumnIndex ?? 999).compareTo(b.armImportColumnIndex ?? 999));
    final first = aamRows.first;

    final matchingTa =
        taRows.where((ta) => ta.id == first.trialAssessmentId).firstOrNull;
    if (matchingTa == null) return null;

    final defRows = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.equals(matchingTa.assessmentDefinitionId)))
        .get();

    final name = matchingTa.displayNameOverride ??
        (defRows.isNotEmpty ? defRows.first.name : null);
    if (name == null) return null;

    final unit = first.ratingUnit;
    return (unit != null && unit.isNotEmpty) ? '$name ($unit)' : name;
  }

  /// Treatment names joined by comma, ordered by ARM row sort order.
  Future<String> _armTreatmentSummary(List<Treatment> treatmentRows) async {
    if (treatmentRows.isEmpty) return '';

    final treatmentIds = treatmentRows.map((t) => t.id).toList();
    final atmRows = await (_db.select(_db.armTreatmentMetadata)
          ..where((a) => a.treatmentId.isIn(treatmentIds)))
        .get();

    if (atmRows.isNotEmpty) {
      final sortOrderById = {
        for (final a in atmRows) a.treatmentId: a.armRowSortOrder ?? 999,
      };
      final sorted = treatmentRows
          .where((t) => sortOrderById.containsKey(t.id))
          .toList()
        ..sort((a, b) =>
            sortOrderById[a.id]!.compareTo(sortOrderById[b.id]!));
      if (sorted.isNotEmpty) return sorted.map((t) => t.name).join(', ');
    }

    return treatmentRows.map((t) => t.name).join(', ');
  }

  // ---------------------------------------------------------------------------
  // Standalone wizard — inferred draft seed
  // ---------------------------------------------------------------------------

  Future<void> seedIfNeeded(int trialId, String sourceMode) async {
    final existing = await _purposeRepo.getCurrentTrialPurpose(trialId);
    if (existing != null) return;

    final trial = await (_db.select(_db.trials)
          ..where((t) => t.id.equals(trialId)))
        .getSingleOrNull();
    if (trial == null) return;

    final treatmentRows = await (_db.select(_db.treatments)
          ..where(
            (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false),
          ))
        .get();

    final treatments = treatmentRows
        .map((t) => TreatmentInferenceData(
              id: t.id,
              name: t.name,
              code: t.code,
              treatmentType: t.treatmentType,
            ))
        .toList();

    final assessments = await _readAssessments(trialId);

    final input = TrialInferenceInput(
      workspaceType: trial.workspaceType,
      crop: trial.crop,
      treatments: treatments,
      assessments: assessments,
      inferenceSource: sourceMode,
    );

    final inferred = inferTrialPurpose(input);

    await _purposeRepo.createInferredTrialPurpose(
      trialId: trialId,
      inferred: inferred,
      sourceMode: sourceMode,
    );
  }

  Future<List<AssessmentInferenceData>> _readAssessments(int trialId) async {
    final taRows = await (_db.select(_db.trialAssessments)
          ..where(
            (ta) => ta.trialId.equals(trialId) & ta.isActive.equals(true),
          ))
        .get();
    if (taRows.isEmpty) return const [];

    final defIds = taRows.map((ta) => ta.assessmentDefinitionId).toList();
    final defRows = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.isIn(defIds)))
        .get();
    final defById = {for (final d in defRows) d.id: d};

    final aamRows = await (_db.select(_db.armAssessmentMetadata)
          ..where(
            (a) => a.trialAssessmentId.isIn(taRows.map((t) => t.id).toList()),
          ))
        .get();
    final pestCodeByTaId = {
      for (final a in aamRows)
        if (a.pestCode != null) a.trialAssessmentId: a.pestCode!,
    };

    return taRows.map((ta) {
      final def = defById[ta.assessmentDefinitionId];
      return AssessmentInferenceData(
        name: ta.displayNameOverride ?? def?.name ?? 'Assessment',
        eppoCode: def?.eppoCode,
        pestCode: pestCodeByTaId[ta.id],
        daysAfterTreatment: def?.daysAfterTreatment,
        timingCode: def?.timingCode,
        definitionCategory: def?.category,
      );
    }).toList();
  }
}

/// Convenience wrappers for each call site.
extension TrialIntentSeederExt on TrialIntentSeeder {
  Future<void> seedFromStandaloneWizard(int trialId) =>
      seedIfNeeded(trialId, TrialPurposeSourceMode.standaloneStructure);
}
