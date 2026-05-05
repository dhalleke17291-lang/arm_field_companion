import 'trial_coherence_dto.dart';
import 'trial_ctq_dto.dart';
import 'trial_interpretation_risk_dto.dart';

class TrialReadinessStatement {
  const TrialReadinessStatement({
    required this.narrative,
    required this.actionItems,
    required this.isReadyForExport,
  });

  final String narrative;
  final List<String> actionItems;
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
}) {
  final parts = <String>[];
  final actions = <String>[];

  // ── CTQ ──────────────────────────────────────────────────────────────────
  final blockers = ctqDto.ctqItems.where((i) => i.isBlocked).toList();
  final unacknowledgedReview =
      ctqDto.ctqItems.where((i) => i.needsReview && !i.isAcknowledged).toList();

  if (ctqDto.overallStatus == 'ready_for_review') {
    parts.add('All critical-to-quality factors satisfied.');
  } else {
    for (final b in blockers) {
      parts.add('${b.label}: ${b.reason}');
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
    parts.add('No coherence concerns identified.');
  } else {
    for (final c in reviewNeededChecks) {
      parts.add('${c.label}: ${c.reason}');
      actions.add('Review deviation: ${c.label}');
    }
    for (final c in cannotEvalChecks) {
      actions.add('Provide missing input for: ${c.label}');
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
        .where((f) => f.severity == 'moderate' || f.severity == 'high')
        .toList();

    if (elevatedFactors.isNotEmpty) {
      final detail = elevatedFactors.first.reason;
      parts.add('Interpretation risk is $riskLabel — $detail');
    } else {
      parts.add('Interpretation risk is $riskLabel.');
    }
  }

  // ── Export readiness verdict ──────────────────────────────────────────────
  final isReady = actions.isEmpty &&
      ctqDto.overallStatus == 'ready_for_review' &&
      coherenceDto.coherenceState == 'aligned' &&
      (riskDto.riskLevel == 'low' || riskDto.riskLevel == 'moderate') &&
      (trialState == 'active' || trialState == 'closed');

  if (isReady) {
    parts.add('Trial is ready for export and analysis.');
  } else {
    parts.add('Trial is not currently export-ready.');
  }

  return TrialReadinessStatement(
    narrative: parts.join(' '),
    actionItems: List.unmodifiable(actions),
    isReadyForExport: isReady,
  );
}
