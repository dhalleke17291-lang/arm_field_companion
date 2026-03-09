import '../../core/database/app_database.dart';

/// One assessment item shown for a trial: either from the library (TrialAssessment + Definition) or legacy (Assessment).
/// Used by trial "Assessments for this Trial" and later by session assessment picker.
class EffectiveTrialAssessment {
  final bool isFromLibrary;
  final int? assessmentId;
  final int? trialAssessmentId;
  final int? assessmentDefinitionId;
  final String name;
  final String? category;
  final String dataType;
  final double? minValue;
  final double? maxValue;
  final String? unit;
  final bool required_;
  final bool isActive;

  const EffectiveTrialAssessment({
    required this.isFromLibrary,
    this.assessmentId,
    this.trialAssessmentId,
    this.assessmentDefinitionId,
    required this.name,
    this.category,
    required this.dataType,
    this.minValue,
    this.maxValue,
    this.unit,
    this.required_ = false,
    this.isActive = true,
  });

  /// From legacy Assessment (trial-level custom assessment).
  factory EffectiveTrialAssessment.fromLegacy(Assessment a) {
    return EffectiveTrialAssessment(
      isFromLibrary: false,
      assessmentId: a.id,
      name: a.name,
      dataType: a.dataType,
      minValue: a.minValue,
      maxValue: a.maxValue,
      unit: a.unit,
      isActive: a.isActive,
    );
  }

  /// From TrialAssessment + AssessmentDefinition (library selection).
  factory EffectiveTrialAssessment.fromLibrary(TrialAssessment ta, AssessmentDefinition def) {
    return EffectiveTrialAssessment(
      isFromLibrary: true,
      trialAssessmentId: ta.id,
      assessmentDefinitionId: def.id,
      name: ta.displayNameOverride ?? def.name,
      category: def.category,
      dataType: def.dataType,
      minValue: def.scaleMin,
      maxValue: def.scaleMax,
      unit: def.unit,
      required_: ta.required,
      isActive: ta.isActive,
    );
  }
}
