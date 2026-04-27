import 'dart:math';

import '../../../core/database/app_database.dart';
import '../../../core/plot_analysis_eligibility.dart';
import '../../../core/utils/check_treatment_helper.dart';
import '../../../domain/intelligence/trial_intelligence_service.dart'
    show kMinRepsForRepVariability;

/// Per-cell result in the treatment × assessment results table.
class TreatmentCellData {
  const TreatmentCellData({
    required this.mean,
    required this.n,
    this.cv,
    this.separation,
  });

  final double mean;
  final int n;

  /// Coefficient of variation (%), null when n < [kMinRepsForRepVariability].
  final double? cv;

  /// Mean − check mean. Null when this treatment IS the check, or no check exists.
  final double? separation;
}

/// Pure computation helpers for the Trial Data screen.
///
/// All methods are static and side-effect free — safe to unit test without Flutter.
class TrialDataComputer {
  const TrialDataComputer._();

  static const double _sdMultiplier = 2.0;

  /// Computes per-treatment, per-assessment means across all provided ratings.
  ///
  /// Only considers ratings that are:
  /// - [RatingRecord.isCurrent] == true
  /// - [RatingRecord.isDeleted] == false
  /// - [RatingRecord.resultStatus] == 'RECORDED'
  /// - [RatingRecord.numericValue] != null
  /// - Plot is analyzable ([isAnalyzablePlot])
  ///
  /// Returns Map<treatmentId, Map<assessmentId, [TreatmentCellData]>>.
  static Map<int, Map<int, TreatmentCellData>> computeTreatmentMeans({
    required List<Treatment> treatments,
    required List<Plot> plots,
    required List<Assignment> assignments,
    required List<Assessment> assessments,
    required List<RatingRecord> ratings,
  }) {
    final analyzablePlots = {
      for (final p in plots)
        if (isAnalyzablePlot(p)) p.id: p,
    };

    // Build plot → treatmentId (assignments first, then legacy plot.treatmentId)
    final plotTreatmentMap = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null && analyzablePlots.containsKey(a.plotId)) {
        plotTreatmentMap[a.plotId] = a.treatmentId!;
      }
    }
    for (final p in analyzablePlots.values) {
      if (!plotTreatmentMap.containsKey(p.id) && p.treatmentId != null) {
        plotTreatmentMap[p.id] = p.treatmentId!;
      }
    }

    // Group values by (treatmentId, assessmentId)
    final groups = <int, Map<int, List<double>>>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      if (r.resultStatus != 'RECORDED') continue;
      final v = r.numericValue;
      if (v == null) continue;
      final tid = plotTreatmentMap[r.plotPk];
      if (tid == null) continue;
      groups.putIfAbsent(tid, () => {}).putIfAbsent(r.assessmentId, () => []).add(v);
    }

    // Identify check mean per assessment
    final checkMeans = <int, double>{};
    for (final t in treatments) {
      if (!isCheckTreatment(t)) continue;
      final byAssessment = groups[t.id];
      if (byAssessment == null) continue;
      for (final entry in byAssessment.entries) {
        final vals = entry.value;
        if (vals.isEmpty) continue;
        checkMeans[entry.key] = vals.reduce((a, b) => a + b) / vals.length;
      }
    }

    // Build result map
    final result = <int, Map<int, TreatmentCellData>>{};
    for (final t in treatments) {
      final byAssessment = groups[t.id];
      if (byAssessment == null) continue;
      final isCheck = isCheckTreatment(t);
      final cellMap = <int, TreatmentCellData>{};
      for (final entry in byAssessment.entries) {
        final aId = entry.key;
        final vals = entry.value;
        if (vals.isEmpty) continue;
        final n = vals.length;
        final mean = vals.reduce((a, b) => a + b) / n;

        double? cv;
        if (n >= kMinRepsForRepVariability && mean.abs() > 1e-9) {
          final variance = vals
                  .map((v) => (v - mean) * (v - mean))
                  .reduce((a, b) => a + b) /
              (n - 1);
          final sd = sqrt(variance);
          cv = (sd / mean.abs()) * 100.0;
        }

        final checkMean = checkMeans[aId];
        final separation =
            (!isCheck && checkMean != null) ? mean - checkMean : null;

        cellMap[aId] = TreatmentCellData(
          mean: mean,
          n: n,
          cv: cv,
          separation: separation,
        );
      }
      if (cellMap.isNotEmpty) result[t.id] = cellMap;
    }

    return result;
  }

  /// Returns (plotPk, assessmentId) pairs where the rating is >2 SD from the
  /// treatment group mean for that assessment.
  ///
  /// Groups must have at least [kMinRepsForRepVariability] members.
  static Set<(int, int)> computeOutlierCandidates({
    required List<Plot> plots,
    required List<Assignment> assignments,
    required List<Assessment> assessments,
    required List<RatingRecord> ratings,
  }) {
    final analyzablePlots = {
      for (final p in plots)
        if (isAnalyzablePlot(p)) p.id: p,
    };

    final plotTreatmentMap = <int, int>{};
    for (final a in assignments) {
      if (a.treatmentId != null && analyzablePlots.containsKey(a.plotId)) {
        plotTreatmentMap[a.plotId] = a.treatmentId!;
      }
    }
    for (final p in analyzablePlots.values) {
      if (!plotTreatmentMap.containsKey(p.id) && p.treatmentId != null) {
        plotTreatmentMap[p.id] = p.treatmentId!;
      }
    }

    // rating map: (plotPk, assessmentId) → value
    final ratingMap = <(int, int), double>{};
    for (final r in ratings) {
      if (!r.isCurrent || r.isDeleted) continue;
      if (r.resultStatus != 'RECORDED') continue;
      final v = r.numericValue;
      if (v == null) continue;
      ratingMap[(r.plotPk, r.assessmentId)] = v;
    }

    final outliers = <(int, int)>{};
    for (final a in assessments) {
      final byTreatment = <int, List<(int, double)>>{};
      for (final plotId in analyzablePlots.keys) {
        final tid = plotTreatmentMap[plotId];
        if (tid == null) continue;
        final v = ratingMap[(plotId, a.id)];
        if (v == null) continue;
        byTreatment.putIfAbsent(tid, () => []).add((plotId, v));
      }

      for (final group in byTreatment.values) {
        if (group.length < kMinRepsForRepVariability) continue;
        final values = group.map((e) => e.$2).toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance = values
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            (values.length - 1);
        final sd = variance > 0 ? sqrt(variance) : 0.0;
        if (sd < 1e-9) continue;
        for (final entry in group) {
          if ((entry.$2 - mean).abs() > _sdMultiplier * sd) {
            outliers.add((entry.$1, a.id));
          }
        }
      }
    }
    return outliers;
  }

  /// Ratings with [RatingRecord.amended] == true (in-place amendments).
  static List<RatingRecord> findAmendedRatings(List<RatingRecord> ratings) {
    return ratings
        .where((r) => !r.isDeleted && r.isCurrent && r.amended)
        .toList();
  }

  /// Ratings where [RatingRecord.raterName] is null (unattributed).
  static List<RatingRecord> findUnattributedRatings(List<RatingRecord> ratings) {
    return ratings
        .where((r) => !r.isDeleted && r.isCurrent && r.raterName == null)
        .toList();
  }

  /// Closed sessions with no [WeatherSnapshot] (weather gap).
  static List<Session> findWeatherGaps({
    required List<Session> closedSessions,
    required List<WeatherSnapshot> snapshots,
  }) {
    final snapshotParentIds = {for (final s in snapshots) s.parentId};
    return closedSessions
        .where((s) => !snapshotParentIds.contains(s.id))
        .toList();
  }

  /// Finds the closest [WeatherSnapshot] for an application, looking for sessions
  /// within ±3 days of [applicationDate].
  ///
  /// Returns null when no session falls within the window.
  static WeatherSnapshot? findApplicationWeather({
    required DateTime applicationDate,
    required List<Session> sessions,
    required List<WeatherSnapshot> snapshots,
  }) {
    final snapshotBySession = <int, WeatherSnapshot>{
      for (final s in snapshots) s.parentId: s,
    };

    Session? best;
    int? bestDiff;
    for (final s in sessions) {
      final parsed = DateTime.tryParse(s.sessionDateLocal);
      if (parsed == null) continue;
      final diff = parsed.difference(applicationDate).inDays.abs();
      if (diff > 3) continue;
      if (bestDiff == null || diff < bestDiff) {
        bestDiff = diff;
        best = s;
      }
    }
    if (best == null) return null;
    return snapshotBySession[best.id];
  }
}
