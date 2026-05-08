import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/utils/check_treatment_helper.dart';
import '../models/plot_analysis_models.dart';
import '../utils/plot_analysis_utils.dart';

/// Per-treatment distribution stats for a single session + assessment.
final plotDistributionProvider = FutureProvider.autoDispose
    .family<DistributionResult, PlotAnalysisParams>((ref, params) async {
  final ratings =
      ref.watch(sessionRatingsProvider(params.sessionId)).valueOrNull ??
          const <RatingRecord>[];
  final treatments =
      ref.watch(treatmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Treatment>[];
  final assignments =
      ref.watch(assignmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Assignment>[];

  // map plotPk → treatmentId
  final assignmentByPlot = {for (final a in assignments) a.plotId: a};

  // filter to this assessment, numeric, non-VOID, non-guard
  final filtered = ratings.where((r) =>
      r.assessmentId == params.assessmentId &&
      r.resultStatus == 'RECORDED' &&
      r.numericValue != null);

  // group values by treatmentId
  final valuesByTreatment = <int, List<double>>{};
  for (final r in filtered) {
    final trtId =
        assignmentByPlot[r.plotPk]?.treatmentId;
    if (trtId == null) continue;
    (valuesByTreatment[trtId] ??= <double>[]).add(r.numericValue!);
  }

  // compute shared scale across all treatments for this assessment
  final allValues =
      valuesByTreatment.values.expand((v) => v).toList();
  double scaleMin = 0;
  double scaleMax = 100;
  if (allValues.isNotEmpty) {
    final dataMin = allValues.reduce(math.min);
    final dataMax = allValues.reduce(math.max);
    final range = dataMax - dataMin;
    final padding = math.max(range * 0.15, 5.0);
    scaleMin = (dataMin - padding).floorToDouble();
    scaleMax = (dataMax + padding).ceilToDouble();
    if (dataMin >= 0 && scaleMin < 0) scaleMin = 0;
    scaleMin = (scaleMin / 5).floorToDouble() * 5;
    scaleMax = (scaleMax / 5).ceilToDouble() * 5;
  }

  // build per-treatment distributions (only treatments with data)
  final treatmentMap = {for (final t in treatments) t.id: t};
  final dists = <TreatmentDistribution>[];
  for (final t in treatments) {
    final vals = valuesByTreatment[t.id];
    if (vals == null || vals.isEmpty) continue;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final sd = computeSD(vals);
    final outlierIndices = detectOutlierIndices(vals);
    final sorted = List<double>.from(vals)..sort();
    final q = computeQuartiles(vals);
    dists.add(TreatmentDistribution(
      treatmentId: t.id,
      treatmentCode: t.code,
      treatmentName: t.name.isNotEmpty ? t.name : t.code,
      isCheck: isCheckTreatment(t),
      n: vals.length,
      mean: mean,
      sd: sd,
      min: sorted.first,
      q1: q.q1,
      median: q.median,
      q3: q.q3,
      max: sorted.last,
      values: vals,
      scaleMin: scaleMin,
      scaleMax: scaleMax,
      hasOutliers: outlierIndices.isNotEmpty,
    ));
  }

  // preserve treatment sort order
  final sortedTreatmentIds = treatmentMap.keys.toList();
  dists.sort((a, b) =>
      sortedTreatmentIds.indexOf(a.treatmentId) -
      sortedTreatmentIds.indexOf(b.treatmentId));

  final pooledCv = dists.isEmpty
      ? null
      : computePooledCV(
          means: dists.map((d) => d.mean).toList(),
          sds: dists.map((d) => d.sd).toList(),
          ns: dists.map((d) => d.n).toList(),
        );

  return DistributionResult(treatments: dists, pooledCv: pooledCv);
});

/// Cross-assessment-time-point mean progression per treatment.
final plotProgressionProvider = FutureProvider.autoDispose
    .family<ProgressionResult, PlotProgressionParams>((ref, params) async {
  final trialAssessments =
      ref.watch(trialAssessmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <TrialAssessment>[];
  final allRatings = await ref
      .watch(allSessionRatingsForTrialProvider(params.trialId).future);
  final treatments =
      ref.watch(treatmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Treatment>[];
  final assignments =
      ref.watch(assignmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Assignment>[];

  // sort time points by sortOrder
  final sortedTimePoints = List<TrialAssessment>.from(trialAssessments)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  // x-axis labels: displayNameOverride if set, else TA{i+1}
  final assessmentLabels = [
    for (var i = 0; i < sortedTimePoints.length; i++)
      (sortedTimePoints[i].displayNameOverride?.trim().isNotEmpty ?? false)
          ? sortedTimePoints[i].displayNameOverride!.trim()
          : 'TA${i + 1}',
  ];

  // map legacyAssessmentId → ta.id for rating lookup
  final legacyIdToTaId = <int, int>{};
  for (final ta in sortedTimePoints) {
    if (ta.legacyAssessmentId != null) {
      legacyIdToTaId[ta.legacyAssessmentId!] = ta.id;
    }
  }

  // map plotPk → treatmentId
  final assignmentByPlot = {for (final a in assignments) a.plotId: a};

  // group ratings by taId → treatmentId → values
  final byTaByTreatment = <int, Map<int, List<double>>>{};
  for (final r in allRatings) {
    if (r.resultStatus != 'RECORDED') continue;
    if (r.numericValue == null) continue;
    final taId = legacyIdToTaId[r.assessmentId];
    if (taId == null) continue;
    final trtId = assignmentByPlot[r.plotPk]?.treatmentId;
    if (trtId == null) continue;
    ((byTaByTreatment[taId] ??= {})[trtId] ??= []).add(r.numericValue!);
  }

  // build per-treatment series
  final series = <ProgressionSeries>[];
  for (final t in treatments) {
    final points = <ProgressionPoint>[];
    for (var i = 0; i < sortedTimePoints.length; i++) {
      final ta = sortedTimePoints[i];
      final vals = byTaByTreatment[ta.id]?[t.id];
      if (vals == null || vals.isEmpty) continue;
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      points.add(ProgressionPoint(
        sessionId: ta.id,
        sessionLabel: assessmentLabels[i],
        mean: mean,
        n: vals.length,
      ));
    }
    if (points.isEmpty) continue;
    series.add(ProgressionSeries(
      treatmentId: t.id,
      treatmentCode: t.code,
      treatmentName: t.name.isNotEmpty ? t.name : t.code,
      isCheck: isCheckTreatment(t),
      points: points,
    ));
  }

  // only include labels for time points that have data in at least one series
  final taIdsWithData = series
      .expand((s) => s.points)
      .map((p) => p.sessionId)
      .toSet();
  final filteredLabels = <String>[];
  for (var i = 0; i < sortedTimePoints.length; i++) {
    if (taIdsWithData.contains(sortedTimePoints[i].id)) {
      filteredLabels.add(assessmentLabels[i]);
    }
  }

  return ProgressionResult(
    series: series,
    assessmentName: 'Assessment',
    sessionLabels: filteredLabels.isEmpty ? assessmentLabels : filteredLabels,
  );
});
