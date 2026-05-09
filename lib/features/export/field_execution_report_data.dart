/// Immutable DTOs for the Field Execution Report.
///
/// Seven sections assembled from existing repositories and use cases.
/// No PDF rendering, no interpretation, no schema changes.
///
/// Evidence source distinction:
///   Section D draws from operational source tables (db.photos,
///   db.weatherSnapshots, db.ratingRecords). It does NOT read the
///   evidence_anchors audit table, which is the separate CRO-provenance
///   store written by EvidenceAnchorRepository. A future Evidence Appendix
///   build will consume that table; this report does not.
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

/// Protocol divergences for a single session.
///
/// Applies the same classification rules as [protocolDivergenceProvider] but
/// scoped to the one session being reported. The provider returns divergences
/// for all sessions in a trial; this DTO contains only the current session's
/// divergence rows. Callers must not read this as the full trial divergence
/// summary.
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

/// Operational evidence presence for a single session.
///
/// All fields are derived from source tables (db.photos, db.weatherSnapshots,
/// db.ratingRecords). This class does NOT read the evidence_anchors table;
/// that table stores durable CRO-provenance anchors written at session-close
/// time and is the subject of a separate Evidence Appendix report.
class FerEvidenceRecord {
  const FerEvidenceRecord({
    required this.photoCount,
    required this.photoIds,
    required this.hasGps,
    required this.hasWeather,
    required this.hasTimestamp,
    required this.sessionDurationMinutes,
  });

  final int photoCount;

  /// Photo IDs from the operational db.photos table (not evidence_anchors).
  final List<int> photoIds;

  /// True if any **current, non-deleted** rating for this session has
  /// captured lat/lng (source: [RatingRepository.getCurrentRatingsForSession]).
  /// Deleted or superseded ratings do not contribute.
  final bool hasGps;

  /// True if a weather snapshot row exists for this session (db.weatherSnapshots).
  final bool hasWeather;

  /// True if [FerIdentity.sessionDateLocal] is a parseable date.
  final bool hasTimestamp;

  /// Session duration derived from existing session started/ended timestamps.
  /// Null when the session has not been closed or either timestamp is missing.
  final int? sessionDurationMinutes;
}

// ── Section E: Signals ────────────────────────────────────────────────────────
// Decision history is not included in the initial DTO. Each signal ID is
// available for a future caller to load decision events via
// SignalRepository.getDecisionHistory(signalId), but that expansion is
// deferred until the PDF builder or a dedicated decision-history section is
// built.

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

/// Unresolved signals for a single session.
///
/// Contains signals with status open | deferred | investigating, sourced from
/// [SignalRepository.getOpenSignalsForSession]. Terminal statuses (resolved,
/// expired, suppressed) are excluded. Decision history per signal is not
/// included here; use [SignalRepository.getDecisionHistory] if needed.
class FerSignalsSection {
  const FerSignalsSection({required this.openSignals});

  /// Signals with status open | deferred | investigating for this session.
  /// Terminal statuses (resolved, expired, suppressed) are not present.
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

// ── Section H: Trial cognition — purpose, evidence arc, CTQ ──────────────────

/// One actionable CTQ factor row for the cognition section.
///
/// Only blocked / review_needed / missing items are included; the status label
/// is pre-baked at assembly time so the PDF builder needs no label logic.
class FerCognitionAttentionItem {
  const FerCognitionAttentionItem({
    required this.factorKey,
    required this.label,
    required this.statusLabel,
  });

  final String factorKey;
  final String label;

  /// Human-readable status, computed by the assembly service.
  final String statusLabel;
}

/// Trial-level cognition summary: purpose, evidence arc, and CTQ readiness.
///
/// This section is trial-scoped. All other sections of [FieldExecutionReportData]
/// are session-scoped. Status strings carry pre-computed human labels so the
/// PDF builder is a pure renderer with no label logic.
class FerCognitionSection {
  const FerCognitionSection({
    required this.purposeStatus,
    required this.purposeStatusLabel,
    this.claimBeingTested,
    this.primaryEndpoint,
    required this.missingIntentFields,
    required this.missingIntentFieldLabels,
    required this.evidenceState,
    required this.evidenceStateLabel,
    required this.actualEvidenceSummary,
    required this.missingEvidenceItems,
    required this.ctqOverallStatus,
    required this.ctqOverallStatusLabel,
    required this.blockerCount,
    required this.warningCount,
    required this.reviewCount,
    required this.satisfiedCount,
    required this.topCtqAttentionItems,
  });

  /// Non-efficacy, non-validity disclaimer required on all cognition output.
  static const String disclaimerText =
      'This section summarises evidence readiness and review needs. '
      'It does not determine treatment efficacy or statistical validity.';

  /// Raw purpose status: unknown | draft | partial | confirmed.
  final String purposeStatus;

  /// Human-readable label, e.g. "Intent confirmed".
  final String purposeStatusLabel;

  final String? claimBeingTested;
  final String? primaryEndpoint;

  /// Raw ModeCQuestionKeys for required fields that have no captured answer.
  final List<String> missingIntentFields;

  /// Human-readable names parallel to [missingIntentFields].
  final List<String> missingIntentFieldLabels;

  /// Raw evidence state: no_evidence | started | partial | sufficient_for_review
  /// | export_ready_candidate.
  final String evidenceState;

  /// Human-readable label, e.g. "No evidence yet".
  final String evidenceStateLabel;

  /// Narrative summary, e.g. "2 sessions · 96 ratings · no photos".
  final String actualEvidenceSummary;

  final List<String> missingEvidenceItems;

  /// Raw CTQ overall status: unknown | incomplete | review_needed | ready_for_review.
  final String ctqOverallStatus;

  /// Human-readable label, e.g. "Needs review".
  final String ctqOverallStatusLabel;

  final int blockerCount;
  final int warningCount;
  final int reviewCount;
  final int satisfiedCount;

  /// Actionable items only (blocked / review_needed / missing), ranked by
  /// severity, capped at 5. Does not include unknown / future factors.
  final List<FerCognitionAttentionItem> topCtqAttentionItems;
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
    required this.cognition,
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

  /// Trial-level cognition: purpose, evidence arc, CTQ readiness.
  final FerCognitionSection cognition;

  final DateTime generatedAt;
}
