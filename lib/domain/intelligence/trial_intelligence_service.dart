import 'dart:math' show sqrt;

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import '../../features/plots/plot_repository.dart';
import '../../features/ratings/rating_repository.dart';
import '../../features/sessions/session_repository.dart';
import '../models/trial_insight.dart';

/// Minimum data thresholds — refuse to compute below these.
const kMinSessionsForHealth = 3;
const kMinRepsForHealth = 3;
const kMinSessionsForTrend = 2;
const kMinSessionsForCheckTrend = 2;
const kMinRepsForRepVariability = 3;
const kMinTestAndRefTreatments = 1;
const kMinDoseResponseTreatments = 3;
const kMinSessionsForPlotAnomaly = 2;
const kMinSessionsForWeatherCorrelation = 3;
const kMinSessionsForCompletenessPattern = 4;
const kMinPlotsForRaterPace = 10;

/// Computes trial insights on demand from session/rating data.
///
/// Called after session close or when overview tab opens.
/// Returns only insights that meet minimum data requirements.
class TrialIntelligenceService {
  TrialIntelligenceService({
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
    required PlotRepository plotRepository,
    required AssignmentRepository assignmentRepository,
    required TreatmentRepository treatmentRepository,
    required WeatherSnapshotRepository weatherSnapshotRepository,
  })  : _sessionRepo = sessionRepository,
        _ratingRepo = ratingRepository,
        _plotRepo = plotRepository,
        _assignmentRepo = assignmentRepository,
        _treatmentRepo = treatmentRepository,
        _weatherRepo = weatherSnapshotRepository;

  final SessionRepository _sessionRepo;
  final RatingRepository _ratingRepo;
  final PlotRepository _plotRepo;
  final AssignmentRepository _assignmentRepo;
  final TreatmentRepository _treatmentRepo;
  final WeatherSnapshotRepository _weatherRepo;

  /// Compute all insights for a trial. Returns only those meeting
  /// minimum data requirements.
  Future<List<TrialInsight>> computeInsights({
    required int trialId,
    required List<Treatment> treatments,
  }) async {
    final sessions = await _sessionRepo.getSessionsForTrial(trialId);
    final closedSessions =
        sessions.where((s) => s.endedAt != null).toList()
          ..sort((a, b) {
            final cmp = b.startedAt.compareTo(a.startedAt);
            return cmp != 0 ? cmp : b.id.compareTo(a.id);
          });
    if (closedSessions.isEmpty) return [];

    final plots = await _plotRepo.getPlotsForTrial(trialId);
    final dataPlots = plots.where(isAnalyzablePlot).toList();
    final assignments = await _assignmentRepo.getForTrial(trialId);

    final plotToTreatment = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null) plotToTreatment[a.plotId] = a.treatmentId!;
    }
    for (final p in dataPlots) {
      if (!plotToTreatment.containsKey(p.id) && p.treatmentId != null) {
        plotToTreatment[p.id] = p.treatmentId!;
      }
    }

    // Check treatment IDs
    final checkIds = <int>{};
    for (final t in treatments) {
      final code = t.code.trim().toUpperCase();
      final type = t.treatmentType?.trim().toUpperCase();
      if (code == 'CHK' || code == 'UTC' || code == 'CONTROL' ||
          type == 'CHK' || type == 'UTC' || type == 'CONTROL') {
        checkIds.add(t.id);
      }
    }

    // Collect ratings per session
    final sessionRatings = <int, List<RatingRecord>>{};
    for (final s in closedSessions) {
      sessionRatings[s.id] =
          await _ratingRepo.getCurrentRatingsForSession(s.id);
    }

    // Distinct assessment IDs across all ratings
    final assessmentIds = <int>{};
    for (final ratings in sessionRatings.values) {
      for (final r in ratings) {
        if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
          assessmentIds.add(r.assessmentId);
        }
      }
    }

    final repCount = dataPlots
        .map((p) => p.rep)
        .whereType<int>()
        .toSet()
        .length;

    final insights = <TrialInsight>[];

    // Per-assessment insights
    for (final aid in assessmentIds) {
      final healthInsight = _computeTrialHealth(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        checkIds: checkIds,
        treatments: treatments,
        assessmentId: aid,
        repCount: repCount,
      );
      if (healthInsight != null) insights.add(healthInsight);

      final trendInsights = _computeTreatmentTrends(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        treatments: treatments,
        assessmentId: aid,
        repCount: repCount,
      );
      insights.addAll(trendInsights);

      final checkInsight = _computeCheckTrend(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        checkIds: checkIds,
        assessmentId: aid,
        repCount: repCount,
      );
      if (checkInsight != null) insights.add(checkInsight);
    }

    final repInsight = _computeRepVariability(
      sessions: closedSessions,
      sessionRatings: sessionRatings,
      dataPlots: dataPlots,
      repCount: repCount,
    );
    if (repInsight != null) insights.add(repInsight);

    // 5.12: Test vs reference
    final componentsByTreatment = <int, List<TreatmentComponent>>{};
    for (final t in treatments) {
      componentsByTreatment[t.id] =
          await _treatmentRepo.getComponentsForTreatment(t.id);
    }

    for (final aid in assessmentIds) {
      final testRefInsight = _computeTestVsReference(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        treatments: treatments,
        componentsByTreatment: componentsByTreatment,
        assessmentId: aid,
        repCount: repCount,
      );
      if (testRefInsight != null) insights.add(testRefInsight);

      // 5.13: Dose-response
      final doseInsights = _computeDoseResponse(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        treatments: treatments,
        componentsByTreatment: componentsByTreatment,
        assessmentId: aid,
        repCount: repCount,
      );
      insights.addAll(doseInsights);
    }

    // 5.14: Plot anomaly
    for (final aid in assessmentIds) {
      final anomalies = _computePlotAnomalies(
        sessions: closedSessions,
        sessionRatings: sessionRatings,
        dataPlots: dataPlots,
        plotToTreatment: plotToTreatment,
        assessmentId: aid,
        repCount: repCount,
      );
      insights.addAll(anomalies);
    }

    // 5.15: Weather-rating correlation
    final weatherInsights = await _computeWeatherCorrelation(
      trialId: trialId,
      sessions: closedSessions,
      sessionRatings: sessionRatings,
      dataPlots: dataPlots,
      plotToTreatment: plotToTreatment,
      assessmentIds: assessmentIds,
      repCount: repCount,
    );
    insights.addAll(weatherInsights);

    // 5.16: Completeness pattern
    final completenessInsights = _computeCompletenessPattern(
      sessions: closedSessions,
    );
    insights.addAll(completenessInsights);

    // 5.17: Rater pace
    for (final s in closedSessions) {
      final paceInsight = _computeRaterPace(
        session: s,
        ratings: sessionRatings[s.id] ?? [],
        dataPlots: dataPlots,
      );
      if (paceInsight != null) insights.add(paceInsight);
    }

    return insights;
  }

  /// 5.2: Trial health signal — effect size, CV range, separation trend.
  TrialInsight? _computeTrialHealth({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required Set<int> checkIds,
    required List<Treatment> treatments,
    required int assessmentId,
    required int repCount,
  }) {
    if (sessions.length < kMinSessionsForHealth ||
        repCount < kMinRepsForHealth) {
      return null;
    }
    if (checkIds.isEmpty) return null;

    // Compute treatment means for latest session
    final latestSession = sessions.first; // already sorted desc by startedAt
    final latestRatings = sessionRatings[latestSession.id] ?? [];
    final treatmentMeans =
        _treatmentMeans(latestRatings, dataPlots, plotToTreatment, assessmentId);
    if (treatmentMeans.isEmpty) return null;

    // Check mean
    double? checkMean;
    for (final cid in checkIds) {
      if (treatmentMeans.containsKey(cid)) {
        checkMean = treatmentMeans[cid];
        break;
      }
    }
    if (checkMean == null || checkMean.abs() < 1e-9) return null;

    // Best treatment mean (excluding checks)
    double? bestMean;
    for (final e in treatmentMeans.entries) {
      if (checkIds.contains(e.key)) continue;
      if (bestMean == null || e.value > bestMean) bestMean = e.value;
    }
    if (bestMean == null) return null;

    final effectSize =
        ((bestMean - checkMean) / checkMean.abs()) * 100;

    // CV per treatment
    final cvValues = <double>[];
    for (final tid in treatmentMeans.keys) {
      final cv = _treatmentCv(
          latestRatings, dataPlots, plotToTreatment, assessmentId, tid);
      if (cv != null) cvValues.add(cv);
    }
    final cvRange = cvValues.isNotEmpty
        ? '${cvValues.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}-${cvValues.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}%'
        : null;

    // Separation trend (compare last 2 sessions' effect sizes)
    String? separationTrend;
    if (sessions.length >= 2) {
      final prevSession = sessions[1];
      final prevRatings = sessionRatings[prevSession.id] ?? [];
      final prevMeans =
          _treatmentMeans(prevRatings, dataPlots, plotToTreatment, assessmentId);
      final prevCheck =
          checkIds.map((id) => prevMeans[id]).whereType<double>().firstOrNull;
      if (prevCheck != null && prevCheck.abs() > 1e-9) {
        double? prevBest;
        for (final e in prevMeans.entries) {
          if (checkIds.contains(e.key)) continue;
          if (prevBest == null || e.value > prevBest) prevBest = e.value;
        }
        if (prevBest != null) {
          final prevEffect =
              ((prevBest - prevCheck) / prevCheck.abs()) * 100;
          final delta = effectSize - prevEffect;
          if (delta > 5) {
            separationTrend = 'increasing';
          } else if (delta < -5) {
            separationTrend = 'collapsing';
          } else {
            separationTrend = 'stable';
          }
        }
      }
    }

    final detailParts = <String>[
      'Effect size: ${effectSize.toStringAsFixed(0)}%',
    ];
    if (cvRange != null) detailParts.add('CV: $cvRange');
    if (separationTrend != null) {
      detailParts.add('Separation: $separationTrend');
    }

    final confidence = resolveConfidence(
      sessionCount: sessions.length,
      repCount: repCount,
      consistentTrend: separationTrend == 'stable' || separationTrend == 'increasing',
    );

    return TrialInsight(
      type: InsightType.trialHealth,
      title: 'Trial health',
      detail: '${detailParts.join('. ')}.',
      basis: InsightBasis(
        repCount: repCount,
        sessionCount: sessions.length,
        method: '(best treatment mean − check mean) / check mean × 100',
        minimumDataMet: true,
        confidence: confidence,
        threshold: 'Minimum: $kMinSessionsForHealth sessions, $kMinRepsForHealth reps',
      ),
    );
  }

  /// 5.3: Treatment trend across sessions — per-treatment mean per session.
  List<TrialInsight> _computeTreatmentTrends({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required List<Treatment> treatments,
    required int assessmentId,
    required int repCount,
  }) {
    if (sessions.length < kMinSessionsForTrend) return [];

    final insights = <TrialInsight>[];
    final treatmentIds =
        plotToTreatment.values.toSet();

    for (final tid in treatmentIds) {
      final treatment = treatments.where((t) => t.id == tid).firstOrNull;
      if (treatment == null) continue;
      final tCode = treatment.code.isNotEmpty ? treatment.code : treatment.name;

      final sessionMeans = <String>[];
      double? firstMean;
      double? lastMean;

      // Chronological order (oldest first)
      final chronological = sessions.reversed.toList();
      for (final s in chronological) {
        final ratings = sessionRatings[s.id] ?? [];
        final means =
            _treatmentMeans(ratings, dataPlots, plotToTreatment, assessmentId);
        final m = means[tid];
        if (m != null) {
          sessionMeans.add('${m.toStringAsFixed(0)}%');
          firstMean ??= m;
          lastMean = m;
        }
      }

      if (sessionMeans.length < kMinSessionsForTrend) continue;

      final delta = lastMean! - firstMean!;
      final sign = delta >= 0 ? '+' : '';
      final detail =
          '$tCode: ${sessionMeans.join(' → ')} ($sign${delta.toStringAsFixed(0)} points).';

      final confidence = resolveConfidence(
        sessionCount: sessionMeans.length,
        repCount: repCount,
      );

      insights.add(TrialInsight(
        type: InsightType.treatmentTrend,
        title: 'Treatment trend — $tCode',
        detail: detail,
        basis: InsightBasis(
          repCount: repCount,
          sessionCount: sessionMeans.length,
          method: 'Arithmetic mean per treatment per session',
          minimumDataMet: true,
          confidence: confidence,
          threshold: 'Minimum: $kMinSessionsForTrend sessions',
        ),
      ));
    }

    return insights;
  }

  /// 5.4: Check plot trend — check treatment mean per session.
  TrialInsight? _computeCheckTrend({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required Set<int> checkIds,
    required int assessmentId,
    required int repCount,
  }) {
    if (sessions.length < kMinSessionsForCheckTrend) return null;
    if (checkIds.isEmpty) return null;

    final sessionMeans = <String>[];
    final chronological = sessions.reversed.toList();

    for (final s in chronological) {
      final ratings = sessionRatings[s.id] ?? [];
      final means =
          _treatmentMeans(ratings, dataPlots, plotToTreatment, assessmentId);
      for (final cid in checkIds) {
        final m = means[cid];
        if (m != null) {
          sessionMeans.add('${m.toStringAsFixed(0)}%');
          break;
        }
      }
    }

    if (sessionMeans.length < kMinSessionsForCheckTrend) return null;

    // Direction
    final firstVal = double.tryParse(sessionMeans.first.replaceAll('%', ''));
    final lastVal = double.tryParse(sessionMeans.last.replaceAll('%', ''));
    String direction = 'stable';
    if (firstVal != null && lastVal != null) {
      final delta = lastVal - firstVal;
      if (delta > 5) {
        direction = 'rising';
      } else if (delta < -5) {
        direction = 'falling';
      }
    }

    final detail =
        'Untreated check: ${sessionMeans.join(' → ')}. Direction: $direction.';

    final confidence = resolveConfidence(
      sessionCount: sessionMeans.length,
      repCount: repCount,
    );

    return TrialInsight(
      type: InsightType.checkTrend,
      title: 'Check plot trend',
      detail: detail,
      basis: InsightBasis(
        repCount: repCount,
        sessionCount: sessionMeans.length,
        method: 'Check treatment arithmetic mean per session',
        minimumDataMet: true,
        confidence: confidence,
        threshold: 'Minimum: $kMinSessionsForCheckTrend sessions',
      ),
    );
  }

  /// 5.5: Per-rep variability — overall mean per rep, flags outlier reps.
  TrialInsight? _computeRepVariability({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required int repCount,
  }) {
    if (repCount < kMinRepsForRepVariability) return null;

    // Group all numeric ratings by rep
    final plotToRep = <int, int>{};
    for (final p in dataPlots) {
      if (p.rep != null) plotToRep[p.id] = p.rep!;
    }

    final repValues = <int, List<double>>{};
    for (final ratings in sessionRatings.values) {
      for (final r in ratings) {
        if (r.resultStatus != 'RECORDED' || r.numericValue == null) continue;
        final rep = plotToRep[r.plotPk];
        if (rep == null) continue;
        repValues.putIfAbsent(rep, () => []).add(r.numericValue!);
      }
    }

    if (repValues.length < kMinRepsForRepVariability) return null;

    // Mean per rep
    final repMeans = <int, double>{};
    for (final e in repValues.entries) {
      repMeans[e.key] =
          e.value.reduce((a, b) => a + b) / e.value.length;
    }

    // Grand mean and SD across rep means
    final allMeans = repMeans.values.toList();
    final grandMean =
        allMeans.reduce((a, b) => a + b) / allMeans.length;
    final variance = allMeans
            .map((m) => (m - grandMean) * (m - grandMean))
            .reduce((a, b) => a + b) /
        (allMeans.length - 1);
    final sd = sqrt(variance);

    // Flag outlier reps (>2 SD from grand mean)
    final outlierReps = <int>[];
    for (final e in repMeans.entries) {
      if (sd > 1e-9 && (e.value - grandMean).abs() > 2 * sd) {
        outlierReps.add(e.key);
      }
    }

    // Build detail
    final repParts = <String>[];
    final sortedReps = repMeans.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in sortedReps) {
      repParts.add('Rep ${e.key}: ${e.value.toStringAsFixed(0)}%');
    }

    final detail = StringBuffer(repParts.join('. '));
    detail.write('.');
    if (outlierReps.isNotEmpty) {
      detail.write(
          ' Outlier rep${outlierReps.length == 1 ? '' : 's'}: ${outlierReps.join(', ')} (>2 SD from grand mean).');
    }

    final confidence = resolveConfidence(
      sessionCount: sessions.length,
      repCount: repCount,
    );

    return TrialInsight(
      type: InsightType.repVariability,
      title: 'Rep variability',
      detail: detail.toString(),
      basis: InsightBasis(
        repCount: repCount,
        sessionCount: sessions.length,
        method: 'Overall mean per rep across all treatments and sessions',
        minimumDataMet: true,
        confidence: confidence,
        threshold: 'Minimum: $kMinRepsForRepVariability reps. Outlier: >2 SD from grand mean',
      ),
    );
  }

  // --- 5.12: Test vs reference ---

  TrialInsight? _computeTestVsReference({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required List<Treatment> treatments,
    required Map<int, List<TreatmentComponent>> componentsByTreatment,
    required int assessmentId,
    required int repCount,
  }) {
    final testIds = <int>{};
    final refIds = <int>{};
    for (final t in treatments) {
      final comps = componentsByTreatment[t.id] ?? [];
      final hasTest = comps.any((c) => c.isTestProduct);
      if (hasTest) {
        testIds.add(t.id);
      } else if (comps.isNotEmpty) {
        refIds.add(t.id);
      }
    }
    if (testIds.length < kMinTestAndRefTreatments ||
        refIds.length < kMinTestAndRefTreatments) {
      return null;
    }

    final chronological = sessions.reversed.toList();
    final gapHistory = <String>[];
    double? firstGap;
    double? lastGap;

    for (final s in chronological) {
      final means =
          _treatmentMeans(sessionRatings[s.id] ?? [], dataPlots, plotToTreatment, assessmentId);
      final testVals = testIds.map((id) => means[id]).whereType<double>();
      final refVals = refIds.map((id) => means[id]).whereType<double>();
      if (testVals.isEmpty || refVals.isEmpty) continue;
      final testMean = testVals.reduce((a, b) => a + b) / testVals.length;
      final refMean = refVals.reduce((a, b) => a + b) / refVals.length;
      final gap = testMean - refMean;
      gapHistory.add('${testMean.toStringAsFixed(0)}% vs ${refMean.toStringAsFixed(0)}% (${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(0)} pts)');
      firstGap ??= gap;
      lastGap = gap;
    }
    if (gapHistory.isEmpty) return null;

    String gapDirection = 'stable';
    if (firstGap != null && lastGap != null && gapHistory.length >= 2) {
      final delta = lastGap - firstGap;
      if (delta > 5) gapDirection = 'widening';
      if (delta < -5) gapDirection = 'narrowing';
    }

    final gapAbs = lastGap?.abs() ?? 0;
    final severity = gapAbs > 20 && gapDirection == 'widening' && sessions.length >= 3
        ? InsightSeverity.attention
        : gapAbs > 20 && gapDirection == 'widening'
            ? InsightSeverity.notable
            : InsightSeverity.info;

    final title = gapAbs <= 3
        ? 'Test product within ${gapAbs.toStringAsFixed(0)} pts of reference'
        : 'Test product ${lastGap! >= 0 ? 'ahead' : 'trailing'} by ${gapAbs.toStringAsFixed(0)} pts';

    final detail = 'Test vs reference: ${gapHistory.join(', ')}. '
        'Gap: $gapDirection. '
        '$repCount reps, ${gapHistory.length} sessions.';

    return TrialInsight(
      type: InsightType.testVsReference,
      title: title,
      detail: detail,
      severity: severity,
      basis: InsightBasis(
        repCount: repCount,
        sessionCount: gapHistory.length,
        method: 'Mean comparison: test product treatments vs reference treatments',
        minimumDataMet: true,
        confidence: resolveConfidence(
            sessionCount: gapHistory.length, repCount: repCount),
      ),
    );
  }

  // --- 5.13: Dose-response ---

  List<TrialInsight> _computeDoseResponse({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required List<Treatment> treatments,
    required Map<int, List<TreatmentComponent>> componentsByTreatment,
    required int assessmentId,
    required int repCount,
  }) {
    // Group treatments by active ingredient name
    final aiGroups = <String, List<({int treatmentId, double rate, String tCode})>>{};
    for (final t in treatments) {
      final comps = componentsByTreatment[t.id] ?? [];
      for (final c in comps) {
        final ai = c.activeIngredientName?.trim();
        if (ai == null || ai.isEmpty) continue;
        if (c.labelRate == null && (componentsByTreatment[t.id]?.length ?? 0) <= 1) {
          // Use the treatment's own rate if component doesn't have labelRate
          continue;
        }
        final rate = c.labelRate ?? c.aiConcentration;
        if (rate == null || rate <= 0) continue;
        aiGroups.putIfAbsent(ai, () => []).add((
          treatmentId: t.id,
          rate: rate,
          tCode: t.code.isNotEmpty ? t.code : t.name,
        ));
      }
    }

    final insights = <TrialInsight>[];
    final latestSession = sessions.first;
    final latestRatings = sessionRatings[latestSession.id] ?? [];

    for (final entry in aiGroups.entries) {
      final ai = entry.key;
      final group = entry.value;
      if (group.length < kMinDoseResponseTreatments) continue;

      // Sort by rate ascending
      group.sort((a, b) => a.rate.compareTo(b.rate));
      final means = _treatmentMeans(latestRatings, dataPlots, plotToTreatment, assessmentId);

      final rateMeans = <({String code, double rate, double mean})>[];
      for (final g in group) {
        final m = means[g.treatmentId];
        if (m == null) continue;
        rateMeans.add((code: g.tCode, rate: g.rate, mean: m));
      }
      if (rateMeans.length < kMinDoseResponseTreatments) continue;

      // Check monotonic increase
      bool isMonotonic = true;
      for (var i = 1; i < rateMeans.length; i++) {
        if (rateMeans[i].mean < rateMeans[i - 1].mean) {
          isMonotonic = false;
          break;
        }
      }

      final rateStrs = rateMeans
          .map((rm) => '${rm.rate.toStringAsFixed(0)} → ${rm.mean.toStringAsFixed(0)}%')
          .join(', ');
      final range = rateMeans.last.mean - rateMeans.first.mean;

      final String title;
      final InsightSeverity severity;
      final String detail;
      if (isMonotonic) {
        title = 'Dose-response pattern for $ai';
        severity = InsightSeverity.info;
        detail = '$ai: $rateStrs. Efficacy follows rate ranking. '
            'Range: ${range.toStringAsFixed(0)} pts. '
            '$repCount reps, ${sessions.length} sessions.';
      } else {
        title = 'No dose-response for $ai';
        severity = InsightSeverity.notable;
        detail = '$ai: $rateStrs. No consistent rate-efficacy relationship. '
            'Range: ${range.abs().toStringAsFixed(0)} pts. '
            '$repCount reps, ${sessions.length} sessions.';
      }

      insights.add(TrialInsight(
        type: InsightType.doseResponse,
        title: title,
        detail: detail,
        severity: severity,
        basis: InsightBasis(
          repCount: repCount,
          sessionCount: sessions.length,
          method: 'Monotonic rate-efficacy check within shared active ingredient',
          minimumDataMet: true,
          confidence: resolveConfidence(
              sessionCount: sessions.length, repCount: repCount),
          threshold: 'Minimum: $kMinDoseResponseTreatments treatments sharing same AI',
        ),
      ));
    }

    return insights;
  }

  // --- 5.14: Plot anomaly ---

  List<TrialInsight> _computePlotAnomalies({
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required int assessmentId,
    required int repCount,
  }) {
    if (sessions.length < kMinSessionsForPlotAnomaly) return [];

    final currentSession = sessions[0];
    final previousSession = sessions[1];
    final currentRatings = sessionRatings[currentSession.id] ?? [];
    final previousRatings = sessionRatings[previousSession.id] ?? [];

    // Build per-plot value maps
    final currentValues = <int, double>{};
    final previousValues = <int, double>{};
    for (final r in currentRatings) {
      if (r.assessmentId != assessmentId) continue;
      if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
        currentValues[r.plotPk] = r.numericValue!;
      }
    }
    for (final r in previousRatings) {
      if (r.assessmentId != assessmentId) continue;
      if (r.resultStatus == 'RECORDED' && r.numericValue != null) {
        previousValues[r.plotPk] = r.numericValue!;
      }
    }

    // Compute per-treatment average change
    final treatmentChanges = <int, List<double>>{};
    for (final p in dataPlots) {
      final cur = currentValues[p.id];
      final prev = previousValues[p.id];
      if (cur == null || prev == null) continue;
      final tid = plotToTreatment[p.id];
      if (tid == null) continue;
      treatmentChanges.putIfAbsent(tid, () => []).add(cur - prev);
    }
    final treatmentAvgChange = <int, double>{};
    for (final e in treatmentChanges.entries) {
      if (e.value.isEmpty) continue;
      treatmentAvgChange[e.key] =
          e.value.reduce((a, b) => a + b) / e.value.length;
    }

    final insights = <TrialInsight>[];
    for (final p in dataPlots) {
      final cur = currentValues[p.id];
      final prev = previousValues[p.id];
      if (cur == null || prev == null) continue;
      final tid = plotToTreatment[p.id];
      if (tid == null) continue;
      final avgChange = treatmentAvgChange[tid];
      if (avgChange == null) continue;

      final plotChange = cur - prev;
      final deviation = (plotChange - avgChange).abs();
      final ratio = avgChange.abs() > 1e-9 ? plotChange.abs() / avgChange.abs() : 0.0;

      if (ratio > 2 && deviation > 25) {
        final trtPlotCount = treatmentChanges[tid]?.length ?? 0;
        final severity = ratio > 3
            ? InsightSeverity.attention
            : InsightSeverity.notable;

        insights.add(TrialInsight(
          type: InsightType.plotAnomaly,
          title: 'Plot ${p.plotId} unusual change',
          detail: 'Plot ${p.plotId}: changed ${plotChange >= 0 ? '+' : ''}${plotChange.toStringAsFixed(0)} pts '
              '(${prev.toStringAsFixed(0)}% → ${cur.toStringAsFixed(0)}%). '
              'Treatment avg change: ${avgChange >= 0 ? '+' : ''}${avgChange.toStringAsFixed(0)} pts. '
              'Deviation: ${deviation.toStringAsFixed(0)} pts above treatment average. '
              '$trtPlotCount reps in treatment.',
          severity: severity,
          relatedPlotIds: [p.id],
          relatedSessionIds: [currentSession.id, previousSession.id],
          basis: InsightBasis(
            repCount: repCount,
            sessionCount: sessions.length,
            method: 'Per-plot change vs treatment group average change',
            minimumDataMet: true,
            confidence: InsightConfidence.preliminary,
            threshold: '2× group avg change AND >25 pts absolute',
          ),
        ));
      }
    }
    return insights;
  }

  // --- 5.15: Weather-rating correlation ---

  Future<List<TrialInsight>> _computeWeatherCorrelation({
    required int trialId,
    required List<Session> sessions,
    required Map<int, List<RatingRecord>> sessionRatings,
    required List<Plot> dataPlots,
    required Map<int, int> plotToTreatment,
    required Set<int> assessmentIds,
    required int repCount,
  }) async {
    if (sessions.length < kMinSessionsForWeatherCorrelation) return [];

    // Load weather for each session
    final sessionWeather = <int, WeatherSnapshot>{};
    for (final s in sessions) {
      final w = await _weatherRepo.getWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession, s.id);
      if (w != null) sessionWeather[s.id] = w;
    }
    if (sessionWeather.length < kMinSessionsForWeatherCorrelation) return [];

    // Compute overall mean treatment change per session pair
    final chronological = sessions.reversed.toList();
    final insights = <TrialInsight>[];

    // Average weather conditions across all sessions
    final allTemps = sessionWeather.values
        .map((w) => w.temperature)
        .whereType<double>()
        .toList();
    final avgTemp = allTemps.isNotEmpty
        ? allTemps.reduce((a, b) => a + b) / allTemps.length
        : null;

    for (var i = 1; i < chronological.length; i++) {
      final s = chronological[i];
      final w = sessionWeather[s.id];
      if (w == null) continue;

      // Check if weather was notably different
      final temp = w.temperature;
      final wind = w.windSpeed;
      final isNotable = (temp != null && avgTemp != null && (temp - avgTemp).abs() > 10) ||
          (temp != null && (temp > 32 || temp < 4)) ||
          (wind != null && wind > 6.7);

      if (!isNotable) continue;

      // Check if treatment means shifted significantly
      final prevSession = chronological[i - 1];
      final firstAid = assessmentIds.isNotEmpty ? assessmentIds.first : null;
      if (firstAid == null) continue;

      final curMeans = _treatmentMeans(
          sessionRatings[s.id] ?? [], dataPlots, plotToTreatment, firstAid);
      final prevMeans = _treatmentMeans(
          sessionRatings[prevSession.id] ?? [], dataPlots, plotToTreatment, firstAid);

      if (curMeans.isEmpty || prevMeans.isEmpty) continue;

      final shifts = <double>[];
      for (final tid in curMeans.keys) {
        final prev = prevMeans[tid];
        if (prev != null) shifts.add(curMeans[tid]! - prev);
      }
      if (shifts.isEmpty) continue;
      final avgShift = shifts.reduce((a, b) => a + b) / shifts.length;

      if (avgShift.abs() < 10) continue;

      final weatherParts = <String>[];
      if (temp != null) weatherParts.add('${temp.round()}°C');
      if (wind != null) weatherParts.add('wind ${wind.toStringAsFixed(1)} m/s');
      if (w.precipitation != null && w.precipitation!.trim().isNotEmpty) {
        weatherParts.add('precip: ${w.precipitation}');
      }

      final avgTempStr = avgTemp != null ? '${avgTemp.round()}°C' : 'n/a';
      final shiftDir = avgShift >= 0 ? '+' : '';

      insights.add(TrialInsight(
        type: InsightType.weatherContext,
        title: 'Weather shift at ${s.name}',
        detail: '${s.name}: ${weatherParts.join(', ')}. '
            'Treatment means shifted $shiftDir${avgShift.toStringAsFixed(0)} pts from previous session. '
            'Trial avg temp: $avgTempStr. '
            '$repCount reps, ${sessions.length} sessions.',
        severity: InsightSeverity.info,
        relatedSessionIds: [s.id, prevSession.id],
        basis: InsightBasis(
          repCount: repCount,
          sessionCount: sessions.length,
          method: 'Weather condition and rating change co-occurrence',
          minimumDataMet: true,
          confidence: resolveConfidence(
              sessionCount: sessions.length, repCount: repCount),
          threshold: 'Notable weather: >10°C from trial avg, >32°C, <4°C, or wind >15 mph. Shift: >10 pts',
        ),
      ));
    }

    return insights;
  }

  // --- 5.16: Completeness pattern ---

  List<TrialInsight> _computeCompletenessPattern({
    required List<Session> sessions,
  }) {
    if (sessions.length < kMinSessionsForCompletenessPattern) return [];

    final chronological = sessions.reversed.toList();
    final halfIdx = chronological.length ~/ 2;
    final firstHalf = chronological.sublist(0, halfIdx);
    final secondHalf = chronological.sublist(halfIdx);

    final insights = <TrialInsight>[];

    // Check weather capture rate
    _checkFieldCapture(
      fieldName: 'Weather',
      firstHalf: firstHalf,
      secondHalf: secondHalf,
      allSessions: chronological,
      hasField: (s) => s.cropStageBbch != null || true, // Weather checked via snapshot
      insights: insights,
    );

    // Check BBCH capture rate
    final bbchFirst = firstHalf.where((s) => s.cropStageBbch != null).length;
    final bbchSecond = secondHalf.where((s) => s.cropStageBbch != null).length;
    final bbchFirstRate = firstHalf.isEmpty ? 1.0 : bbchFirst / firstHalf.length;
    final bbchSecondRate = secondHalf.isEmpty ? 1.0 : bbchSecond / secondHalf.length;

    if (bbchFirstRate > 0.75 && bbchSecondRate < 0.5) {
      final overall = (bbchFirst + bbchSecond) / chronological.length;
      insights.add(TrialInsight(
        type: InsightType.completenessPattern,
        title: 'BBCH capture declining',
        detail: 'BBCH recorded: Sessions 1–$halfIdx (${(bbchFirstRate * 100).toStringAsFixed(0)}%). '
            'Sessions ${halfIdx + 1}–${chronological.length} (${(bbchSecondRate * 100).toStringAsFixed(0)}%). '
            'Overall rate: ${(overall * 100).toStringAsFixed(0)}%. '
            '${chronological.length} sessions total.',
        severity: bbchSecondRate < 0.25
            ? InsightSeverity.attention
            : InsightSeverity.notable,
        basis: InsightBasis(
          repCount: 0,
          sessionCount: chronological.length,
          method: 'Per-field capture rate: first half vs second half of sessions',
          minimumDataMet: true,
          confidence: InsightConfidence.moderate,
          threshold: 'Flag when rate drops below 50% in second half',
        ),
      ));
    }

    // Check crop injury capture rate
    final ciFirst = firstHalf.where((s) => s.cropInjuryStatus != null).length;
    final ciSecond = secondHalf.where((s) => s.cropInjuryStatus != null).length;
    final ciFirstRate = firstHalf.isEmpty ? 1.0 : ciFirst / firstHalf.length;
    final ciSecondRate = secondHalf.isEmpty ? 1.0 : ciSecond / secondHalf.length;

    if (ciFirstRate > 0.75 && ciSecondRate < 0.5) {
      final overall = (ciFirst + ciSecond) / chronological.length;
      insights.add(TrialInsight(
        type: InsightType.completenessPattern,
        title: 'Crop injury capture declining',
        detail: 'Crop injury recorded: Sessions 1–$halfIdx (${(ciFirstRate * 100).toStringAsFixed(0)}%). '
            'Sessions ${halfIdx + 1}–${chronological.length} (${(ciSecondRate * 100).toStringAsFixed(0)}%). '
            'Overall rate: ${(overall * 100).toStringAsFixed(0)}%. '
            '${chronological.length} sessions total.',
        severity: ciSecondRate < 0.25
            ? InsightSeverity.attention
            : InsightSeverity.notable,
        basis: InsightBasis(
          repCount: 0,
          sessionCount: chronological.length,
          method: 'Per-field capture rate: first half vs second half of sessions',
          minimumDataMet: true,
          confidence: InsightConfidence.moderate,
          threshold: 'Flag when rate drops below 50% in second half',
        ),
      ));
    }

    return insights;
  }

  void _checkFieldCapture({
    required String fieldName,
    required List<Session> firstHalf,
    required List<Session> secondHalf,
    required List<Session> allSessions,
    required bool Function(Session) hasField,
    required List<TrialInsight> insights,
  }) {
    // Placeholder — weather capture requires async snapshot lookup.
    // Implemented inline for BBCH and crop injury above.
  }

  // --- 5.17: Rater pace ---

  TrialInsight? _computeRaterPace({
    required Session session,
    required List<RatingRecord> ratings,
    required List<Plot> dataPlots,
  }) {
    // Use createdAt (DateTime) for interval computation.
    final timedRatings = ratings
        .where((r) => r.resultStatus == 'RECORDED' && r.isCurrent)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (timedRatings.length < kMinPlotsForRaterPace) return null;

    // Compute per-plot intervals (seconds between consecutive ratings)
    final intervals = <({int plotPk, double seconds})>[];
    for (var i = 1; i < timedRatings.length; i++) {
      final gap = timedRatings[i].createdAt
          .difference(timedRatings[i - 1].createdAt)
          .inMilliseconds / 1000.0;
      if (gap > 0 && gap < 600) {
        intervals.add((plotPk: timedRatings[i].plotPk, seconds: gap));
      }
    }
    if (intervals.length < kMinPlotsForRaterPace) return null;

    final totalSeconds =
        intervals.map((e) => e.seconds).reduce((a, b) => a + b);
    final totalMinutes = totalSeconds / 60;

    // Skip pace analysis for sessions under 5 minutes — not enough
    // walking time for meaningful pace variation.
    if (totalMinutes < 5) return null;

    final avgSeconds = totalSeconds / intervals.length;

    // Flag as slow only if BOTH: >2× session average AND >60s absolute.
    final slowPlots = <int>{};
    for (final iv in intervals) {
      if (iv.seconds > avgSeconds * 2 && iv.seconds > 60) {
        slowPlots.add(iv.plotPk);
      }
    }
    if (slowPlots.isEmpty) return null;

    // Get plot labels
    final plotMap = {for (final p in dataPlots) p.id: p.plotId};
    final slowLabels = slowPlots
        .map((pk) => plotMap[pk] ?? '$pk')
        .take(5)
        .toList();

    final slowAvg = intervals
        .where((iv) => slowPlots.contains(iv.plotPk))
        .map((iv) => iv.seconds)
        .toList();
    final slowAvgSec = slowAvg.isNotEmpty
        ? slowAvg.reduce((a, b) => a + b) / slowAvg.length
        : 0.0;

    return TrialInsight(
      type: InsightType.raterPace,
      title: '${session.name}: pace anomaly on ${slowPlots.length} plots',
      detail: 'Session pace: ${timedRatings.length} ratings in ${totalMinutes.toStringAsFixed(0)} min '
          '(avg ${(avgSeconds / 60).toStringAsFixed(1)} min/plot). '
          'Plots ${slowLabels.join(', ')}: avg ${(slowAvgSec / 60).toStringAsFixed(1)} min/plot '
          '(${(slowAvgSec / avgSeconds).toStringAsFixed(1)}× session average). '
          '${timedRatings.length} plots total.',
      severity: InsightSeverity.info,
      relatedSessionIds: [session.id],
      relatedPlotIds: slowPlots.toList(),
      basis: const InsightBasis(
        repCount: 0,
        sessionCount: 1,
        method: 'Per-plot rating timestamp interval analysis',
        minimumDataMet: true,
        confidence: InsightConfidence.preliminary,
        threshold: 'Minimum session: 5 min. Slow: >2× session average AND >1 min absolute. Breaks: gaps >10 min excluded',
      ),
    );
  }

  // --- Helpers ---

  /// Treatment means for a single session/assessment.
  Map<int, double> _treatmentMeans(
    List<RatingRecord> ratings,
    List<Plot> dataPlots,
    Map<int, int> plotToTreatment,
    int assessmentId,
  ) {
    final plotPks = dataPlots.map((p) => p.id).toSet();
    final byTreatment = <int, List<double>>{};
    for (final r in ratings) {
      if (r.assessmentId != assessmentId) continue;
      if (r.resultStatus != 'RECORDED' || r.numericValue == null) continue;
      if (!plotPks.contains(r.plotPk)) continue;
      final tid = plotToTreatment[r.plotPk];
      if (tid == null) continue;
      byTreatment.putIfAbsent(tid, () => []).add(r.numericValue!);
    }
    return {
      for (final e in byTreatment.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };
  }

  /// CV% for one treatment in one session/assessment.
  double? _treatmentCv(
    List<RatingRecord> ratings,
    List<Plot> dataPlots,
    Map<int, int> plotToTreatment,
    int assessmentId,
    int treatmentId,
  ) {
    final plotPks = dataPlots.map((p) => p.id).toSet();
    final values = <double>[];
    for (final r in ratings) {
      if (r.assessmentId != assessmentId) continue;
      if (r.resultStatus != 'RECORDED' || r.numericValue == null) continue;
      if (!plotPks.contains(r.plotPk)) continue;
      if (plotToTreatment[r.plotPk] != treatmentId) continue;
      values.add(r.numericValue!);
    }
    if (values.length < 2) return null;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean.abs() < 1e-9) return null;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        (values.length - 1);
    return (sqrt(variance) / mean.abs()) * 100;
  }
}
