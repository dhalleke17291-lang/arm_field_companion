import 'dart:math' show sqrt;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/utils/check_treatment_helper.dart';
import '../../features/derived/domain/trial_statistics.dart';
import 'trial_coherence_dto.dart';
import 'trial_interpretation_risk_dto.dart';

Future<TrialInterpretationRiskDto> computeTrialInterpretationRiskDto({
  required AppDatabase db,
  required int trialId,
  required TrialCoherenceDto coherenceDto,
}) async {
  final results = await Future.wait([
    // 0: current trial purpose (non-superseded)
    (db.select(db.trialPurposes)
          ..where(
            (p) => p.trialId.equals(trialId) & p.supersededAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.version)])
          ..limit(1))
        .getSingleOrNull(),
    // 1: assessments
    (db.select(db.assessments)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 2: current, non-deleted, RECORDED rating records
    (db.select(db.ratingRecords)
          ..where((r) =>
              r.trialId.equals(trialId) &
              r.isCurrent.equals(true) &
              r.isDeleted.equals(false) &
              r.resultStatus.equals('RECORDED')))
        .get(),
    // 3: non-deleted treatments
    (db.select(db.treatments)
          ..where(
            (t) => t.trialId.equals(trialId) & t.isDeleted.equals(false),
          ))
        .get(),
    // 4: non-deleted plots
    (db.select(db.plots)
          ..where(
            (p) => p.trialId.equals(trialId) & p.isDeleted.equals(false),
          ))
        .get(),
    // 5: assignments
    (db.select(db.assignments)
          ..where((a) => a.trialId.equals(trialId)))
        .get(),
    // 6: open/investigating rater signals
    (db.select(db.signals)
          ..where((s) =>
              s.trialId.equals(trialId) &
              s.signalType.isIn(
                  ['rater_drift', 'between_rater_divergence']) &
              s.status.isIn(['open', 'investigating'])))
        .get(),
  ]);

  final purpose = results[0] as TrialPurpose?;
  final assessments = results[1] as List<Assessment>;
  final recordedRatings = results[2] as List<RatingRecord>;
  final treatments = results[3] as List<Treatment>;
  final allPlots = results[4] as List<Plot>;
  final assignments = results[5] as List<Assignment>;
  final raterSignals = results[6] as List<Signal>;

  final analyzablePlots = allPlots.where(isAnalyzablePlot).toList();

  // Build plot → treatmentId map (assignments override plot.treatmentId).
  final plotTreatmentMap = <int, int>{};
  for (final p in allPlots) {
    if (p.treatmentId != null) plotTreatmentMap[p.id] = p.treatmentId!;
  }
  for (final a in assignments) {
    if (a.treatmentId != null) plotTreatmentMap[a.plotId] = a.treatmentId!;
  }

  final factors = [
    _factorDataVariability(
        purpose, assessments, recordedRatings, treatments, plotTreatmentMap),
    _factorUntreatedCheckPressure(
        treatments, allPlots, assignments, recordedRatings, plotTreatmentMap),
    _factorApplicationTimingDeviation(coherenceDto),
    _factorPrimaryEndpointCompleteness(
        purpose, assessments, recordedRatings, analyzablePlots),
    _factorRaterConsistency(raterSignals),
  ];

  return TrialInterpretationRiskDto(
    riskLevel: _aggregateRiskLevel(factors),
    factors: List.unmodifiable(factors),
    computedAt: DateTime.now(),
  );
}

// ── Factor 1: data variability ────────────────────────────────────────────────

TrialRiskFactorDto _factorDataVariability(
  TrialPurpose? purpose,
  List<Assessment> assessments,
  List<RatingRecord> recordedRatings,
  List<Treatment> treatments,
  Map<int, int> plotTreatmentMap,
) {
  const key = 'data_variability';
  const label = 'Primary endpoint data variability';
  const sources = ['trial_purposes', 'assessments', 'rating_records'];

  if (purpose?.primaryEndpoint == null) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'No primary endpoint defined — CV cannot be assessed.',
      sourceFields: sources,
    );
  }

  final endpoint = purpose!.primaryEndpoint!.toLowerCase();
  Assessment? matched;
  for (final a in assessments) {
    final name = a.name.toLowerCase();
    if (endpoint.contains(name) || name.contains(endpoint)) {
      matched = a;
      break;
    }
  }

  if (matched == null) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason:
          'No assessment matching "${purpose.primaryEndpoint}" — CV cannot be computed.',
      sourceFields: sources,
    );
  }

  final assessmentId = matched.id;
  final groups = <int, List<double>>{};
  for (final r in recordedRatings) {
    if (r.assessmentId != assessmentId) continue;
    final tid = plotTreatmentMap[r.plotPk];
    if (tid == null) continue;
    final v = r.numericValue;
    if (v == null) continue;
    groups.putIfAbsent(tid, () => []).add(v);
  }

  if (groups.isEmpty) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason:
          'No numeric ratings for "${matched.name}" — CV cannot be computed.',
      sourceFields: sources,
    );
  }

  final means = <TreatmentMean>[];
  for (final entry in groups.entries) {
    final vals = entry.value;
    final n = vals.length;
    final mean = vals.reduce((a, b) => a + b) / n;
    final variance = n > 1
        ? vals
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            (n - 1)
        : 0.0;
    final sd = sqrt(variance);
    Treatment? trt;
    for (final t in treatments) {
      if (t.id == entry.key) {
        trt = t;
        break;
      }
    }
    means.add(TreatmentMean(
      treatmentCode: trt?.code ?? '?',
      mean: mean,
      standardDeviation: sd,
      standardError: n > 0 ? sd / sqrt(n.toDouble()) : 0.0,
      n: n,
      min: vals.reduce((a, b) => a < b ? a : b),
      max: vals.reduce((a, b) => a > b ? a : b),
      isPreliminary: false,
    ));
  }

  final cv = computeTrialCV(means);

  if (cv == null) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason:
          'Insufficient data to compute CV for "${matched.name}" (need ≥2 observations, non-zero mean).',
      sourceFields: sources,
    );
  }

  final cvStr = cv.toStringAsFixed(1);
  if (cv >= kCvHighThreshold) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'high',
      reason:
          '${matched.name}: CV = $cvStr% — exceeds high threshold '
          '(${kCvHighThreshold.toStringAsFixed(0)}%, EPPO PP1/152(4)).',
      sourceFields: sources,
    );
  }
  if (cv >= kCvReviewThreshold) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'moderate',
      reason:
          '${matched.name}: CV = $cvStr% — above review threshold '
          '(${kCvReviewThreshold.toStringAsFixed(0)}%, EPPO PP1/152(4)).',
      sourceFields: sources,
    );
  }
  return TrialRiskFactorDto(
    factorKey: key,
    label: label,
    severity: 'none',
    reason: '${matched.name}: CV = $cvStr% — within acceptable range.',
    sourceFields: sources,
  );
}

// ── Factor 2: untreated check pressure ───────────────────────────────────────

// Threshold below which check mean is considered "low but present".
const _kCheckLowPressureThreshold = 10.0;

TrialRiskFactorDto _factorUntreatedCheckPressure(
  List<Treatment> treatments,
  List<Plot> allPlots,
  List<Assignment> assignments,
  List<RatingRecord> recordedRatings,
  Map<int, int> plotTreatmentMap,
) {
  const key = 'untreated_check_pressure';
  const label = 'Untreated check pressure';
  const sources = ['treatments', 'rating_records', 'assignments'];

  final checkTreatments = treatments.where(isCheckTreatment).toList();

  if (checkTreatments.isEmpty) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'No untreated check treatment identified.',
      sourceFields: sources,
    );
  }

  final checkIds = {for (final t in checkTreatments) t.id};

  final checkValues = <double>[];
  for (final r in recordedRatings) {
    final tid = plotTreatmentMap[r.plotPk];
    if (tid == null || !checkIds.contains(tid)) continue;
    final v = r.numericValue;
    if (v != null) checkValues.add(v);
  }

  if (checkValues.isEmpty) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'No ratings found for untreated check plots.',
      sourceFields: sources,
    );
  }

  final mean = checkValues.reduce((a, b) => a + b) / checkValues.length;
  final meanStr = mean.toStringAsFixed(1);

  if (mean.abs() < 1e-9) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'high',
      reason:
          'Untreated check mean = $meanStr — at scale floor. '
          'Treatment separation is unlikely to be interpretable.',
      sourceFields: sources,
    );
  }

  if (mean < _kCheckLowPressureThreshold) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'moderate',
      reason:
          'Untreated check mean = $meanStr — low pressure. '
          'Treatment differences may be difficult to detect.',
      sourceFields: sources,
    );
  }

  return TrialRiskFactorDto(
    factorKey: key,
    label: label,
    severity: 'none',
    reason: 'Untreated check mean = $meanStr — adequate pressure for treatment separation.',
    sourceFields: sources,
  );
}

// ── Factor 3: application timing deviation ────────────────────────────────────

TrialRiskFactorDto _factorApplicationTimingDeviation(
    TrialCoherenceDto coherenceDto) {
  const key = 'application_timing_deviation';
  const label = 'Application timing deviation';
  const sources = ['trial_coherence_provider'];

  TrialCoherenceCheckDto? timingCheck;
  for (final c in coherenceDto.checks) {
    if (c.checkKey == 'application_timing_within_claim_window') {
      timingCheck = c;
      break;
    }
  }

  if (timingCheck == null) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'Application timing coherence check not available.',
      sourceFields: sources,
    );
  }

  return switch (timingCheck.status) {
    'aligned' => const TrialRiskFactorDto(
        factorKey: key,
        label: label,
        severity: 'none',
        reason: 'Application timing is within the claim window.',
        sourceFields: sources,
      ),
    'review_needed' => TrialRiskFactorDto(
        factorKey: key,
        label: label,
        severity: 'moderate',
        reason: timingCheck.reason,
        sourceFields: sources,
      ),
    'acknowledged' => TrialRiskFactorDto(
        factorKey: key,
        label: label,
        severity: 'moderate',
        reason: 'Timing deviation noted — ${timingCheck.reason}',
        sourceFields: sources,
      ),
    _ => const TrialRiskFactorDto(
        factorKey: key,
        label: label,
        severity: 'cannot_evaluate',
        reason: 'Application timing coherence check could not be evaluated.',
        sourceFields: sources,
      ),
  };
}

// ── Factor 4: primary endpoint completeness ───────────────────────────────────

TrialRiskFactorDto _factorPrimaryEndpointCompleteness(
  TrialPurpose? purpose,
  List<Assessment> assessments,
  List<RatingRecord> recordedRatings,
  List<Plot> analyzablePlots,
) {
  const key = 'primary_endpoint_completeness';
  const label = 'Primary endpoint data completeness';
  const sources = ['trial_purposes', 'assessments', 'rating_records', 'plots'];

  if (purpose?.primaryEndpoint == null) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'No primary endpoint defined — completeness cannot be assessed.',
      sourceFields: sources,
    );
  }

  final endpoint = purpose!.primaryEndpoint!.toLowerCase();
  Assessment? matched;
  for (final a in assessments) {
    final name = a.name.toLowerCase();
    if (endpoint.contains(name) || name.contains(endpoint)) {
      matched = a;
      break;
    }
  }

  if (matched == null) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason:
          'No assessment matching "${purpose.primaryEndpoint}" — completeness cannot be determined.',
      sourceFields: sources,
    );
  }

  if (analyzablePlots.isEmpty) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'cannot_evaluate',
      reason: 'No analyzable plots defined.',
      sourceFields: sources,
    );
  }

  final assessmentId = matched.id;
  final ratedPlotPks = <int>{};
  for (final r in recordedRatings) {
    if (r.assessmentId == assessmentId && r.numericValue != null) {
      ratedPlotPks.add(r.plotPk);
    }
  }

  final totalPlots = analyzablePlots.length;
  final ratedCount = ratedPlotPks
      .where((pk) => analyzablePlots.any((p) => p.id == pk))
      .length;

  if (ratedCount == 0) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'high',
      reason:
          'No plots rated for "${matched.name}" — primary endpoint has no data.',
      sourceFields: sources,
    );
  }

  final pct = (ratedCount / totalPlots) * 100.0;
  final pctStr = pct.toStringAsFixed(0);

  if (pct < 80.0) {
    return TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'moderate',
      reason:
          '${matched.name}: $ratedCount of $totalPlots plots rated ($pctStr%) — '
          'below the 80% completeness threshold.',
      sourceFields: sources,
    );
  }

  return TrialRiskFactorDto(
    factorKey: key,
    label: label,
    severity: 'none',
    reason:
        '${matched.name}: $ratedCount of $totalPlots plots rated ($pctStr%).',
    sourceFields: sources,
  );
}

// ── Factor 5: rater consistency ───────────────────────────────────────────────

TrialRiskFactorDto _factorRaterConsistency(List<Signal> raterSignals) {
  const key = 'rater_consistency';
  const label = 'Rater consistency';
  const sources = ['signals'];

  if (raterSignals.isEmpty) {
    return const TrialRiskFactorDto(
      factorKey: key,
      label: label,
      severity: 'none',
      reason: 'No open rater drift or between-rater divergence signals.',
      sourceFields: sources,
    );
  }

  final count = raterSignals.length;
  final details = raterSignals
      .map((s) => s.consequenceText)
      .where((t) => t.isNotEmpty)
      .take(3)
      .join('; ');

  return TrialRiskFactorDto(
    factorKey: key,
    label: label,
    severity: 'moderate',
    reason: '$count open rater signal(s). $details',
    sourceFields: sources,
  );
}

// ── Risk level aggregation ─────────────────────────────────────────────────────

String _aggregateRiskLevel(List<TrialRiskFactorDto> factors) {
  var anyHigh = false;
  var anyModerate = false;
  var allNone = true;

  for (final f in factors) {
    switch (f.severity) {
      case 'high':
        anyHigh = true;
        allNone = false;
      case 'moderate':
        anyModerate = true;
        allNone = false;
      case 'cannot_evaluate':
        allNone = false;
      case 'none':
        break;
    }
  }

  if (anyHigh) return 'high';
  if (anyModerate) return 'moderate';
  if (allNone) return 'low';
  // Some factors cannot_evaluate, none at high/moderate.
  return 'cannot_evaluate';
}
