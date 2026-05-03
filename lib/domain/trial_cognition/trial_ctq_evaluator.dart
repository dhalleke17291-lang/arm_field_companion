import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import 'trial_ctq_dto.dart';

/// CTQ V1 deterministic evaluator.
///
/// Evaluates available CTQ factors from existing app data.
/// Factors with no safe evidence source return [TrialCtqItemDto.status] == 'unknown'.
///
/// Evaluated: plot_completeness, photo_evidence, gps_evidence,
///   treatment_identity, rater_consistency, application_timing, rating_window.
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
  ]);

  final treatments = results[0] as List<Treatment>;
  final photos = results[1] as List<Photo>;
  final recordedRatings = results[2] as List<RatingRecord>;
  final allPlots = results[3] as List<Plot>;
  final openSignals = results[4] as List<Signal>;
  final applications = results[5] as List<TrialApplicationEvent>;

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
      'application_timing' =>
        _evalApplicationTiming(factor, applications, treatments),
      'rating_window' => _evalRatingWindow(factor, recordedRatings),
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
) {
  if (treatments.isEmpty) {
    return _item(
      factor,
      status: 'unknown',
      evidenceSummary: 'No treatments defined.',
      reason: 'Application timing cannot be evaluated without treatments.',
    );
  }
  if (applications.isNotEmpty) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '${applications.length} application record(s).',
      reason: 'Application records exist for this trial.',
    );
  }
  return _item(
    factor,
    status: 'missing',
    evidenceSummary: 'No applications recorded.',
    reason: 'No application records have been recorded.',
  );
}

TrialCtqItemDto _evalRatingWindow(
  CtqFactorDefinition factor,
  List<RatingRecord> recordedRatings,
) {
  if (recordedRatings.isNotEmpty) {
    return _item(
      factor,
      status: 'satisfied',
      evidenceSummary: '${recordedRatings.length} recorded rating(s).',
      reason: 'Rating evidence is present.',
    );
  }
  return _item(
    factor,
    status: 'missing',
    evidenceSummary: 'No recorded ratings.',
    reason: 'No rating assessments have been recorded.',
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
