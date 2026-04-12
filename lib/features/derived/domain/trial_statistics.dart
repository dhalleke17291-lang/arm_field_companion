// Pure statistics functions for trial assessment data.
// No I/O; no overwriting of raw evidence.
// Follows the same pattern as derived_calc.dart.

import 'dart:math' as math;

import '../../../core/assessment_result_direction.dart';
import '../../export/standalone_report_data.dart';

enum AssessmentCompleteness {
  noData, // 0 plots have a valid numeric value
  inProgress, // some plots rated, not all
  complete, // all plots rated
}

enum CvInterpretation {
  excellent, // CV < 10%
  acceptable, // CV 10–20%
  questionable, // CV 20–30%
  poor, // CV > 30%
}

class AssessmentProgress {
  const AssessmentProgress({
    required this.assessmentId,
    required this.assessmentName,
    required this.ratedPlots,
    required this.totalPlots,
    required this.completeness,
    required this.missingReps,
  });

  final int assessmentId;
  final String assessmentName;
  final int ratedPlots;
  final int totalPlots;
  final AssessmentCompleteness completeness;
  final List<int> missingReps;

  bool get hasAnyData => ratedPlots > 0;
  bool get isPreliminary =>
      completeness != AssessmentCompleteness.complete;
}

class TreatmentMean {
  const TreatmentMean({
    required this.treatmentCode,
    required this.mean,
    required this.standardDeviation,
    required this.standardError,
    required this.n,
    required this.min,
    required this.max,
    required this.isPreliminary,
  });

  final String treatmentCode;
  final double mean;
  final double standardDeviation;
  final double standardError;
  final int n;
  final double min;
  final double max;
  final bool isPreliminary;
}

class PlotOutlier {
  const PlotOutlier({
    required this.plotId,
    required this.rep,
    required this.treatmentCode,
    required this.value,
    required this.treatmentMean,
    required this.deviationsFromMean,
  });

  final String plotId;
  final int rep;
  final String treatmentCode;
  final double value;
  final double treatmentMean;
  final double deviationsFromMean;
  // NOTE: computed in v2 only — class defined now for future use
}

class AssessmentStatistics {
  const AssessmentStatistics({
    required this.progress,
    required this.unit,
    required this.resultDirection,
    required this.treatmentMeans,
    this.trialCV,
    this.cvInterpretation,
    this.outliers,
    this.repConsistencyIssues = const [],
  });

  final AssessmentProgress progress;
  final String unit;
  final ResultDirection resultDirection;
  final List<TreatmentMean> treatmentMeans;

  final double? trialCV;
  final CvInterpretation? cvInterpretation;
  final List<PlotOutlier>? outliers; // v2
  final List<RepConsistencyIssue> repConsistencyIssues;

  bool get hasAnyData => progress.hasAnyData;
  bool get isPreliminary => progress.isPreliminary;
}

/// Returns only valid numeric values from [rows] for [assessmentName].
/// Includes: resultStatus == 'RECORDED' and double.tryParse(value) != null.
/// Excludes: resultStatus == 'VOID' or non-numeric values.
Map<String, List<double>> _numericValuesByTreatment(
  List<RatingResultRow> rows,
  String assessmentName,
) {
  final result = <String, List<double>>{};
  for (final row in rows) {
    if (row.assessmentName != assessmentName) continue;
    if (row.resultStatus != 'RECORDED') continue;
    final v = double.tryParse(row.value);
    if (v == null) continue;
    result.putIfAbsent(row.treatmentCode, () => []).add(v);
  }
  return result;
}

/// Returns plot IDs with at least one valid RECORDED numeric value
/// for [assessmentName].
Set<String> _ratedPlotIds(
  List<RatingResultRow> rows,
  String assessmentName,
) {
  final result = <String>{};
  for (final row in rows) {
    if (row.assessmentName != assessmentName) continue;
    if (row.resultStatus != 'RECORDED') continue;
    if (double.tryParse(row.value) == null) continue;
    result.add(row.plotId);
  }
  return result;
}

/// Determines completeness of [assessmentName] data.
/// [totalPlots] is the total number of plots in the trial.
AssessmentCompleteness computeCompleteness(
  List<RatingResultRow> rows,
  String assessmentName,
  int totalPlots,
) {
  if (totalPlots <= 0) return AssessmentCompleteness.noData;
  final rated = _ratedPlotIds(rows, assessmentName).length;
  if (rated == 0) return AssessmentCompleteness.noData;
  if (rated >= totalPlots) return AssessmentCompleteness.complete;
  return AssessmentCompleteness.inProgress;
}

/// Returns which rep numbers have no rated plots for [assessmentName].
/// Uses the rep field on RatingResultRow for reps that DO have data,
/// then infers missing reps from [allReps].
/// [allReps] is the set of all rep numbers in the trial.
List<int> computeMissingReps(
  List<RatingResultRow> rows,
  String assessmentName,
  Set<int> allReps,
) {
  final ratedReps = <int>{};
  for (final row in rows) {
    if (row.assessmentName != assessmentName) continue;
    if (row.resultStatus != 'RECORDED') continue;
    if (double.tryParse(row.value) == null) continue;
    ratedReps.add(row.rep);
  }
  return allReps.where((r) => !ratedReps.contains(r)).toList()..sort();
}

/// Assembles [AssessmentProgress] for [assessmentName].
AssessmentProgress computeProgress(
  List<RatingResultRow> rows,
  String assessmentName,
  int assessmentId,
  int totalPlots,
  Set<int> allReps,
) {
  final completeness = computeCompleteness(rows, assessmentName, totalPlots);
  final ratedPlots = _ratedPlotIds(rows, assessmentName).length;
  final missingReps = computeMissingReps(rows, assessmentName, allReps);
  return AssessmentProgress(
    assessmentId: assessmentId,
    assessmentName: assessmentName,
    ratedPlots: ratedPlots,
    totalPlots: totalPlots,
    completeness: completeness,
    missingReps: missingReps,
  );
}

/// Computes [TreatmentMean] for each treatment with valid numeric data.
/// [isPreliminary] should be true when completeness != complete.
List<TreatmentMean> computeTreatmentMeans(
  List<RatingResultRow> rows,
  String assessmentName,
  bool isPreliminary,
) {
  final byTreatment = _numericValuesByTreatment(rows, assessmentName);
  if (byTreatment.isEmpty) return [];

  final result = <TreatmentMean>[];
  for (final entry in byTreatment.entries) {
    final values = entry.value;
    if (values.isEmpty) continue;
    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final variance = values
            .map((v) => math.pow(v - mean, 2))
            .reduce((a, b) => a + b) /
        (n > 1 ? n - 1 : 1); // sample variance (n-1)
    final sd = math.sqrt(variance);
    final se = n > 0 ? sd / math.sqrt(n.toDouble()) : 0.0;
    result.add(TreatmentMean(
      treatmentCode: entry.key,
      mean: mean,
      standardDeviation: sd,
      standardError: se,
      n: n,
      min: min,
      max: max,
      isPreliminary: isPreliminary,
    ));
  }

  return result;
}

/// Interprets a CV% value using standard field research thresholds.
/// CV < 10 → excellent, 10–20 → acceptable, 20–30 → questionable, > 30 → poor.
CvInterpretation interpretCV(double cv) {
  if (cv < 10) return CvInterpretation.excellent;
  if (cv < 20) return CvInterpretation.acceptable;
  if (cv < 30) return CvInterpretation.questionable;
  return CvInterpretation.poor;
}

/// Assembles complete [AssessmentStatistics] for [assessmentName].
/// Computes the pooled (error) CV% across treatments.
///
/// Uses pooled within-treatment variance and the grand mean:
///   pooledVar = Σ((nᵢ−1)·SDᵢ²) / Σ(nᵢ−1)
///   grandMean = Σ(nᵢ·meanᵢ) / Σ(nᵢ)
///   CV% = √pooledVar / grandMean × 100
///
/// Returns null when fewer than 2 total observations or grand mean is zero.
double? computeTrialCV(List<TreatmentMean> means) {
  if (means.isEmpty) return null;
  var totalN = 0;
  var sumWeightedMean = 0.0;
  var sumWeightedVar = 0.0;
  var totalDf = 0;
  for (final m in means) {
    totalN += m.n;
    sumWeightedMean += m.n * m.mean;
    final df = m.n - 1;
    if (df > 0) {
      sumWeightedVar += df * m.standardDeviation * m.standardDeviation;
      totalDf += df;
    }
  }
  if (totalN < 2 || totalDf == 0) return null;
  final grandMean = sumWeightedMean / totalN;
  if (grandMean == 0) return null;
  final pooledSd = math.sqrt(sumWeightedVar / totalDf);
  return (pooledSd / grandMean.abs()) * 100;
}

/// Assembles complete [AssessmentStatistics] for [assessmentName].
AssessmentStatistics computeAssessmentStatistics(
  List<RatingResultRow> rows,
  String assessmentName,
  int assessmentId,
  String unit,
  String resultDirectionString,
  int totalPlots,
  Set<int> allReps,
) {
  final progress = computeProgress(
    rows,
    assessmentName,
    assessmentId,
    totalPlots,
    allReps,
  );
  final means = computeTreatmentMeans(
    rows,
    assessmentName,
    progress.isPreliminary,
  );
  final direction = ResultDirection.fromString(resultDirectionString);
  final cv = computeTrialCV(means);
  final repIssues = computeRepConsistency(rows, assessmentName);
  return AssessmentStatistics(
    progress: progress,
    unit: unit,
    resultDirection: direction,
    treatmentMeans: means,
    trialCV: cv,
    cvInterpretation: cv != null ? interpretCV(cv) : null,
    outliers: null, // v2
    repConsistencyIssues: repIssues,
  );
}

/// Sorts [TreatmentMean] list by result direction for display.
/// higherIsBetter → descending mean (best first)
/// lowerIsBetter  → ascending mean (best first)
/// neutral        → alphabetical by treatmentCode
List<TreatmentMean> sortTreatmentMeans(
  List<TreatmentMean> means,
  ResultDirection direction,
) {
  final sorted = List<TreatmentMean>.from(means);
  switch (direction) {
    case ResultDirection.higherIsBetter:
      sorted.sort((a, b) => b.mean.compareTo(a.mean));
      break;
    case ResultDirection.lowerIsBetter:
      sorted.sort((a, b) => a.mean.compareTo(b.mean));
      break;
    case ResultDirection.neutral:
      sorted.sort((a, b) => a.treatmentCode.compareTo(b.treatmentCode));
      break;
  }
  return sorted;
}

/// Computes percent change of each treatment mean relative to the check treatment.
/// Returns a map of treatmentCode → percent change (e.g. -42.0 means 42% lower than check).
/// The check treatment itself is excluded from the result.
/// Returns empty map when [checkTreatmentCode] is null, not found, or check mean is zero.
Map<String, double> computeCheckComparison(
  List<TreatmentMean> means,
  String? checkTreatmentCode,
) {
  if (checkTreatmentCode == null || means.isEmpty) return {};
  final checkMean = means
      .where((m) => m.treatmentCode == checkTreatmentCode)
      .map((m) => m.mean)
      .firstOrNull;
  if (checkMean == null || checkMean == 0) return {};
  final result = <String, double>{};
  for (final m in means) {
    if (m.treatmentCode == checkTreatmentCode) continue;
    result[m.treatmentCode] = ((m.mean - checkMean) / checkMean) * 100;
  }
  return result;
}

/// Rep where the treatment ranking differs from the consensus (majority) ranking.
class RepConsistencyIssue {
  const RepConsistencyIssue({
    required this.rep,
    required this.repRanking,
    required this.consensusRanking,
  });

  final int rep;

  /// Treatment codes in order of mean value (descending) for this rep.
  final List<String> repRanking;

  /// Treatment codes in order of mean value (descending) across all reps combined.
  final List<String> consensusRanking;
}

/// Checks whether treatment rankings are consistent across reps.
///
/// Computes treatment mean within each rep, ranks them (descending by mean),
/// then compares each rep's ranking to the consensus (overall treatment means).
/// Returns a list of reps whose ranking differs from the consensus.
///
/// Returns empty list when fewer than 2 reps or fewer than 2 treatments.
List<RepConsistencyIssue> computeRepConsistency(
  List<RatingResultRow> rows,
  String assessmentName,
) {
  // Group values by (rep, treatmentCode).
  final byRepTreatment = <int, Map<String, List<double>>>{};
  for (final row in rows) {
    if (row.assessmentName != assessmentName) continue;
    if (row.resultStatus != 'RECORDED') continue;
    final v = double.tryParse(row.value);
    if (v == null) continue;
    byRepTreatment
        .putIfAbsent(row.rep, () => {})
        .putIfAbsent(row.treatmentCode, () => [])
        .add(v);
  }

  if (byRepTreatment.length < 2) return [];

  // Compute per-rep treatment means and rank (descending).
  List<String> rankTreatments(Map<String, List<double>> treatmentValues) {
    final means = <String, double>{};
    for (final entry in treatmentValues.entries) {
      final vals = entry.value;
      if (vals.isEmpty) continue;
      means[entry.key] = vals.reduce((a, b) => a + b) / vals.length;
    }
    final sorted = means.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  // Consensus: pool all reps.
  final pooled = <String, List<double>>{};
  for (final repMap in byRepTreatment.values) {
    for (final entry in repMap.entries) {
      pooled.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
  }
  final consensusRanking = rankTreatments(pooled);
  if (consensusRanking.length < 2) return [];

  final issues = <RepConsistencyIssue>[];
  for (final entry in byRepTreatment.entries) {
    final repRanking = rankTreatments(entry.value);
    if (repRanking.length < 2) continue;
    // Compare only treatments present in both rankings.
    final common = consensusRanking.where(repRanking.contains).toList();
    final repFiltered = repRanking.where(common.contains).toList();
    if (common.length < 2) continue;
    if (!_rankingsMatch(common, repFiltered)) {
      issues.add(RepConsistencyIssue(
        rep: entry.key,
        repRanking: repRanking,
        consensusRanking: consensusRanking,
      ));
    }
  }
  return issues;
}

bool _rankingsMatch(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
