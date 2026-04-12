import 'unknown_pattern_flag.dart';

/// Result of resolving [AssessmentToken]s to [AssessmentDefinition] ids (no trial rows).
class ResolvedArmAssessmentDefinitions {
  const ResolvedArmAssessmentDefinitions({
    required this.assessmentKeyToDefinitionId,
    this.warnings = const [],
    this.unknownPatterns = const [],
  });

  final Map<String, int> assessmentKeyToDefinitionId;
  final List<String> warnings;
  final List<UnknownPatternFlag> unknownPatterns;
}
