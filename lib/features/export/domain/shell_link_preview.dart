/// Validation / UX severity for ARM shell link preview.
enum ShellLinkIssueSeverity {
  /// Blocks [ArmShellLinkUseCase.apply].
  block,

  /// User may proceed after review.
  warn,

  /// Informational only.
  info,
}

/// Single validation or summary line in a [ShellLinkPreview].
class ShellLinkIssue {
  const ShellLinkIssue({
    required this.severity,
    required this.code,
    required this.message,
  });

  final ShellLinkIssueSeverity severity;
  final String code;
  final String message;
}

/// Trial table field that would change when applying shell metadata.
class ShellTrialFieldChange {
  const ShellTrialFieldChange({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.isFillEmpty,
  });

  /// Logical field (e.g. `name`, `protocolNumber`, `cooperatorName`, `crop`).
  final String fieldName;

  /// Current DB value (may be null / empty).
  final String? oldValue;

  /// Value from shell (non-empty; empty shell cells never produce a change).
  final String newValue;

  /// True when [oldValue] was null or blank.
  final bool isFillEmpty;
}

/// [TrialAssessment] row update proposed from shell column metadata.
class ShellAssessmentFieldChange {
  const ShellAssessmentFieldChange({
    required this.trialAssessmentId,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.isFillEmpty,
  });

  final int trialAssessmentId;

  /// e.g. `pestCode`, `se_name`, `arm_shell_column_id`
  final String fieldName;
  final String? oldValue;
  final String newValue;
  final bool isFillEmpty;
}

/// Shell assessment column with no matching trial assessment.
class ShellUnmatchedShellColumn {
  const ShellUnmatchedShellColumn({
    required this.armColumnId,
    required this.columnLetter,
    required this.columnIndex,
  });

  final String armColumnId;
  final String columnLetter;
  final int columnIndex;
}

/// Trial assessment with no matching shell column.
class ShellUnmatchedTrialAssessment {
  const ShellUnmatchedTrialAssessment({
    required this.trialAssessmentId,
    this.pestCode,
    this.armImportColumnIndex,
  });

  final int trialAssessmentId;
  final String? pestCode;
  final int? armImportColumnIndex;
}

/// Result of [ArmShellLinkUseCase.preview] before any DB writes.
class ShellLinkPreview {
  const ShellLinkPreview({
    required this.issues,
    required this.trialFieldChanges,
    required this.assessmentFieldChanges,
    required this.unmatchedShellColumns,
    required this.unmatchedTrialAssessments,
    required this.matchedAssessmentColumnCount,
    required this.shellFilePath,
    required this.shellFileName,
    required this.shellTitle,
    required this.shellPlotCount,
    required this.trialMatchedPlotCount,
    required this.trialPlotCount,
  });

  final List<ShellLinkIssue> issues;

  final List<ShellTrialFieldChange> trialFieldChanges;
  final List<ShellAssessmentFieldChange> assessmentFieldChanges;
  final List<ShellUnmatchedShellColumn> unmatchedShellColumns;
  final List<ShellUnmatchedTrialAssessment> unmatchedTrialAssessments;

  /// Shell assessment columns that matched at least one TA.
  final int matchedAssessmentColumnCount;

  final String shellFilePath;
  final String shellFileName;

  /// Trial title cell from shell (Plot Data), for confirmation UI.
  final String shellTitle;

  final int shellPlotCount;
  final int trialMatchedPlotCount;
  final int trialPlotCount;

  bool get canApply =>
      !issues.any((i) => i.severity == ShellLinkIssueSeverity.block);

  List<ShellLinkIssue> get blockers =>
      issues.where((i) => i.severity == ShellLinkIssueSeverity.block).toList();

  String get blockerSummary =>
      blockers.map((b) => b.message).join(' ');
}

/// Outcome of [ArmShellLinkUseCase.apply].
class LinkShellResult {
  const LinkShellResult._({
    required this.success,
    this.errorMessage,
    this.preview,
    this.fieldsUpdatedCount,
    this.assessmentsMatchedCount,
    this.totalAssessmentsMatched,
    this.totalAssessmentsUnmatched,
    this.fieldsUpdated,
    this.warningMessages,
  });

  factory LinkShellResult.success({
    required ShellLinkPreview preview,
    required int fieldsUpdatedCount,
    required int assessmentsMatchedCount,
    required int totalAssessmentsMatched,
    required int totalAssessmentsUnmatched,
    required int fieldsUpdated,
    List<String> warningMessages = const [],
  }) {
    return LinkShellResult._(
      success: true,
      preview: preview,
      fieldsUpdatedCount: fieldsUpdatedCount,
      assessmentsMatchedCount: assessmentsMatchedCount,
      totalAssessmentsMatched: totalAssessmentsMatched,
      totalAssessmentsUnmatched: totalAssessmentsUnmatched,
      fieldsUpdated: fieldsUpdated,
      warningMessages: warningMessages,
    );
  }

  factory LinkShellResult.failure(String message) {
    return LinkShellResult._(
      success: false,
      errorMessage: message,
    );
  }

  final bool success;
  final String? errorMessage;
  final ShellLinkPreview? preview;
  final int? fieldsUpdatedCount;
  final int? assessmentsMatchedCount;

  /// Shell column matches (same as [ShellLinkPreview.matchedAssessmentColumnCount]).
  final int? totalAssessmentsMatched;

  /// Trial assessments with no matching shell column.
  final int? totalAssessmentsUnmatched;

  /// Scalar fields written (trial + per-assessment columns).
  final int? fieldsUpdated;

  /// [ShellLinkIssueSeverity.warn] messages from the preview used for apply.
  final List<String>? warningMessages;
}
