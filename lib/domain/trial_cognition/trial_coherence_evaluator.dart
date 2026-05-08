import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/check_treatment_helper.dart';
import '../signals/signal_repository.dart';
import 'application_timing_helper.dart';
import 'trial_coherence_dto.dart';

Future<TrialCoherenceDto> computeTrialCoherenceDto({
  required AppDatabase db,
  required int trialId,
  required SignalRepository signalRepo,
}) async {
  // ── Parallel data fetch ──────────────────────────────────────────────────
  final results = await Future.wait([
    // 0: current trial purpose (non-superseded)
    (db.select(db.trialPurposes)
          ..where(
            (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.version)])
          ..limit(1))
        .getSingleOrNull(),
    // 1: trial-specific assessments (for check 1)
    (db.select(db.assessments)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 2: application events
    (db.select(db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 3: non-deleted treatments
    (db.select(db.treatments)
          ..where(
            (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false),
          ))
        .get(),
    // 4: non-deleted treatment components
    (db.select(db.treatmentComponents)
          ..where(
            (c) => c.trialId.equals(trialId) & c.isDeleted.equals(false),
          ))
        .get(),
    // 5: trial record (for crop)
    (db.select(db.trials)..where((t) => t.id.equals(trialId)))
        .getSingleOrNull(),
    // 6: assignments
    (db.select(db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 7: all signals for this trial
    (db.select(db.signals)..where((s) => s.trialId.equals(trialId))).get(),
  ]);

  final purpose = results[0] as TrialPurpose?;
  final assessments = results[1] as List<Assessment>;
  final applications = results[2] as List<TrialApplicationEvent>;
  final treatments = results[3] as List<Treatment>;
  final treatmentComponents = results[4] as List<TreatmentComponent>;
  final trialRecord = results[5] as Trial?;
  final assignments = results[6] as List<Assignment>;
  final allSignals = results[7] as List<Signal>;

  final trialCrop = trialRecord?.crop;

  // Researcher decisions with notes for check 2 acknowledgment.
  final researcherDecisions =
      await signalRepo.getAllResearcherDecisionEventsForTrial(trialId);

  // ── Four checks ──────────────────────────────────────────────────────────
  final checks = [
    _checkPrimaryEndpointAssessment(purpose, assessments),
    _checkApplicationTiming(
      applications: applications,
      treatments: treatments,
      treatmentComponents: treatmentComponents,
      trialCrop: trialCrop,
      allSignals: allSignals,
      researcherDecisions: researcherDecisions,
    ),
    _checkClaimTreatmentReplication(purpose, treatments, assignments),
    _checkOpenProtocolDivergenceSignals(purpose, allSignals),
  ];

  return TrialCoherenceDto(
    coherenceState: _worstState(checks),
    checks: List.unmodifiable(checks),
    computedAt: DateTime.now(),
  );
}

// ── Check 1: primary endpoint assessment present ──────────────────────────

TrialCoherenceCheckDto _checkPrimaryEndpointAssessment(
  TrialPurpose? purpose,
  List<Assessment> assessments,
) {
  const key = 'primary_endpoint_assessment_present';
  const label = 'Primary endpoint assessment present';
  const sources = ['trial_purposes', 'assessments'];

  if (purpose == null || purpose.primaryEndpoint == null) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'No primary endpoint has been captured for this trial.',
      sourceFields: sources,
    );
  }

  if (assessments.isEmpty) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'review_needed',
      reason: 'Primary endpoint is stated but no assessments have been defined.',
      sourceFields: sources,
    );
  }

  final endpoint = purpose.primaryEndpoint!;
  final hasMatch = assessments.any((a) {
    return _assessmentMatchesPrimaryEndpoint(
      assessmentName: a.name,
      primaryEndpoint: endpoint,
    );
  });

  if (hasMatch) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          'An assessment matching the stated primary endpoint is present for this trial.',
      sourceFields: sources,
    );
  }

  return TrialCoherenceCheckDto(
    checkKey: key,
    label: label,
    status: 'review_needed',
    reason:
        'No assessment name matches the stated primary endpoint ("${purpose.primaryEndpoint}"). '
        'Verify the assessment is correctly named.',
    sourceFields: sources,
  );
}

bool _assessmentMatchesPrimaryEndpoint({
  required String assessmentName,
  required String primaryEndpoint,
}) {
  final assessment = _normalizeEndpointText(assessmentName);
  final endpoint = _normalizeEndpointText(primaryEndpoint);
  if (assessment.isEmpty || endpoint.isEmpty) return false;
  if (endpoint.contains(assessment) || assessment.contains(endpoint)) {
    return true;
  }

  final assessmentTokens = _meaningfulEndpointTokens(assessment);
  if (assessmentTokens.isEmpty) return false;
  final endpointTokens = _meaningfulEndpointTokens(endpoint).toSet();
  if (assessmentTokens.length == 1) {
    final token = assessmentTokens.single;
    return token.length >= 5 && endpointTokens.contains(token);
  }
  final matched =
      assessmentTokens.where((token) => endpointTokens.contains(token)).length;
  return matched == assessmentTokens.length;
}

String _normalizeEndpointText(String value) {
  return value
      .toLowerCase()
      .replaceAll('%', ' percent ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _meaningfulEndpointTokens(String normalized) {
  const stopWords = {
    'a',
    'an',
    'and',
    'at',
    'between',
    'by',
    'comparison',
    'endpoint',
    'final',
    'for',
    'in',
    'of',
    'plots',
    'plot',
    'primary',
    'stage',
    'the',
    'to',
  };
  return normalized
      .split(' ')
      .where((token) => token.isNotEmpty && !stopWords.contains(token))
      .toList();
}

// ── Check 2: application timing within claim window ───────────────────────

TrialCoherenceCheckDto _checkApplicationTiming({
  required List<TrialApplicationEvent> applications,
  required List<Treatment> treatments,
  required List<TreatmentComponent> treatmentComponents,
  required String? trialCrop,
  required List<Signal> allSignals,
  required List<dynamic> researcherDecisions,
}) {
  const key = 'application_timing_within_claim_window';
  const label = 'Application timing within claim window';
  const sources = ['trial_application_events', 'biological_window_profiles'];

  if (treatments.isEmpty || applications.isEmpty) {
    return TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: treatments.isEmpty
          ? 'No treatments defined — application timing cannot be evaluated.'
          : 'No application events recorded.',
      sourceFields: sources,
    );
  }

  final hasBbch =
      applications.any((a) => a.growthStageBbchAtApplication != null);
  if (!hasBbch) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'BBCH growth stage was not recorded at any application event.',
      sourceFields: sources,
    );
  }

  final result =
      evaluateBbchTiming(applications, treatmentComponents, trialCrop);

  if (result == null) {
    return TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          '${applications.length} application event(s) recorded. '
          'No biological window profile configured for this crop and category.',
      sourceFields: sources,
    );
  }

  if (!result.hasBbch) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'BBCH growth stage was not captured at application.',
      sourceFields: sources,
    );
  }

  if (result.profile == null) {
    return TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          '${result.applicationCount} application event(s) with BBCH data. '
          'No window profile configured for this crop and ${result.pesticideCategory} combination.',
      sourceFields: sources,
    );
  }

  if (result.worstSeverity == 0) {
    final profile = result.profile!;
    return TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          'Applied at BBCH ${result.worstBbch}. '
          'Within optimal window (${profile.optimalWindowLabel}).',
      sourceFields: sources,
    );
  }

  // Severity > 0 — check whether the researcher has acknowledged a
  // causal_context_flag signal with documented reasoning.
  final timingSignalIds = allSignals
      .where((s) => s.signalType == 'causal_context_flag')
      .map((s) => s.id)
      .toSet();

  if (timingSignalIds.isNotEmpty) {
    final ackDecisions = researcherDecisions.where((d) {
      final note = (d as dynamic).note as String?;
      return timingSignalIds.contains((d as dynamic).signalId as int) &&
          (note?.isNotEmpty == true);
    }).toList();

    if (ackDecisions.isNotEmpty) {
      final first = ackDecisions.first as dynamic;
      final actor = (first.actorName as String?) ?? 'Researcher';
      final note = first.note as String;
      final profile = result.profile!;
      final windowLabel = result.worstSeverity == 2
          ? 'outside acceptable window (${profile.acceptableWindowLabel})'
          : 'outside optimal window (${profile.optimalWindowLabel})';
      return TrialCoherenceCheckDto(
        checkKey: key,
        label: label,
        status: 'acknowledged',
        reason:
            'Applied at BBCH ${result.worstBbch} ($windowLabel). '
            'Acknowledged by $actor — $note',
        sourceFields: [...sources, 'signal_decision_events'],
      );
    }
  }

  final profile = result.profile!;
  final windowDesc = result.worstSeverity == 2
      ? 'outside the acceptable application window (${profile.acceptableWindowLabel})'
      : 'outside the optimal window (${profile.optimalWindowLabel}) but within acceptable range (${profile.acceptableWindowLabel})';
  return TrialCoherenceCheckDto(
    checkKey: key,
    label: label,
    status: 'review_needed',
    reason:
        'Applied at BBCH ${result.worstBbch}. $windowDesc for '
        '${profile.cropLabel} ${result.pesticideCategory}.',
    sourceFields: sources,
  );
}

// ── Check 3: claim treatment adequate replication ─────────────────────────

TrialCoherenceCheckDto _checkClaimTreatmentReplication(
  TrialPurpose? purpose,
  List<Treatment> treatments,
  List<Assignment> assignments,
) {
  const key = 'claim_treatment_adequate_replication';
  const label = 'Claim treatment adequate replication';
  const sources = ['trial_purposes', 'assignments'];

  if (purpose == null || purpose.treatmentRoleSummary == null) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'Treatment roles have not been captured in the trial purpose.',
      sourceFields: sources,
    );
  }

  final activeTreatments = treatments.where((t) => !isCheckTreatment(t)).toList();

  if (activeTreatments.isEmpty) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'No active (non-check) treatments are defined for this trial.',
      sourceFields: sources,
    );
  }

  // Count assignments per active treatment.
  final repCounts = <int, int>{};
  for (final t in activeTreatments) {
    repCounts[t.id] = 0;
  }
  for (final a in assignments) {
    if (a.treatmentId != null && repCounts.containsKey(a.treatmentId)) {
      repCounts[a.treatmentId!] = (repCounts[a.treatmentId!] ?? 0) + 1;
    }
  }

  final maxReps = repCounts.values.fold(0, (a, b) => a > b ? a : b);

  if (maxReps >= 4) {
    return TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          'Claim treatment has $maxReps replication(s) — meets the minimum of 4.',
      sourceFields: sources,
    );
  }

  return TrialCoherenceCheckDto(
    checkKey: key,
    label: label,
    status: 'review_needed',
    reason: maxReps == 0
        ? 'No assignments found for active treatments. Replication cannot be confirmed.'
        : 'Maximum replication across active treatments is $maxReps (minimum 4 required).',
    sourceFields: sources,
  );
}

// ── Check 4: open protocol divergence / causal context signals ────────────

TrialCoherenceCheckDto _checkOpenProtocolDivergenceSignals(
  TrialPurpose? purpose,
  List<Signal> allSignals,
) {
  const key = 'open_protocol_divergence_signals';
  const label = 'Open protocol divergence signals';
  const sources = ['signals'];

  if (purpose == null) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'cannot_evaluate',
      reason: 'No trial purpose defined — protocol divergence cannot be assessed.',
      sourceFields: sources,
    );
  }

  final openDivergence = allSignals
      .where((s) =>
          s.status == 'open' &&
          (s.signalType == 'protocol_divergence' ||
              s.signalType == 'causal_context_flag'))
      .toList();

  if (openDivergence.isEmpty) {
    return const TrialCoherenceCheckDto(
      checkKey: key,
      label: label,
      status: 'aligned',
      reason:
          'No open protocol divergence or causal context signals for this trial.',
      sourceFields: sources,
    );
  }

  final count = openDivergence.length;
  final details = openDivergence
      .map((s) => s.consequenceText)
      .where((t) => t.isNotEmpty)
      .take(3)
      .join('; ');

  return TrialCoherenceCheckDto(
    checkKey: key,
    label: label,
    status: 'review_needed',
    reason: count == 1
        ? '1 open signal requires review. $details'
        : '$count open signals require review. $details',
    sourceFields: sources,
  );
}

// ── Overall state ─────────────────────────────────────────────────────────

String _worstState(List<TrialCoherenceCheckDto> checks) {
  // Priority: cannot_evaluate(3) > review_needed(2) > acknowledged(1) > aligned(0)
  // Overall state has no 'acknowledged' — it collapses to 'review_needed'.
  const priority = {
    'cannot_evaluate': 3,
    'review_needed': 2,
    'acknowledged': 1,
    'aligned': 0,
  };
  var worstPriority = 0;
  var worstStatus = 'aligned';
  for (final check in checks) {
    final p = priority[check.status] ?? 0;
    if (p > worstPriority) {
      worstPriority = p;
      worstStatus = check.status;
    }
  }
  // Map 'acknowledged' to 'review_needed' for the overall state.
  if (worstStatus == 'acknowledged') return 'review_needed';
  return worstStatus;
}
