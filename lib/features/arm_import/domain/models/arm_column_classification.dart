import '../enums/arm_column_kind.dart';
import 'assessment_token.dart';

/// One CSV column after header classification (parser fills this in a later step).
class ArmColumnClassification {
  const ArmColumnClassification({
    required this.header,
    required this.kind,
    required this.index,
    this.identityRole,
    this.assessmentToken,
  });

  final String header;
  final ArmColumnKind kind;
  final int index;
  final String? identityRole;
  final AssessmentToken? assessmentToken;
}
