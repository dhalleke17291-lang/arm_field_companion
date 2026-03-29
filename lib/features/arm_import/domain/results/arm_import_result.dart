import '../enums/import_confidence.dart';
import '../models/unknown_pattern_flag.dart';

/// Outcome of an ARM CSV import run (execute path). Scaffolded like
/// [ProtocolImportExecuteResult] in `protocol_import_models.dart`.
class ArmImportResult {
  const ArmImportResult._({
    required this.success,
    this.trialId,
    required this.confidence,
    this.errorMessage,
    this.warnings = const [],
    this.unknownPatterns = const [],
  });

  final bool success;
  final int? trialId;
  final ImportConfidence confidence;
  final String? errorMessage;
  final List<String> warnings;
  final List<UnknownPatternFlag> unknownPatterns;

  factory ArmImportResult.success({
    int? trialId,
    ImportConfidence confidence = ImportConfidence.high,
    List<String> warnings = const [],
    List<UnknownPatternFlag> unknownPatterns = const [],
  }) {
    return ArmImportResult._(
      success: true,
      trialId: trialId,
      confidence: confidence,
      warnings: warnings,
      unknownPatterns: unknownPatterns,
    );
  }

  factory ArmImportResult.failure(
    String message, {
    ImportConfidence confidence = ImportConfidence.blocked,
    List<String> warnings = const [],
    List<UnknownPatternFlag> unknownPatterns = const [],
  }) {
    return ArmImportResult._(
      success: false,
      confidence: confidence,
      errorMessage: message,
      warnings: warnings,
      unknownPatterns: unknownPatterns,
    );
  }
}
