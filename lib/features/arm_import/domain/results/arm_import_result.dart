import '../enums/import_confidence.dart';
import '../models/unknown_pattern_flag.dart';

/// Outcome of an ARM CSV import run (execute path). Scaffolded like
/// [ProtocolImportExecuteResult] in `protocol_import_models.dart`.
class ArmImportResult {
  const ArmImportResult._({
    required this.success,
    this.trialId,
    this.importSessionId,
    required this.confidence,
    this.errorMessage,
    this.warnings = const [],
    this.unknownPatterns = const [],
    this.duplicateDetected = false,
    this.priorTrialIds = const [],
  });

  final bool success;
  final int? trialId;
  /// Session created (or reused) for later rating import; null when no trial assessments.
  final int? importSessionId;
  final ImportConfidence confidence;
  final String? errorMessage;
  final List<String> warnings;
  final List<UnknownPatternFlag> unknownPatterns;

  /// True when this file's checksum matched a prior [ImportSnapshots.rawFileChecksum] row
  /// before this run completed (structured companion to the duplicate warning string).
  final bool duplicateDetected;

  /// Distinct trial ids that already had a snapshot with this checksum at import time
  /// (excludes the new trial until after the next import sees it).
  final List<int> priorTrialIds;

  factory ArmImportResult.success({
    int? trialId,
    int? importSessionId,
    ImportConfidence confidence = ImportConfidence.high,
    List<String> warnings = const [],
    List<UnknownPatternFlag> unknownPatterns = const [],
    bool duplicateDetected = false,
    List<int> priorTrialIds = const [],
  }) {
    return ArmImportResult._(
      success: true,
      trialId: trialId,
      importSessionId: importSessionId,
      confidence: confidence,
      warnings: warnings,
      unknownPatterns: unknownPatterns,
      duplicateDetected: duplicateDetected,
      priorTrialIds: priorTrialIds,
    );
  }

  factory ArmImportResult.failure(
    String message, {
    ImportConfidence confidence = ImportConfidence.blocked,
    List<String> warnings = const [],
    List<UnknownPatternFlag> unknownPatterns = const [],
    bool duplicateDetected = false,
    List<int> priorTrialIds = const [],
  }) {
    return ArmImportResult._(
      success: false,
      confidence: confidence,
      errorMessage: message,
      warnings: warnings,
      unknownPatterns: unknownPatterns,
      duplicateDetected: duplicateDetected,
      priorTrialIds: priorTrialIds,
    );
  }
}
