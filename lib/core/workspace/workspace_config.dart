// Workspace configuration: trial tabs, exports, and lock policy by workspace type.
// Used after completion of TreatmentComponents UI, bulk assignment, applications,
// and export layer to drive variety / efficacy / GLP behavior.
//
// --- Workspace type string parsing (multiple paths by design) ---
//
// a) [workspaceTypeFromStringOrNull]: tolerant trim/lowercase [byName]; blank or
//    unknown → null. Use when callers need to represent "unrecognized" without
//    picking a preset (e.g. some UI conditions; input to code that applies its
//    own default separately).
//
// b) [safeConfigFromString] (this file): tolerant normalization;
//    unknown or invalid → [WorkspaceConfig.efficacy]. Drives trial detail hub/tabs.
//
// c) [_workspaceTypeForExportList] and [allowedExportFormatsForWorkspace]: tolerant
//    parse; unknown → [WorkspaceType.efficacy] then [WorkspaceConfig.forType] for
//    [availableExports]. Export entry point.
//
// Falling back to efficacy is a safe protocol preset for continuity and stable
// behavior — not semantic truth that the trial is an "efficacy" study.

import 'package:arm_field_companion/features/export/export_format.dart';

enum WorkspaceType { variety, efficacy, glp, standalone }

enum TrialMode {
  standalone,
  protocol,
}

enum StudyType {
  general,
  variety,
  efficacy,
  glp,
}

extension WorkspaceTypeDecomposition on WorkspaceType {
  TrialMode get trialMode {
    switch (this) {
      case WorkspaceType.standalone:
        return TrialMode.standalone;
      case WorkspaceType.variety:
      case WorkspaceType.efficacy:
      case WorkspaceType.glp:
        return TrialMode.protocol;
    }
  }

  StudyType get studyType {
    switch (this) {
      case WorkspaceType.variety:
        return StudyType.variety;
      case WorkspaceType.efficacy:
        return StudyType.efficacy;
      case WorkspaceType.glp:
        return StudyType.glp;
      case WorkspaceType.standalone:
        return StudyType.general;
    }
  }
}

enum TrialTab {
  plots,
  seeding,
  applications,
  assessments,
  treatments,
  photos,
  timeline,
}

enum ProtocolLockPolicy {
  soft, // warnings only, researcher can override
  hard, // locked at Ready, changes require amendment
}

enum MandatorySection {
  seeding,
  applications,
  assessments,
}

class WorkspaceConfig {
  final WorkspaceType type;
  final String displayName;
  final String shortDescription;
  final List<TrialTab> visibleTabs;
  final List<TrialTab> tabOrder;
  final List<ExportFormat> availableExports;
  final ExportFormat primaryExport;
  final ProtocolLockPolicy lockPolicy;
  final List<MandatorySection> requiredSections;
  final bool requireCorrectionReason;
  final bool allowProtocolEditAfterReady;
  final bool requireAmendmentWorkflow;
  final bool showComplianceWarnings;
  final bool csvAllowed;

  bool get isStandalone => type == WorkspaceType.standalone;
  bool get isProtocol => !isStandalone;
  bool get isGlp => type == WorkspaceType.glp;

  TrialMode get mode => type.trialMode;
  StudyType get studyType => type.studyType;

  const WorkspaceConfig({
    required this.type,
    required this.displayName,
    required this.shortDescription,
    required this.visibleTabs,
    required this.tabOrder,
    required this.availableExports,
    required this.primaryExport,
    required this.lockPolicy,
    required this.requiredSections,
    required this.requireCorrectionReason,
    required this.allowProtocolEditAfterReady,
    required this.requireAmendmentWorkflow,
    required this.showComplianceWarnings,
    required this.csvAllowed,
  });

  static const variety = WorkspaceConfig(
    type: WorkspaceType.variety,
    displayName: 'Variety Trials',
    shortDescription: 'Compare crop varieties — yield, grade, standability',
    visibleTabs: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    availableExports: [
      ExportFormat.flatCsv,
      ExportFormat.armHandoff,
      ExportFormat.pdfReport,
      ExportFormat.evidenceReport,
      ExportFormat.trialReport,
      ExportFormat.trialDefensibility,
    ],
    primaryExport: ExportFormat.pdfReport,
    lockPolicy: ProtocolLockPolicy.soft,
    requiredSections: [],
    requireCorrectionReason: false,
    allowProtocolEditAfterReady: true,
    requireAmendmentWorkflow: false,
    showComplianceWarnings: false,
    csvAllowed: true,
  );

  static const efficacy = WorkspaceConfig(
    type: WorkspaceType.efficacy,
    displayName: 'Efficacy Studies',
    shortDescription: 'Test chemical products — dose response, % control',
    visibleTabs: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    availableExports: [
      ExportFormat.flatCsv,
      ExportFormat.armHandoff,
      ExportFormat.pdfReport,
      ExportFormat.evidenceReport,
      ExportFormat.trialReport,
      ExportFormat.trialDefensibility,
    ],
    primaryExport: ExportFormat.armHandoff,
    lockPolicy: ProtocolLockPolicy.soft,
    requiredSections: [
      MandatorySection.applications,
    ],
    requireCorrectionReason: false,
    allowProtocolEditAfterReady: true,
    requireAmendmentWorkflow: false,
    showComplianceWarnings: true,
    csvAllowed: true,
  );

  static const glp = WorkspaceConfig(
    type: WorkspaceType.glp,
    displayName: 'GLP Studies',
    shortDescription: 'Regulated studies — full audit trail, compliant export',
    visibleTabs: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    availableExports: [
      ExportFormat.flatCsv,
      ExportFormat.armHandoff,
      ExportFormat.pdfReport,
      ExportFormat.evidenceReport,
      ExportFormat.trialReport,
      ExportFormat.trialDefensibility,
    ],
    primaryExport: ExportFormat.armHandoff,
    lockPolicy: ProtocolLockPolicy.hard,
    requiredSections: [
      MandatorySection.seeding,
      MandatorySection.applications,
      MandatorySection.assessments,
    ],
    requireCorrectionReason: true,
    allowProtocolEditAfterReady: false,
    requireAmendmentWorkflow: true,
    showComplianceWarnings: true,
    csvAllowed: false,
  );

  static const standalone = WorkspaceConfig(
    type: WorkspaceType.standalone,
    displayName: 'Custom Trial',
    shortDescription:
        'Independent trial — no CSV import required, PDF and CSV report',
    visibleTabs: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.applications,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.applications,
      TrialTab.seeding,
      TrialTab.photos,
      TrialTab.timeline,
    ],
    availableExports: [
      ExportFormat.pdfReport,
      ExportFormat.trialReport,
      ExportFormat.trialDefensibility,
      ExportFormat.flatCsv,
    ],
    primaryExport: ExportFormat.pdfReport,
    lockPolicy: ProtocolLockPolicy.soft,
    requiredSections: [],
    requireCorrectionReason: false,
    allowProtocolEditAfterReady: true,
    requireAmendmentWorkflow: false,
    showComplianceWarnings: false,
    csvAllowed: true,
  );

  static WorkspaceConfig forType(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.variety:
        return variety;
      case WorkspaceType.efficacy:
        return efficacy;
      case WorkspaceType.glp:
        return glp;
      case WorkspaceType.standalone:
        return standalone;
    }
  }
}

/// Parses non-empty [workspaceType] to a known enum, or null if blank/unknown.
/// List filtering ([workspace_filter]) uses this: null means the trial is neither custom nor protocol-only.
WorkspaceType? workspaceTypeFromStringOrNull(String? workspaceType) {
  if (workspaceType == null || workspaceType.trim().isEmpty) return null;
  try {
    return WorkspaceType.values.byName(workspaceType.trim().toLowerCase());
  } catch (_) {
    return null;
  }
}

/// Parses stored workspace type for export rules; unknown values → [WorkspaceType.efficacy]
/// (matches prior [allowedExportFormatsForWorkspace] default branch).
WorkspaceType _workspaceTypeForExportList(String workspaceType) {
  try {
    return WorkspaceType.values.byName(workspaceType.trim().toLowerCase());
  } catch (_) {
    return WorkspaceType.efficacy;
  }
}

/// Returns execution-layer export formats allowed for a trial's workspace type.
/// Single source: [WorkspaceConfig.availableExports] via [WorkspaceConfig.forType].
///
/// Unknown or invalid [workspaceType] strings resolve to the efficacy preset (see
/// [_workspaceTypeForExportList]) so export options stay valid, ARM-oriented paths
/// remain available where configured, and users do not hit empty or broken export
/// flows for bad data.
List<ExportFormat> allowedExportFormatsForWorkspace(String workspaceType) {
  return WorkspaceConfig.forType(_workspaceTypeForExportList(workspaceType))
      .availableExports;
}

/// Trial export sheet: workspace formats, plus [ExportFormat.armRatingShell] only when
/// [isArmLinked] is true (not already in [WorkspaceConfig.availableExports]).
///
/// Non–ARM-linked trials never list ARM Rating Shell, so the sheet matches what
/// [ExportArmRatingShellUseCase] can run.
List<ExportFormat> exportFormatsForTrialSheet(
  String workspaceType, {
  required bool isArmLinked,
}) {
  final allowed = allowedExportFormatsForWorkspace(workspaceType);
  if (!isArmLinked) return allowed;
  if (allowed.contains(ExportFormat.armRatingShell)) return allowed;
  return [...allowed, ExportFormat.armRatingShell];
}

/// Tooltip for the trial detail Export control. ARM-specific options depend on
/// [isArmLinked] only; [workspaceType] selects the non–ARM-linked format bundle.
String exportEntryTooltipMessage(
  String workspaceType, {
  required bool isArmLinked,
}) {
  final config = safeConfigFromString(workspaceType);
  if (isArmLinked) {
    return 'This trial is imported. Export includes CSV, Import Assistant, ZIP with photos, PDF, and Excel Rating Sheet where available.';
  }
  if (config.isStandalone) {
    return 'Export trial data (PDF or CSV bundle). Excel Rating Sheet is only for imported trials.';
  }
  return 'Export trial data (CSV, ZIP with photos, or PDF). Excel Rating Sheet is only for imported trials.';
}

/// Parses a stored [workspaceType] string to a [WorkspaceConfig].
/// In-app creation paths always write 'standalone' or 'efficacy'.
/// This fallback only applies to legacy data, bad imports, or manual DB edits —
/// not normal app usage. Unknown or invalid values fall back to
/// [WorkspaceConfig.efficacy] as a safe protocol preset.
///
/// UI callers must not assume that a fallback result means the trial is
/// genuinely a protocol/efficacy trial — it only means the type was
/// unrecognized. Use config.isStandalone and config.studyType for
/// display decisions, but be aware that unknown types resolve to
/// protocol-like behavior, not standalone.
WorkspaceConfig safeConfigFromString(String stored) {
  try {
    final type = WorkspaceType.values.byName(stored.trim().toLowerCase());
    return WorkspaceConfig.forType(type);
  } catch (_) {
    return WorkspaceConfig.efficacy;
  }
}
