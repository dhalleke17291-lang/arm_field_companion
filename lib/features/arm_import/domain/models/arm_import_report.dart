import '../enums/import_confidence.dart';
import 'unknown_pattern_flag.dart';

class ArmImportReport {
  final ImportConfidence confidence;
  final int plotsDetected;
  final int treatmentsDetected;
  final int assessmentsDetected;
  final String sourceRoute;
  final String? armVersionHint;
  final List<String> warnings;
  final List<UnknownPatternFlag> unknownPatterns;
  final String exportStatus;

  const ArmImportReport({
    required this.confidence,
    required this.plotsDetected,
    required this.treatmentsDetected,
    required this.assessmentsDetected,
    required this.sourceRoute,
    required this.armVersionHint,
    required this.warnings,
    required this.unknownPatterns,
    required this.exportStatus,
  });
}
