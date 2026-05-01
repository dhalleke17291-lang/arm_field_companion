/// Immutable DTOs for the Field Execution Report.
///
/// Seven sections assembled from existing repositories and use cases.
/// No PDF rendering, no interpretation, no schema changes.
library;

// ── Section A: Trial and session identity ────────────────────────────────────

class FerIdentity {
  const FerIdentity({
    required this.trialId,
    required this.trialName,
    required this.protocolNumber,
    required this.crop,
    required this.location,
    required this.season,
    required this.sessionId,
    required this.sessionName,
    required this.sessionDateLocal,
    required this.sessionStatus,
    required this.raterName,
  });

  final int trialId;
  final String trialName;
  final String? protocolNumber;
  final String? crop;
  final String? location;
  final String? season;
  final int sessionId;
  final String sessionName;
  final String sessionDateLocal;

  /// Derived from [Session.status] — 'open' or 'closed'.
  final String sessionStatus;
  final String? raterName;
}

// ── Section B: Protocol context ───────────────────────────────────────────────

enum FerDivergenceType { timing, missing, unexpected }

class FerProtocolDivergenceRow {
  const FerProtocolDivergenceRow({
    required this.type,
    this.deltaDays,
    this.plannedDat,
    this.actualDat,
  });

  final FerDivergenceType type;

  /// Signed: actual − planned (null for missing and unexpected).
  final int? deltaDays;

  /// Days After Treatment (seeding) for planned date; null when no seeding record.
  final int? plannedDat;

  /// Days After Treatment (seeding) for actual date; null when no seeding record.
  final int? actualDat;
}

class FerProtocolContext {
  const FerProtocolContext({
    required this.isArmLinked,
    required this.isArmTrial,
    required this.divergences,
  });

  /// Whether this session has an ARM protocol metadata row.
  final bool isArmLinked;

  /// Whether the trial has any ARM protocol metadata rows at all.
  final bool isArmTrial;

  final List<FerProtocolDivergenceRow> divergences;

  int get timingCount =>
      divergences.where((d) => d.type == FerDivergenceType.timing).length;
  int get missingCount =>
      divergences.where((d) => d.type == FerDivergenceType.missing).length;
  int get unexpectedCount =>
      divergences.where((d) => d.type == FerDivergenceType.unexpected).length;
  int get totalCount => divergences.length;
}

// ── Section C: Session grid (hub data-plot semantics) ─────────────────────────

class FerSessionGrid {
  const FerSessionGrid({
    required this.dataPlotCount,
    required this.assessmentCount,
    required this.rated,
    required this.unrated,
    required this.withIssues,
    required this.edited,
    required this.flagged,
  });

  /// Analyzable (non-guard, non-excluded) plots in the trial.
  final int dataPlotCount;

  /// Distinct assessments linked to this session.
  final int assessmentCount;

  final int rated;
  final int unrated;

  /// Plots with at least one non-RECORDED status rating.
  final int withIssues;

  /// Plots with at least one amended or corrected rating.
  final int edited;

  final int flagged;
}

// ── Section D: Evidence record ────────────────────────────────────────────────

class FerEvidenceRecord {
  const FerEvidenceRecord({
    required this.photoCount,
    required this.photoIds,
    required this.hasGps,
    required this.hasWeather,
    required this.hasTimestamp,
  });

  final int photoCount;

  /// Durable photo IDs from the photos table for audit provenance.
  final List<int> photoIds;

  /// True if any current rating in this session has captured lat/lng.
  final bool hasGps;

  /// True if a weather snapshot exists for this session.
  final bool hasWeather;

  /// True if [FerIdentity.sessionDateLocal] is a parseable date.
  final bool hasTimestamp;
}

// ── Section E: Signals and decisions ─────────────────────────────────────────

class FerSignalRow {
  const FerSignalRow({
    required this.id,
    required this.signalType,
    required this.severity,
    required this.status,
    required this.consequenceText,
    required this.raisedAt,
  });

  final int id;
  final String signalType;
  final String severity;
  final String status;
  final String consequenceText;

  /// Epoch milliseconds UTC.
  final int raisedAt;
}

class FerSignalsSection {
  const FerSignalsSection({required this.openSignals});

  /// Signals with status open | deferred | investigating for this session.
  final List<FerSignalRow> openSignals;
}

// ── Section F: Completeness ───────────────────────────────────────────────────

class FerCompletenessSection {
  const FerCompletenessSection({
    required this.expectedPlots,
    required this.completedPlots,
    required this.incompletePlots,
    required this.canClose,
    required this.blockerCount,
    required this.warningCount,
  });

  final int expectedPlots;
  final int completedPlots;
  final int incompletePlots;

  /// True when there are no blocker-severity completeness issues.
  final bool canClose;

  final int blockerCount;
  final int warningCount;
}

// ── Top-level ─────────────────────────────────────────────────────────────────

class FieldExecutionReportData {
  const FieldExecutionReportData({
    required this.identity,
    required this.protocolContext,
    required this.sessionGrid,
    required this.evidenceRecord,
    required this.signals,
    required this.completeness,
    required this.executionStatement,
    required this.generatedAt,
  });

  final FerIdentity identity;
  final FerProtocolContext protocolContext;
  final FerSessionGrid sessionGrid;
  final FerEvidenceRecord evidenceRecord;
  final FerSignalsSection signals;
  final FerCompletenessSection completeness;

  /// Deterministic factual summary generated from the assembled sections.
  final String executionStatement;

  final DateTime generatedAt;
}
