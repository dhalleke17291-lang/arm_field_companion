import 'interpretation_factors_codec.dart';
import 'trial_coherence_dto.dart';
import 'trial_ctq_dto.dart';
import 'trial_interpretation_risk_dto.dart';

const _kReadinessConditionLabels = <String, String>{
  'low_pest_pressure': 'low pest or disease pressure expected at this site',
  'high_pest_pressure':
      'high pest or disease pressure may affect treatment expression',
  'drought_stress': 'drought stress this season',
  'excessive_rainfall': 'excessive rainfall during the trial period',
  'frost_risk': 'frost risk during the trial period',
  'spatial_gradient':
      'spatial gradient in the field may affect treatment comparisons',
  'previous_crop_residue': 'previous crop residue effects noted at this site',
  'atypical_season': 'atypical seasonal conditions for this region',
  'drainage_issues': 'drainage issues noted in the trial area',
};

class TrialReadinessStatement {
  const TrialReadinessStatement({
    required this.statusLabel,
    required this.summaryText,
    required this.reasons,
    required this.actionItems,
    required this.cautions,
    required this.isReadyForExport,
  });

  /// Short chip label: 'Export ready' | 'Not export-ready'
  final String statusLabel;

  /// One-sentence summary shown below the chip.
  final String summaryText;

  /// Supporting "why" bullets (CTQ/coherence detail sentences).
  final List<String> reasons;

  /// Actionable items the researcher must resolve.
  final List<String> actionItems;

  /// Caveats that do not block export but warrant attention (e.g. moderate risk).
  final List<String> cautions;

  final bool isReadyForExport;
}

/// Deterministic, pure narrative from the three cognition DTOs and trial state.
/// No DateTime.now, no DB access, no provider reads.
/// Forbidden output words: passed, failed, statistically significant, superior,
/// best treatment, winner.
TrialReadinessStatement computeTrialReadinessStatement({
  required TrialCoherenceDto coherenceDto,
  required TrialInterpretationRiskDto riskDto,
  required TrialCtqDto ctqDto,
  required String trialState,
  String? knownInterpretationFactors,
}) {
  final reasons = <String>[];
  final actions = <String>[];
  final cautions = <String>[];

  // ── CTQ ──────────────────────────────────────────────────────────────────
  final blockers = ctqDto.ctqItems.where((i) => i.isBlocked).toList();
  final unacknowledgedReview =
      ctqDto.ctqItems.where((i) => i.needsReview && !i.isAcknowledged).toList();

  if (ctqDto.overallStatus == 'ready_for_review') {
    reasons.add('All critical-to-quality factors satisfied.');
  } else {
    for (final b in blockers) {
      reasons.add('${b.label}: ${b.reason}');
      actions.add('Resolve: ${b.label}');
    }
    for (final r in unacknowledgedReview) {
      actions.add('Review: ${r.label}');
    }
  }

  // ── Coherence ─────────────────────────────────────────────────────────────
  final reviewNeededChecks = coherenceDto.checks
      .where((c) => c.status == 'review_needed')
      .toList();
  final cannotEvalChecks = coherenceDto.checks
      .where((c) => c.status == 'cannot_evaluate')
      .toList();

  if (reviewNeededChecks.isEmpty && cannotEvalChecks.isEmpty) {
    reasons.add('No coherence concerns identified.');
  } else {
    for (final c in reviewNeededChecks) {
      reasons.add('${c.label}: ${c.reason}');
      actions.add('Review deviation: ${c.label}');
    }
    for (final c in cannotEvalChecks) {
      actions.add('Provide missing input for: ${c.label}');
    }
  }

  // ── Known site/season conditions ─────────────────────────────────────────
  final parsedFactors =
      InterpretationFactorsCodec.parse(knownInterpretationFactors);
  if (parsedFactors != null && !parsedFactors.noneSelected) {
    for (final k in parsedFactors.selectedKeys) {
      final text = _kReadinessConditionLabels[k];
      if (text != null) cautions.add('Site/season condition noted: $text.');
    }
    if (parsedFactors.otherText != null) {
      cautions.add('Site/season condition noted: ${parsedFactors.otherText}.');
    }
  }

  // ── Known site / season risk factor ─────────────────────────────────────
  for (final f in riskDto.factors) {
    if (f.factorKey == 'known_site_season_factors' && f.severity == 'moderate') {
      if (parsedFactors != null && !parsedFactors.noneSelected) {
        final labels = <String>[];
        for (final k in parsedFactors.selectedKeys) {
          final text = _kReadinessConditionLabels[k];
          if (text != null) labels.add(text);
        }
        if (parsedFactors.otherText != null) labels.add(parsedFactors.otherText!);
        if (labels.isNotEmpty) {
          cautions.add(
            'Caution: researcher noted ${labels.join(', ')} this season. '
            'Consider site conditions when interpreting results.',
          );
        }
      } else {
        // parsedFactors unavailable — use the evaluator's pre-formatted reason.
        cautions.add(f.reason);
      }
      break;
    }
  }

  // ── Interpretation risk ───────────────────────────────────────────────────
  final riskLabel = switch (riskDto.riskLevel) {
    'low' => 'low',
    'moderate' => 'moderate',
    'high' => 'high',
    _ => null,
  };

  if (riskLabel != null) {
    final elevatedFactors = riskDto.factors
        .where((f) =>
            (f.severity == 'moderate' || f.severity == 'high') &&
            f.factorKey != 'known_site_season_factors')
        .toList();

    if (elevatedFactors.isNotEmpty && riskLabel != 'low') {
      final worstFactor = elevatedFactors.firstWhere(
        (f) => f.severity == riskLabel,
        orElse: () => elevatedFactors.first,
      );
      cautions.add('Interpretation risk is $riskLabel — ${worstFactor.reason}');
    } else {
      reasons.add('Interpretation risk is $riskLabel.');
    }
  }

  // ── Export readiness verdict ──────────────────────────────────────────────
  final isReady = actions.isEmpty &&
      ctqDto.overallStatus == 'ready_for_review' &&
      coherenceDto.coherenceState == 'aligned' &&
      (riskDto.riskLevel == 'low' || riskDto.riskLevel == 'moderate') &&
      (trialState == 'active' || trialState == 'closed');

  final statusLabel = isReady ? 'Export ready' : 'Not export-ready';
  final summaryText = isReady
      ? 'Trial is ready for export and analysis.'
      : 'Trial is not currently export-ready.';

  return TrialReadinessStatement(
    statusLabel: statusLabel,
    summaryText: summaryText,
    reasons: List.unmodifiable(reasons),
    actionItems: List.unmodifiable(actions),
    cautions: List.unmodifiable(cautions),
    isReadyForExport: isReady,
  );
}
