/// Protocol import CSV format (Charter PART 15–16).
///
/// First row = headers. One column must be [section] with values:
/// - TRIAL (exactly one row: trial_name, crop?, location?, season?)
/// - TREATMENT (code, name, description?)
/// - PLOT (plot_id, rep?, row?, column?, plot_sort_index?, treatment_code?)
///
/// treatment_code in PLOT rows references TREATMENT.code for assignment.
const String kProtocolSectionColumn = 'section';
const String kSectionTrial = 'TRIAL';
const String kSectionTreatment = 'TREATMENT';
const String kSectionPlot = 'PLOT';

/// Per-section review (four categories).
class SectionReview {
  final int matchedCount;
  final List<String> autoHandled;
  final List<String> needsReview;
  final List<String> mustFix;

  const SectionReview({
    required this.matchedCount,
    this.autoHandled = const [],
    this.needsReview = const [],
    this.mustFix = const [],
  });

  bool get canProceed => mustFix.isEmpty;
}

/// Full protocol import review (Charter PART 16).
class ProtocolImportReviewResult {
  final SectionReview trialSection;
  final SectionReview treatmentSection;
  final SectionReview plotSection;
  final SectionReview assignmentSection;

  /// Normalized trial row (single), or null if missing/invalid.
  final Map<String, dynamic>? normalizedTrial;

  /// Normalized treatment rows (code, name, description).
  final List<Map<String, dynamic>> normalizedTreatments;

  /// Normalized plot rows (plot_id, rep, row, column, plot_sort_index, treatment_code).
  final List<Map<String, dynamic>> normalizedPlots;

  const ProtocolImportReviewResult({
    required this.trialSection,
    required this.treatmentSection,
    required this.plotSection,
    required this.assignmentSection,
    this.normalizedTrial,
    this.normalizedTreatments = const [],
    this.normalizedPlots = const [],
  });

  bool get canProceed =>
      trialSection.canProceed &&
      treatmentSection.canProceed &&
      plotSection.canProceed &&
      assignmentSection.canProceed &&
      (normalizedTrial != null ||
          normalizedTreatments.isNotEmpty ||
          normalizedPlots.isNotEmpty);
}

/// Result of executing protocol import.
class ProtocolImportExecuteResult {
  final bool success;
  final int? trialId;
  final int treatmentsImported;
  final int plotsImported;
  final String? errorMessage;

  const ProtocolImportExecuteResult._({
    required this.success,
    this.trialId,
    this.treatmentsImported = 0,
    this.plotsImported = 0,
    this.errorMessage,
  });

  factory ProtocolImportExecuteResult.ok({
    required int trialId,
    required int treatmentsImported,
    required int plotsImported,
  }) =>
      ProtocolImportExecuteResult._(
        success: true,
        trialId: trialId,
        treatmentsImported: treatmentsImported,
        plotsImported: plotsImported,
      );

  factory ProtocolImportExecuteResult.failure(String message) =>
      ProtocolImportExecuteResult._(success: false, errorMessage: message);
}
