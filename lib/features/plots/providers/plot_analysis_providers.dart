import 'dart:math' as math;

import 'package:collection/collection.dart';
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

  return DistributionResult(
    treatments: dists,
    pooledCv: pooledCv,
    sessionId: params.sessionId,
  );
});

/// Cross-session mean progression per treatment for a selected assessment type.
final plotProgressionProvider = FutureProvider.autoDispose
    .family<ProgressionResult, PlotProgressionParams>((ref, params) async {
  final trialAssessments =
      ref.watch(trialAssessmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <TrialAssessment>[];
  final allRatings =
      await ref.watch(allSessionRatingsForTrialProvider(params.trialId).future);
  final treatments =
      ref.watch(treatmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Treatment>[];
  final assignments =
      ref.watch(assignmentsForTrialProvider(params.trialId)).valueOrNull ??
          const <Assignment>[];
  final sessions =
      ref.watch(sessionsForTrialProvider(params.trialId)).valueOrNull ??
          const <Session>[];

  // Find the trial_assessment row for the selected legacy assessment id.
  final selectedTA = trialAssessments.firstWhereOrNull(
    (ta) => ta.legacyAssessmentId == params.assessmentId,
  );
  if (selectedTA == null || sessions.isEmpty) {
    return const ProgressionResult(
      series: [],
      assessmentLabels: [],
      xAxisMode: ProgressionXAxisMode.sessions,
      patternNotes: [],
    );
  }

  // x-axis: one label per session, ordered by startedAt (from provider).
  final sessionLabels = sessions.map((s) => s.name).toList();

  // map plotPk → treatmentId
  final assignmentByPlot = {for (final a in assignments) a.plotId: a};

  // group ratings by sessionId → treatmentId → values for the selected assessment
  final bySessionByTreatment = <int, Map<int, List<double>>>{};
  for (final r in allRatings) {
    if (r.resultStatus != 'RECORDED') continue;
    if (r.numericValue == null) continue;
    if (!_ratingMatchesTA(r, selectedTA)) continue;
    final trtId = assignmentByPlot[r.plotPk]?.treatmentId;
    if (trtId == null) continue;
    ((bySessionByTreatment[r.sessionId] ??= {})[trtId] ??= [])
        .add(r.numericValue!);
  }

  // build per-treatment series
  final series = <ProgressionSeries>[];
  for (final t in treatments) {
    final points = <ProgressionPoint>[];
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      final vals = bySessionByTreatment[session.id]?[t.id];
      if (vals == null || vals.isEmpty) continue;
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      points.add(ProgressionPoint(
        sessionId: session.id,
        sessionLabel: sessionLabels[i],
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

  // only include labels for sessions that have data in at least one series
  final sessionIdsWithData = series
      .expand((s) => s.points)
      .map((p) => p.sessionId)
      .toSet();
  final filteredLabels = <String>[];
  for (var i = 0; i < sessions.length; i++) {
    if (sessionIdsWithData.contains(sessions[i].id)) {
      filteredLabels.add(sessionLabels[i]);
    }
  }

  return ProgressionResult(
    series: series,
    assessmentLabels: filteredLabels.isEmpty ? sessionLabels : filteredLabels,
    xAxisMode: ProgressionXAxisMode.sessions,
    patternNotes: computeProgressionPatternNotes(series),
  );
});

bool _ratingMatchesTA(RatingRecord r, TrialAssessment ta) {
  if (r.trialAssessmentId != null && r.trialAssessmentId == ta.id) {
    return true;
  }
  if (ta.legacyAssessmentId != null &&
      r.assessmentId == ta.legacyAssessmentId) {
    return true;
  }
  return false;
}
