import '../models/trial_insight.dart';

/// Builds verdict strings for [TrialInsight] emissions.
///
/// Every string produced here must pass `docs/INSIGHT_VOICE_SPEC.md`.
/// A verdict is returned only when the situation fits one of the allowed
/// verdict kinds (spec §3) and the confidence tier permits a clean call.
/// Otherwise `null` — silence beats noise.
class InsightVoice {
  InsightVoice._();

  /// Effect-size threshold below which separation is not a call.
  static const double _kSeparationFloorPct = 5;

  /// Effect-size threshold at which separation is clearly established.
  static const double _kSeparationClearPct = 20;

  /// Treatment-trend delta threshold (percentage points) below which the
  /// direction is too weak to call.
  static const double _kTrendDeltaFloorPct = 5;

  // ---------------------------------------------------------------------------
  // Tier prefix (spec §5)
  // ---------------------------------------------------------------------------

  /// Applies the confidence-tier opener to a core verdict sentence.
  ///
  /// The core sentence is expected to read naturally as a standalone verdict
  /// ("Treatments are separating clearly."). This method adds the hedge
  /// opener required by the tier.
  static String applyTier(String core, InsightConfidence tier) {
    switch (tier) {
      case InsightConfidence.established:
        return core;
      case InsightConfidence.preliminary:
        return 'Early signal — $core';
      case InsightConfidence.moderate:
        return 'So far: $core';
    }
  }

  // ---------------------------------------------------------------------------
  // Separation verdict — trial health (spec §3)
  // ---------------------------------------------------------------------------

  /// Builds a separation verdict for the trial-health insight.
  ///
  /// [effectSize] is the percent difference between best treatment and check.
  /// [separationTrend] is 'increasing' | 'stable' | 'collapsing' | null.
  static String? separationVerdict({
    required double effectSize,
    String? separationTrend,
    required InsightConfidence tier,
  }) {
    final abs = effectSize.abs();
    String core;
    if (abs < _kSeparationFloorPct) {
      core = 'Treatments are not separating yet.';
    } else if (effectSize < 0) {
      // Best non-check is worse than check; unusual but defensible.
      return null;
    } else if (abs >= _kSeparationClearPct &&
        (separationTrend == 'increasing' || separationTrend == 'stable')) {
      core = 'Treatments are separating clearly.';
    } else if (abs >= _kSeparationClearPct && separationTrend == 'collapsing') {
      core = 'Treatments are separating, but the gap is narrowing.';
    } else {
      core = 'Treatments are beginning to separate.';
    }
    return applyTier(core, tier);
  }

  // ---------------------------------------------------------------------------
  // Trend verdict — treatment trend (spec §3)
  // ---------------------------------------------------------------------------

  /// Builds a trend verdict for a single treatment.
  ///
  /// Returns `null` when the delta is too small to call a direction. The
  /// category row stays visible with its raw numbers; silence on the verdict
  /// line is intentional.
  static String? trendVerdict({
    required String treatmentCode,
    required double delta,
    required InsightConfidence tier,
  }) {
    if (delta.abs() < _kTrendDeltaFloorPct) return null;
    final code = treatmentCode.trim();
    if (code.isEmpty) return null;
    final core = delta > 0
        ? 'Treatment $code response is trending up.'
        : 'Treatment $code response is trending down.';
    return applyTier(core, tier);
  }

  // ---------------------------------------------------------------------------
  // Drift verdict — rep variability (spec §3)
  // ---------------------------------------------------------------------------

  /// Builds a drift verdict for rep variability.
  ///
  /// Returns `null` when no outlier reps were flagged — no call to make.
  static String? driftVerdict({
    required List<int> outlierReps,
    required InsightConfidence tier,
  }) {
    if (outlierReps.isEmpty) return null;
    String core;
    if (outlierReps.length == 1) {
      core = 'Rep ${outlierReps.first} is drifting; verify consistency next session.';
    } else {
      final reps = (List<int>.from(outlierReps)..sort()).join(', ');
      core = 'Reps $reps are drifting from the trial mean; verify consistency.';
    }
    return applyTier(core, tier);
  }
}
