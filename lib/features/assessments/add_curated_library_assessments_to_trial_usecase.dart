import '../../data/repositories/assessment_definition_repository.dart';
import '../../data/repositories/trial_assessment_repository.dart';
import '../trials/assessment_library_system_map.dart';
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
    for (var i = 0; i < selections.length; i++) {
      final entry = selections[i];
      if (skipLibraryEntryIds.contains(entry.id)) continue;
      final code = curatedLibraryAssessmentDefinitionCode(
        trialId: trialId,
        libraryEntryId: entry.id,
        disambiguator: i,
      );
      Future<int> insertCustomDefinition() {
        return _definitionRepository.insertCustom(
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
      }

      final systemCode = canonicalSystemAssessmentCode(
        libraryEntryId: entry.id,
        name: entry.name,
        dataType: entry.dataType,
        unit: entry.unit.isEmpty ? null : entry.unit,
        scaleMin: entry.scaleMin,
        scaleMax: entry.scaleMax,
        category: entry.category,
      );
      final systemDef = systemCode != null
          ? await _definitionRepository.getByCode(systemCode)
          : null;
      final defId = systemDef?.id ?? await insertCustomDefinition();
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
