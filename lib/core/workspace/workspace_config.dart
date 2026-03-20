// Workspace configuration: trial tabs, exports, and lock policy by workspace type.
// Used after completion of TreatmentComponents UI, bulk assignment, applications,
// and export layer to drive variety / efficacy / GLP behavior.

enum WorkspaceType { variety, efficacy, glp, standalone }

enum TrialTab {
  plots,
  seeding,
  applications,
  assessments,
  treatments,
  photos,
}

enum ExportFormat {
  csv,
  armXml,
  glpPdf,
  efficacyCombined,
  varietyStats,
  standaloneReport,
  standaloneCsv,
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
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
    ],
    availableExports: [
      ExportFormat.csv,
      ExportFormat.varietyStats,
    ],
    primaryExport: ExportFormat.varietyStats,
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
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
    ],
    availableExports: [
      ExportFormat.csv,
      ExportFormat.efficacyCombined,
    ],
    primaryExport: ExportFormat.efficacyCombined,
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
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.applications,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.seeding,
      TrialTab.photos,
    ],
    availableExports: [
      ExportFormat.armXml,
      ExportFormat.glpPdf,
    ],
    primaryExport: ExportFormat.glpPdf,
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
    displayName: 'Standalone Trial',
    shortDescription: 'Independent trial — no ARM required, PDF and CSV report',
    visibleTabs: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.applications,
      TrialTab.seeding,
      TrialTab.photos,
    ],
    tabOrder: [
      TrialTab.plots,
      TrialTab.assessments,
      TrialTab.treatments,
      TrialTab.applications,
      TrialTab.seeding,
      TrialTab.photos,
    ],
    availableExports: [
      ExportFormat.standaloneReport,
      ExportFormat.standaloneCsv,
    ],
    primaryExport: ExportFormat.standaloneReport,
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
