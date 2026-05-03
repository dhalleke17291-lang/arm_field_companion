import 'dart:math' show sqrt;

import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/utils/check_treatment_helper.dart';
import 'trial_ctq_dto.dart';

/// CTQ V1 deterministic evaluator.
///
/// Evaluates available CTQ factors from existing app data.
/// Factors with no safe evidence source return [TrialCtqItemDto.status] == 'unknown'.
///
/// Evaluated: plot_completeness, photo_evidence, gps_evidence,
///   treatment_identity, rater_consistency, application_timing, rating_window,
///   data_variance, untreated_check_pressure.
/// Intentionally unknown: disease_pressure, crop_stage, rainfall_after_application.
Future<TrialCtqDto> computeTrialCtqDtoV1(
  AppDatabase db,
  int trialId,
  List<CtqFactorDefinition> factors,
) async {
  if (factors.isEmpty) {
    return TrialCtqDto(
      trialId: trialId,
      ctqItems: const [],
      blockerCount: 0,
      warningCount: 0,
      reviewCount: 0,
      satisfiedCount: 0,
      overallStatus: 'unknown',
    );
  }

  // ── Parallel evidence queries ─────────────────────────────────────────────
  final results = await Future.wait([
    // 0: non-deleted treatments
    (db.select(db.treatments)
          ..where((t) => t.trialId.equals(trialId) & t.isDeleted.equals(false)))
        .get(),
    // 1: non-deleted photos
    (db.select(db.photos)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get(),
    // 2: current, non-deleted, RECORDED ratings
    (db.select(db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false) &
              r.resultStatus.equals('RECORDED')))
        .get(),
    // 3: non-deleted plots
    (db.select(db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false)))
        .get(),
    // 4: open signals (open | deferred | investigating)
    (db.select(db.signals)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.status.isIn(['open', 'deferred', 'investigating'])))
        .get(),
    // 5: application events (no soft-delete column on this table)
    (db.select(db.trialApplicationEvents)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 6: assignments (for correct plot→treatment mapping)
    (db.select(db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 7: treatment components (for pesticideCategory check)
    (db.select(db.treatmentComponents)
          ..where(
              (c) => c.trialId.equals(trialId) & c.isDeleted.equals(false)))
        .get(),
  ]);

  final treatments = results[0] as List<Treatment>;
  final photos = results[1] as List<Photo>;
  final recordedRatings = results[2] as List<RatingRecord>;
  final allPlots = results[3] as List<Plot>;
  final openSignals = results[4] as List<Signal>;
  final applications = results[5] as List<TrialApplicationEvent>;
  final assignments = results[6] as List<Assignment>;
  final treatmentComponents = results[7] as List<TreatmentComponent>;

  final analyzablePlots = allPlots.where(isAnalyzablePlot).toList();
  final ratedPlotPks = recordedRatings.map((r) => r.plotPk).toSet();
  final gpsCount = recordedRatings
      .where((r) => r.capturedLatitude != null && r.capturedLongitude != null)
      .length;

  // Signal classification
  final raterSignals = openSignals
      .where((s) =>
          s.signalType == 'rater_drift' ||
          s.signalType == 'between_rater_divergence')
      .toList();
  final timingWindowSignals = openSignals
      .where((s) => s.signalType == 'causal_context_flag')
      .toList();
  final hasCriticalSignals = openSignals.any((s) => s.severity == 'critical');
  final hasProtocolDivergenceSignals =
      openSignals.any((s) => s.signalType == 'protocol_divergence');

  // ── Evaluate each factor ─────────────────────────────────────────────────
  final items = <TrialCtqItemDto>[];

  for (final factor in factors) {
    final item = switch (factor.factorKey) {
      'plot_completeness' =>
        _evalPlotCompleteness(factor, analyzablePlots, ratedPlotPks),
      'photo_evidence' => _evalPhotoEvidence(factor, photos),
      'gps_evidence' =>
        _evalGpsEvidence(factor, recordedRatings, gpsCount),
      'treatment_identity' => _evalTreatmentIdentity(factor, treatments),
      'rater_consistency' => _evalRaterConsistency(factor, raterSignals),
      'application_timing' => _evalApplicationTiming(
          factor, applications, treatments, treatmentComponents),
      'rating_window' =>
        _evalRatingWindow(factor, recordedRatings, timingWindowSignals),
      'data_variance' => _evalDataVariance(factor, recordedRatings),
      'untreated_check_pressure' => _evalUntreatedCheckPressure(
          factor, treatments, allPlots, assignments, recordedRatings),
      _ => _unknownFactor(factor),
    };
    items.add(item);
  }

  // ── Counts ────────────────────────────────────────────────────────────────
  int blockerCount = 0;
  int warningCount = 0;
  int reviewCount = 0;
  int satisfiedCount = 0;
  for (final item in items) {
    switch (item.status) {
      case 'blocked':
        blockerCount++;
      case 'missing':
        warningCount++;
      case 'review_needed':
        reviewCount++;
      case 'satisfied':
        satisfiedCount++;
    }
  }

  // ── Overall status ────────────────────────────────────────────────────────
  final allUnknown = items.every((i) => i.status == 'unknown');

  final String overallStatus;
  if (allUnknown && !hasCriticalSignals && !hasProtocolDivergenceSignals) {
    overallStatus = 'unknown';
  } else if (blockerCount > 0 ||
      reviewCount > 0 ||
      hasCriticalSignals ||
      hasProtocolDivergenceSignals) {
    overallStatus = 'review_needed';
  } else if (warningCount > 0) {
    overallStatus = 'incomplete';
  } else {
    final evaluated = items.where((i) => i.status != 'unknown');
    overallStatus = evaluated.isNotEmpty &&
            evaluated.every((i) => i.status == 'satisfied')
        ? 'ready_for_review'
        : 'unknown';
  }

  return TrialCtqDto(
    trialId: trialId,
    ctqItems: List.unmodifiable(items),
    blockerCount: blockerCount,
    warningCount: warningCount,
    reviewCount: reviewCount,
    satisfiedCount: satisfiedCount,
    overallStatus: overallStatus,
  );
}

// ── Factor evaluators ─────────────────────────────────────────────────────────

TrialCtqItemDto _evalPlotCompleteness(
  CtqFactorDefinition factor,
  List<Plot> analyzablePlots,
  Set<int> ratedPlotPks,
) {
  if (analyzablePlots.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No analyzable plots defined.',
      reason: 'No analyzable plots are defined for this trial.',
    );
  }
  final total = analyzablePlots.length;
  final rated =
      ratedPlotPks.intersection(analyzablePlots.map((p) => p.id).toSet()).length;

  if (rated == total) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '$rated/$total plots have recorded ratings.',
      reason: 'All analyzable plots have recorded ratings.',
    );
  } else if (rated > 0) {
    return _item(
      factor,
      status: 'review_needed',
      evidenceSummary: '$rated/$total plots have recorded ratings.',
      reason: 'Rating evidence is partial; review before export.',
    );
  } else {
    return _item(
      factor,
      status: 'missing',
      evidenceSummary: '0/$total plots rated.',
      reason: 'No plot ratings have been recorded.',
    );
  }
}

TrialCtqItemDto _evalPhotoEvidence(
  CtqFactorDefinition factor,
  List<Photo> photos,
) {
  if (photos.isNotEmpty) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '${photos.length} photo(s) attached.',
      reason: 'Photo evidence is present.',
    );
  }
  return _item(
    factor,
    status: 'missing',
    evidenceSummary: 'No photos.',
    reason: 'No photo evidence has been attached.',
  );
}

TrialCtqItemDto _evalGpsEvidence(
  CtqFactorDefinition factor,
  List<RatingRecord> recordedRatings,
  int gpsCount,
) {
  if (recordedRatings.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No ratings to check.',
      reason: 'No rating records exist to evaluate GPS presence.',
    );
  }
  if (gpsCount > 0) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '$gpsCount rating(s) with GPS.',
      reason: 'GPS evidence is present.',
    );
  }
  return _item(
    factor,
    status: 'missing',
    evidenceSummary: 'No GPS captured.',
    reason: 'No GPS coordinates have been captured for any rating.',
  );
}

TrialCtqItemDto _evalTreatmentIdentity(
  CtqFactorDefinition factor,
  List<Treatment> treatments,
) {
  if (treatments.isNotEmpty) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '${treatments.length} treatment(s) defined.',
      reason: 'Treatment identity exists for this trial.',
    );
  }
  return _item(
    factor,
    status: 'missing',
    evidenceSummary: 'No treatments defined.',
    reason: 'No treatments have been defined for this trial.',
  );
}

TrialCtqItemDto _evalRaterConsistency(
  CtqFactorDefinition factor,
  List<Signal> raterSignals,
) {
  if (raterSignals.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No rater signals detected.',
      reason: 'No rater consistency signals have been raised.',
    );
  }
  final hasCritical = raterSignals.any((s) => s.severity == 'critical');
  return _item(
    factor,
    status: hasCritical ? 'blocked' : 'review_needed',
    evidenceSummary: '${raterSignals.length} open rater signal(s).',
    reason: 'Open rater signals require review.',
  );
}

TrialCtqItemDto _evalApplicationTiming(
  CtqFactorDefinition factor,
  List<TrialApplicationEvent> applications,
  List<Treatment> treatments,
  List<TreatmentComponent> treatmentComponents,
) {
  if (treatments.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No treatments defined.',
      reason: 'Application timing cannot be evaluated without treatments.',
    );
  }
  if (applications.isEmpty) {
    return _item(
      factor,
      status: 'missing',
      evidenceSummary: 'No applications recorded.',
      reason: 'No application events have been recorded.',
    );
  }
  final hasCategorySet =
      treatmentComponents.any((c) => c.pesticideCategory != null);
  if (!hasCategorySet) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '${applications.length} application record(s).',
      reason: 'Application events are present.',
    );
  }
  final hasBbch =
      applications.any((a) => a.growthStageBbchAtApplication != null);
  if (!hasBbch) {
    return _item(
      factor,
      status: 'review_needed',
      evidenceSummary:
          '${applications.length} application record(s); BBCH not captured.',
      reason:
          'Application events exist but BBCH at application has not been recorded. Timing cannot be evaluated.',
    );
  }
  return _item(
    factor,
    status: 'satisfied',
    evidenceSummary:
        '${applications.length} application record(s) with BBCH data.',
    reason:
        'Application timing evidence is present with structured BBCH capture. Window checks will be available once crop profiles are configured.',
  );
}

/// Upgraded from presence-only: also checks for open timing-window signals.
///
/// If [timingWindowSignals] is non-empty, returns review_needed — the signals
/// were raised by [TimingWindowViolationWriter] and require investigation before
/// the rating window can be considered acceptable.
TrialCtqItemDto _evalRatingWindow(
  CtqFactorDefinition factor,
  List<RatingRecord> recordedRatings,
  List<Signal> timingWindowSignals,
) {
  if (recordedRatings.isEmpty) {
    return _item(
      factor,
      status: 'missing',
      evidenceSummary: 'No recorded ratings.',
      reason: 'No rating assessments have been recorded.',
    );
  }
  if (timingWindowSignals.isNotEmpty) {
    return _item(
      factor,
      status: 'review_needed',
      evidenceSummary:
          '${timingWindowSignals.length} open timing-window signal(s).',
      reason:
          'Timing-window signals exist and should be reviewed before interpretation.',
    );
  }
  return _item(
    factor,
    status: 'satisfied',
    evidenceSummary: '${recordedRatings.length} recorded rating(s).',
    reason:
        'Rating evidence is present and no open timing-window signal was found.',
  );
}

/// Evaluates per-assessment CV across all recorded ratings.
///
/// Returns review_needed when any assessment group reaches the high-CV
/// threshold (≥50%, matching the delta-color suppression threshold used
/// elsewhere in the app). Returns unknown when there is insufficient
/// replicate data to compute CV.
TrialCtqItemDto _evalDataVariance(
  CtqFactorDefinition factor,
  List<RatingRecord> recordedRatings,
) {
  if (recordedRatings.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No recorded ratings.',
      reason: 'Not enough rating data to evaluate variance.',
    );
  }

  // Group numeric values by assessmentId (trial-wide, not per-treatment)
  final groups = <int, List<double>>{};
  for (final r in recordedRatings) {
    final v = r.numericValue;
    if (v == null) continue;
    groups.putIfAbsent(r.assessmentId, () => []).add(v);
  }

  if (groups.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No numeric rating values found.',
      reason: 'Not enough numeric data to evaluate variance.',
    );
  }

  // 3 replicates minimum — matches kMinRepsForRepVariability
  const minReps = 3;
  // 50.0 — matches kHighCvDeltaColorSuppressionThreshold in trial_statistics.dart
  const highCvThreshold = 50.0;

  bool anyComputedCv = false;
  bool anyHighCv = false;

  for (final vals in groups.values) {
    if (vals.length < minReps) continue;
    final n = vals.length;
    final mean = vals.reduce((a, b) => a + b) / n;
    if (mean.abs() < 1e-9) continue;
    final variance = vals
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        (n - 1);
    final cv = (sqrt(variance) / mean.abs()) * 100.0;
    anyComputedCv = true;
    if (cv >= highCvThreshold) anyHighCv = true;
  }

  if (!anyComputedCv) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'Fewer than $minReps replicates per assessment.',
      reason: 'Not enough replicate data to evaluate variance.',
    );
  }

  if (anyHighCv) {
    return _item(
      factor,
      status: 'review_needed',
      evidenceSummary: 'High rating variability detected.',
      reason: 'High rating variability may limit treatment separation.',
    );
  }

  return _item(
    factor,
    status: 'satisfied',
    evidenceSummary: 'Rating variability is within the expected range.',
    reason: 'Rating variability is within the expected range.',
  );
}

/// Evaluates whether the untreated check treatment shows a measurable response.
///
/// Uses [isCheckTreatment] to identify check treatments. Returns review_needed
/// only when the check mean is at the absolute floor (zero). Does not apply
/// crop-specific or scale-specific thresholds.
TrialCtqItemDto _evalUntreatedCheckPressure(
  CtqFactorDefinition factor,
  List<Treatment> treatments,
  List<Plot> allPlots,
  List<Assignment> assignments,
  List<RatingRecord> recordedRatings,
) {
  final checkTreatments = treatments.where(isCheckTreatment).toList();

  if (checkTreatments.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No untreated check treatment identified.',
      reason: 'No untreated check treatment was identified for this trial.',
    );
  }

  if (recordedRatings.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No ratings recorded.',
      reason: 'No rating data to evaluate untreated check response.',
    );
  }

  // Build plot → treatmentId map: plot.treatmentId as base, assignments override
  final plotTreatmentMap = <int, int>{};
  for (final p in allPlots) {
    if (p.treatmentId != null) plotTreatmentMap[p.id] = p.treatmentId!;
  }
  for (final a in assignments) {
    if (a.treatmentId != null) plotTreatmentMap[a.plotId] = a.treatmentId!;
  }

  final checkTreatmentIds = {for (final t in checkTreatments) t.id};

  final checkValues = <double>[];
  for (final r in recordedRatings) {
    final tid = plotTreatmentMap[r.plotPk];
    if (tid == null || !checkTreatmentIds.contains(tid)) continue;
    final v = r.numericValue;
    if (v != null) checkValues.add(v);
  }

  if (checkValues.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No ratings found for untreated check plots.',
      reason:
          'No rating data found for the identified untreated check treatment.',
    );
  }

  final checkMean =
      checkValues.reduce((a, b) => a + b) / checkValues.length;

  if (checkMean.abs() < 1e-9) {
    return _item(
      factor,
      status: 'review_needed',
      evidenceSummary: 'Untreated check mean is zero.',
      reason:
          'Untreated check response appears near zero; treatment separation may be difficult to interpret.',
    );
  }

  return _item(
    factor,
    status: 'satisfied',
    evidenceSummary:
        'Untreated check mean: ${checkMean.toStringAsFixed(1)}.',
    reason: 'Untreated check response is present.',
  );
}

TrialCtqItemDto _unknownFactor(CtqFactorDefinition factor) {
  return _item(
    factor,
    status: 'unknown',
    evidenceSummary: 'Not evaluated.',
    reason: 'This factor is not evaluated at this stage.',
  );
}

TrialCtqItemDto _item(
  CtqFactorDefinition factor, {
  required String status,
  required String evidenceSummary,
  required String reason,
}) {
  return TrialCtqItemDto(
    factorKey: factor.factorKey,
    label: factor.factorLabel,
    importance: factor.importance,
    status: status,
    evidenceSummary: evidenceSummary,
    reason: reason,
    source: factor.source,
  );
}
