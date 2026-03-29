import 'arm_column_classification.dart';
import 'assessment_token.dart';
import 'unknown_pattern_flag.dart';
import '../enums/import_confidence.dart';

class ParsedArmCsv {
  final String sourceFileName;
  final String sourceRoute;
  final String? armVersionHint;
  final List<String> rawHeaders;
  final List<String> columnOrder;
  final List<ArmColumnClassification> columns;
  final List<Map<String, String?>> dataRows;
  final List<AssessmentToken> assessments;
  final List<UnknownPatternFlag> unknownPatterns;
  final bool hasSubsamples;
  final bool hasMultiApplication;
  final bool hasSparseData;
  final bool hasRepeatedCodes;
  final ImportConfidence importConfidence;

  const ParsedArmCsv({
    required this.sourceFileName,
    required this.sourceRoute,
    required this.armVersionHint,
    required this.rawHeaders,
    required this.columnOrder,
    required this.columns,
    required this.dataRows,
    required this.assessments,
    required this.unknownPatterns,
    required this.hasSubsamples,
    required this.hasMultiApplication,
    required this.hasSparseData,
    required this.hasRepeatedCodes,
    required this.importConfidence,
  });
}
