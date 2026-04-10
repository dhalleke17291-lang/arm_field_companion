import '../../data/repositories/assessment_definition_repository.dart';
import '../../data/repositories/trial_assessment_repository.dart';
import 'assessment_library.dart';

/// Inserts custom definitions from curated [LibraryAssessment] rows and links them to a trial.
class AddCuratedLibraryAssessmentsToTrialUseCase {
  AddCuratedLibraryAssessmentsToTrialUseCase(
    this._definitionRepository,
    this._trialAssessmentRepository,
  );

  final AssessmentDefinitionRepository _definitionRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;

  /// Adds each entry; skips if [skipLibraryEntryIds] contains the id (already on trial or draft).
  Future<void> execute({
    required int trialId,
    required List<LibraryAssessment> selections,
    Set<String> skipLibraryEntryIds = const {},
  }) async {
    for (final entry in selections) {
      if (skipLibraryEntryIds.contains(entry.id)) continue;
      final code =
          'LIB_${entry.id}_${trialId}_${DateTime.now().microsecondsSinceEpoch}';
      final defId = await _definitionRepository.insertCustom(
        code: code,
        name: entry.name,
        category: entry.category,
        dataType: entry.dataType,
        unit: entry.unit.isEmpty ? null : entry.unit,
        scaleMin: entry.scaleMin,
        scaleMax: entry.scaleMax,
        assessmentMethod: null,
        cropPart: null,
        timingCode: null,
        daysAfterTreatment: null,
        timingDescription: null,
        validMin: null,
        validMax: null,
        eppoCode: null,
      );
      await _trialAssessmentRepository.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
        displayNameOverride: entry.name,
        selectedManually: true,
        instructionOverride: curatedLibraryInstructionTag(entry.id),
      );
    }
  }
}
