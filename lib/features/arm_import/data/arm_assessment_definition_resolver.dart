import '../../../core/assessment_result_direction.dart';
import '../../../data/repositories/assessment_definition_repository.dart';
import '../domain/models/assessment_token.dart';
import '../domain/models/resolved_arm_assessment_definitions.dart';
import '../domain/models/unknown_pattern_flag.dart';

/// Resolves [AssessmentToken]s to [AssessmentDefinition] ids using stable codes per [assessmentKey].
class ArmAssessmentDefinitionResolver {
  ArmAssessmentDefinitionResolver(this._definitions);

  final AssessmentDefinitionRepository _definitions;

  /// Stable code for DB (max 50 chars per schema).
  static String definitionCodeForAssessmentKey(String assessmentKey) {
    final sanitized =
        assessmentKey.replaceAll(RegExp(r'[^A-Za-z0-9_|]'), '_');
    const prefix = 'ARM_';
    final combined = '$prefix$sanitized';
    if (combined.length <= 50) return combined;
    return combined.substring(0, 50);
  }

  Future<ResolvedArmAssessmentDefinitions> resolveAll({
    required int trialId,
    required List<AssessmentToken> assessments,
  }) async {
    if (trialId <= 0) {
      throw ArgumentError.value(trialId, 'trialId');
    }
    final warnings = <String>[];
    final unknownPatterns = <UnknownPatternFlag>[];
    final map = <String, int>{};

    for (final token in assessments) {
      final key = token.assessmentKey;
      if (map.containsKey(key)) {
        continue;
      }

      final trimmedCode = token.armCode.trim();
      if (trimmedCode.isEmpty) {
        warnings.add('Skipped assessment with empty armCode for key "$key".');
        unknownPatterns.add(UnknownPatternFlag(
          type: 'assessment_definition',
          severity: PatternSeverity.medium,
          affectsExport: true,
          rawValue: token.rawHeader,
        ));
        continue;
      }

      final code = definitionCodeForAssessmentKey(key);
      var def = await _definitions.getByCode(code);
      def ??= await _definitions.getByCode(trimmedCode);

      if (def == null) {
        final name = '${token.armCode.trim()} (${token.timingCode.trim()})';
        final unitStr = token.unit.trim();
        try {
          final id = await _definitions.insertCustom(
            code: code,
            name: name.length > 255 ? name.substring(0, 255) : name,
            category: 'custom',
            dataType: 'numeric',
            unit: unitStr.isEmpty ? null : unitStr,
            scaleMin: _scaleMinForUnit(token.unit),
            scaleMax: _scaleMaxForUnit(token.unit),
            timingCode: token.timingCode.trim().isEmpty
                ? null
                : token.timingCode.trim(),
            resultDirection: AssessmentResultDirection.neutral,
          );
          map[key] = id;
        } catch (e) {
          warnings.add(
              'Could not create assessment definition for key "$key": $e');
          unknownPatterns.add(UnknownPatternFlag(
            type: 'assessment_definition',
            severity: PatternSeverity.high,
            affectsExport: true,
            rawValue: token.rawHeader,
          ));
        }
      } else {
        map[key] = def.id;
      }
    }

    return ResolvedArmAssessmentDefinitions(
      assessmentKeyToDefinitionId: map,
      warnings: warnings,
      unknownPatterns: unknownPatterns,
    );
  }

  static double _scaleMinForUnit(String unit) => 0;

  static double _scaleMaxForUnit(String unit) {
    final u = unit.trim().toUpperCase();
    if (u.isEmpty || u == 'NUMBER') return 9999;
    switch (u) {
      case '%':
        return 100;
      case 'BU/AC':
      case 'T/HA':
      case 'KG/HA':
        return 9999;
      default:
        return 999;
    }
  }
}
