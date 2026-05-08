import '../../core/database/app_database.dart';
import 'signal_models.dart';
import 'signal_review_projection.dart';

SignalReviewProjection projectSignalForReview(Signal signal) {
  final operationalState = _operationalStateForStatus(signal.status);
  final statusLabel = signalStatusLabel(signal.status);
  final severityLabel = signalSeverityLabel(signal.severity);
  final title = signalDisplayTitle(signal.signalType);
  final summary = signalShortSummary(signal.signalType);
  final requiresReadinessAction = signal.status == SignalStatus.open.dbValue;
  final blocksExport = signalBlocksExport(signal);

  return SignalReviewProjection(
    signalId: signal.id,
    type: signal.signalType,
    status: signal.status,
    severity: signal.severity,
    operationalState: operationalState,
    displayTitle: title,
    shortSummary: summary,
    detailText: signal.consequenceText,
    whyItMatters: signalWhyItMatters(signal.signalType),
    recommendedAction: signalRecommendedAction(signal),
    statusLabel: statusLabel,
    severityLabel: severityLabel,
    isActive: operationalState != SignalOperationalState.historical,
    isNeedsAction: operationalState == SignalOperationalState.needsAction,
    isUnderReview: operationalState == SignalOperationalState.underReview,
    isHistorical: operationalState == SignalOperationalState.historical,
    requiresReadinessAction: requiresReadinessAction,
    readinessActionReason: requiresReadinessAction
        ? 'This signal is still open and should be reviewed before readiness is confirmed.'
        : null,
    blocksExport: blocksExport,
    blocksExportReason: signalBlocksExportReason(signal),
  );
}

List<SignalReviewProjection> projectSignalsForReview(List<Signal> signals) =>
    signals.map(projectSignalForReview).toList(growable: false);

List<SignalReviewGroupProjection> projectSignalGroupsForReview(
  List<Signal> signals,
) {
  final buckets = <String, List<Signal>>{};
  for (final signal in signals) {
    final key = _groupKeyForSignal(signal);
    buckets.putIfAbsent(key, () => <Signal>[]).add(signal);
  }

  final sortedKeys = buckets.keys.toList()..sort();
  return sortedKeys
      .map((key) => _projectSignalGroup(key, buckets[key]!))
      .toList(growable: false);
}

String signalStatusLabel(String status) => switch (status) {
      'open' => 'Needs review',
      'investigating' => 'Under review',
      'deferred' => 'Review later',
      'resolved' => 'Reviewed',
      'suppressed' => 'Hidden from active review',
      'expired' => 'No longer active',
      _ => _plainLabel(status),
    };

String signalSeverityLabel(String severity) => switch (severity) {
      'critical' => 'Needs review before export',
      'review' => 'Needs review',
      'info' => 'For awareness',
      _ => _plainLabel(severity),
    };

String signalDisplayTitle(String type) => switch (type) {
      'causal_context_flag' => 'Treatment timing may need review',
      'rater_drift' ||
      'between_rater_divergence' =>
        'Rating consistency may need review',
      'replication_warning' => 'Replication pattern may affect results',
      'scale_violation' => 'Recorded values may need review',
      'aov_prediction' => 'Analysis pattern may need review',
      'protocol_divergence' => 'Trial alignment may need review',
      'deviation_declaration' => 'Field deviation recorded',
      'export_preflight' => 'Export readiness may need review',
      'spatial_anomaly' => 'Field pattern may need review',
      _ => 'Signal needs review',
    };

String signalShortSummary(String type) => switch (type) {
      'causal_context_flag' =>
        'A rating or application timing detail may affect interpretation.',
      'rater_drift' ||
      'between_rater_divergence' =>
        'Rating attribution or consistency may need confirmation.',
      'replication_warning' =>
        'The rated plot pattern may limit result confidence.',
      'scale_violation' =>
        'A recorded value was outside the expected assessment range.',
      'aov_prediction' =>
        'The current data pattern may limit statistical comparison.',
      'protocol_divergence' =>
        'Field execution may differ from the trial plan.',
      'deviation_declaration' =>
        'A field deviation has been recorded for review.',
      'export_preflight' => 'One export readiness item may need confirmation.',
      'spatial_anomaly' =>
        'A field pattern may need review before interpretation.',
      _ => 'This item may need review before final interpretation.',
    };

String signalWhyItMatters(String type) => switch (type) {
      'causal_context_flag' =>
        'Timing can change how confidently results are interpreted.',
      'rater_drift' ||
      'between_rater_divergence' =>
        'Consistent rating records help protect comparison quality.',
      'replication_warning' =>
        'Low replication can weaken treatment comparisons.',
      'scale_violation' =>
        'Values outside a scale can affect data quality and export review.',
      'aov_prediction' =>
        'Some data patterns make treatment comparisons less reliable.',
      'protocol_divergence' =>
        'Trial plan differences should be understood before reporting.',
      'deviation_declaration' =>
        'Documented deviations help explain field reality later.',
      'export_preflight' => 'Export review helps keep handoff data traceable.',
      'spatial_anomaly' =>
        'Field patterns can affect confidence in treatment effects.',
      _ => 'Reviewing this item helps preserve trial traceability.',
    };

String signalRecommendedAction(Signal signal) {
  if (signal.status == SignalStatus.investigating.dbValue) {
    return 'Continue the review and record the outcome when ready.';
  }
  if (signal.status == SignalStatus.deferred.dbValue) {
    return 'Review this before final reporting or export.';
  }
  if (_operationalStateForStatus(signal.status) ==
      SignalOperationalState.historical) {
    return 'Keep this item in the record for traceability.';
  }

  return switch (signal.signalType) {
    'causal_context_flag' =>
      'Confirm the timing context or document why it is acceptable.',
    'rater_drift' ||
    'between_rater_divergence' =>
      'Confirm who rated the session or review the affected ratings.',
    'replication_warning' =>
      'Review whether enough plots were rated for this treatment.',
    'scale_violation' =>
      'Review the affected value and confirm whether correction is needed.',
    'aov_prediction' =>
      'Review the affected assessment before relying on analysis.',
    'protocol_divergence' =>
      'Document whether the field difference is acceptable.',
    'deviation_declaration' =>
      'Review the deviation and add reasoning if needed.',
    'export_preflight' =>
      'Review the export item before creating a final handoff.',
    'spatial_anomaly' =>
      'Review field notes, photos, or plot context for this pattern.',
    _ => 'Review this item and record a decision.',
  };
}

bool signalBlocksExport(Signal signal) =>
    signal.status == SignalStatus.open.dbValue &&
    signal.severity == SignalSeverity.critical.dbValue;

String? signalBlocksExportReason(Signal signal) =>
    signalBlocksExport(signal)
        ? 'Export is blocked until this critical signal is reviewed.'
        : null;

SignalReviewGroupProjection _projectSignalGroup(
  String groupId,
  List<Signal> signals,
) {
  final sortedSignals = [...signals]..sort((a, b) => a.id.compareTo(b.id));
  final memberSignals = projectSignalsForReview(sortedSignals);
  final representative = memberSignals.first;
  final family = _familyForSignal(sortedSignals.first);

  return SignalReviewGroupProjection(
    groupId: groupId,
    groupType: representative.type,
    familyKey: family.key,
    familyDefinition: signalFamilyDefinition(family.key),
    groupingBasis: family.groupingBasis,
    familyScientificRole: signalFamilyScientificRole(family.key),
    familyInterpretationImpact: signalFamilyInterpretationImpact(family.key),
    reviewQuestion: signalFamilyReviewQuestion(family.key),
    displayTitle: representative.displayTitle,
    shortSummary: _groupShortSummary(representative, memberSignals.length),
    whyItMatters: representative.whyItMatters,
    recommendedAction: representative.recommendedAction,
    statusLabel: _dominantStatusLabel(memberSignals),
    severityLabel: _dominantSeverityLabel(memberSignals),
    signalCount: memberSignals.length,
    affectedAssessmentIds: const <int>[],
    affectedPlotIds: _sortedUniqueNullable(sortedSignals.map((s) => s.plotId)),
    affectedSessionIds:
        _sortedUniqueNullable(sortedSignals.map((s) => s.sessionId)),
    memberSignals: memberSignals,
  );
}

String signalFamilyDefinition(SignalFamilyKey key) => switch (key) {
      SignalFamilyKey.untreatedCheckVariance =>
        'Multiple review items point to the same untreated-check reliability concern.',
      SignalFamilyKey.raterDivergence =>
        'Multiple review items point to the same rating-consistency concern.',
      SignalFamilyKey.timingWindowReview =>
        'Multiple review items point to the same treatment-timing review concern.',
      SignalFamilyKey.replicationPattern =>
        'Multiple review items point to the same replication-pattern concern.',
      SignalFamilyKey.singleton => 'This review item is handled on its own.',
    };

String signalFamilyScientificRole(SignalFamilyKey key) => switch (key) {
      SignalFamilyKey.untreatedCheckVariance =>
        'Untreated checks establish the baseline used for treatment comparison.',
      SignalFamilyKey.raterDivergence =>
        'Consistent rating behavior supports reliable assessment comparison.',
      SignalFamilyKey.timingWindowReview =>
        'Application timing affects whether treatments can be compared fairly.',
      SignalFamilyKey.replicationPattern =>
        'Replication helps distinguish treatment effects from field variability.',
      SignalFamilyKey.singleton =>
        'This review item should be considered on its own.',
    };

String signalFamilyInterpretationImpact(SignalFamilyKey key) => switch (key) {
      SignalFamilyKey.untreatedCheckVariance =>
        'Low untreated-check variation across related assessments may reduce confidence in treatment separation.',
      SignalFamilyKey.raterDivergence =>
        'Differences between raters may reduce confidence in assessment consistency.',
      SignalFamilyKey.timingWindowReview =>
        'Applications outside the intended timing window may weaken comparison reliability.',
      SignalFamilyKey.replicationPattern =>
        'Irregular replication patterns may weaken treatment comparison reliability.',
      SignalFamilyKey.singleton =>
        'Its effect depends on the specific review context.',
    };

String signalFamilyReviewQuestion(SignalFamilyKey key) => switch (key) {
      SignalFamilyKey.untreatedCheckVariance =>
        'Are these assessments reliable enough for final comparison?',
      SignalFamilyKey.raterDivergence =>
        'Do these assessments require review or re-rating?',
      SignalFamilyKey.timingWindowReview =>
        'Should these applications remain part of final comparison?',
      SignalFamilyKey.replicationPattern =>
        'Are treatment comparisons still interpretable?',
      SignalFamilyKey.singleton =>
        'Does this item need action before review or export?',
    };

String _groupShortSummary(
  SignalReviewProjection representative,
  int signalCount,
) {
  if (signalCount == 1) return representative.shortSummary;
  return '${representative.shortSummary} $signalCount related signals are grouped for review.';
}

String _dominantStatusLabel(List<SignalReviewProjection> signals) {
  final statuses = signals.map((s) => s.status).toSet();
  if (statuses.length == 1) return signals.first.statusLabel;
  if (statuses.contains(SignalStatus.open.dbValue)) {
    return signalStatusLabel(SignalStatus.open.dbValue);
  }
  if (statuses.contains(SignalStatus.investigating.dbValue)) {
    return signalStatusLabel(SignalStatus.investigating.dbValue);
  }
  if (statuses.contains(SignalStatus.deferred.dbValue)) {
    return signalStatusLabel(SignalStatus.deferred.dbValue);
  }
  return signals.first.statusLabel;
}

String _dominantSeverityLabel(List<SignalReviewProjection> signals) {
  final severities = signals.map((s) => s.severity).toSet();
  if (severities.contains(SignalSeverity.critical.dbValue)) {
    return signalSeverityLabel(SignalSeverity.critical.dbValue);
  }
  if (severities.contains(SignalSeverity.review.dbValue)) {
    return signalSeverityLabel(SignalSeverity.review.dbValue);
  }
  return signals.first.severityLabel;
}

String _groupKeyForSignal(Signal signal) {
  final family = _familyForSignal(signal);
  final base = [
    'family=${family.key.name}',
    'type=${signal.signalType}',
    'trial=${signal.trialId}',
    'session=${signal.sessionId ?? 'none'}',
    'status=${signal.status}',
    'severity=${signal.severity}',
  ];

  if (family.key == SignalFamilyKey.singleton) {
    return [
      ...base,
      'signal=${signal.id}',
    ].join('|');
  }

  return [
    ...base,
    ...family.keyParts,
  ].join('|');
}

_SignalFamilyAssignment _familyForSignal(Signal signal) {
  final ref = _decodeReferenceContext(signal.referenceContext);
  final type = signal.signalType;
  final sessionId = signal.sessionId;
  final seType = ref?.seType;

  if (type == SignalType.replicationWarning.dbValue && sessionId != null) {
    return _SignalFamilyAssignment(
      key: SignalFamilyKey.replicationPattern,
      groupingBasis:
          'Grouped because these replication-pattern signals share trial ${signal.trialId} and session $sessionId.',
      keyParts: ['basis=session:$sessionId'],
    );
  }

  if ((type == SignalType.raterDrift.dbValue ||
          type == SignalType.betweenRaterDivergence.dbValue) &&
      sessionId != null &&
      seType != null &&
      seType.isNotEmpty) {
    return _SignalFamilyAssignment(
      key: SignalFamilyKey.raterDivergence,
      groupingBasis:
          'Grouped because these rating-consistency signals share trial ${signal.trialId}, session $sessionId, and assessment family $seType.',
      keyParts: ['basis=session:$sessionId', 'assessment:$seType'],
    );
  }

  if (type == SignalType.causalContextFlag.dbValue &&
      sessionId != null &&
      seType != null &&
      seType.isNotEmpty) {
    return _SignalFamilyAssignment(
      key: SignalFamilyKey.timingWindowReview,
      groupingBasis:
          'Grouped because these treatment-timing signals share trial ${signal.trialId}, session $sessionId, and assessment family $seType.',
      keyParts: ['basis=session:$sessionId', 'assessment:$seType'],
    );
  }

  if (type == SignalType.aovPrediction.dbValue &&
      sessionId != null &&
      seType != null &&
      seType.isNotEmpty) {
    return _SignalFamilyAssignment(
      key: SignalFamilyKey.untreatedCheckVariance,
      groupingBasis:
          'Grouped because these untreated-check reliability signals share trial ${signal.trialId}, session $sessionId, and assessment family $seType.',
      keyParts: ['basis=session:$sessionId', 'assessment:$seType'],
    );
  }

  return _SignalFamilyAssignment(
    key: SignalFamilyKey.singleton,
    groupingBasis:
        'Handled on its own because this signal does not have enough structured family context for grouping.',
    keyParts: ['signal:${signal.id}'],
  );
}

class _SignalFamilyAssignment {
  const _SignalFamilyAssignment({
    required this.key,
    required this.groupingBasis,
    required this.keyParts,
  });

  final SignalFamilyKey key;
  final String groupingBasis;
  final List<String> keyParts;
}

SignalReferenceContext? _decodeReferenceContext(String raw) {
  try {
    return SignalReferenceContext.decodeJson(raw);
  } catch (_) {
    return null;
  }
}

List<int> _sortedUniqueNullable(Iterable<int?> values) {
  final unique = values.whereType<int>().toSet().toList()..sort();
  return unique;
}

SignalOperationalState _operationalStateForStatus(String status) =>
    switch (status) {
      'open' => SignalOperationalState.needsAction,
      'investigating' => SignalOperationalState.underReview,
      'deferred' => SignalOperationalState.reviewLater,
      'resolved' ||
      'suppressed' ||
      'expired' =>
        SignalOperationalState.historical,
      _ => SignalOperationalState.needsAction,
    };

String _plainLabel(String raw) {
  final words = raw
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => part.trim().toLowerCase())
      .toList();
  if (words.isEmpty) return raw;
  final first = words.first;
  return [
    first[0].toUpperCase() + first.substring(1),
    ...words.skip(1),
  ].join(' ');
}
