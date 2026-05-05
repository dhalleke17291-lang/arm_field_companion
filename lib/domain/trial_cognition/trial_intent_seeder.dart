import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/trial_purpose_repository.dart';
import 'mode_c_revelation_model.dart';
import 'trial_intent_inferrer.dart';

/// Reads trial structure from the DB, calls the pure inferrer, and writes a
/// draft [TrialPurposes] row with [requiresConfirmation] = 1.
///
/// Idempotent: if a [TrialPurposes] row already exists for [trialId] (the
/// researcher already went through Mode C), the method returns without writing.
class TrialIntentSeeder {
  TrialIntentSeeder(this._db, this._purposeRepo);

  final AppDatabase _db;
  final TrialPurposeRepository _purposeRepo;

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

    // ARM: read pest codes from arm_assessment_metadata
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
  Future<void> seedFromArmImport(int trialId) =>
      seedIfNeeded(trialId, TrialPurposeSourceMode.armStructure);

  Future<void> seedFromStandaloneWizard(int trialId) =>
      seedIfNeeded(trialId, TrialPurposeSourceMode.standaloneStructure);
}
