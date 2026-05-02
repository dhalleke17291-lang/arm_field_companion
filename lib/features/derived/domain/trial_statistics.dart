// Pure statistics functions for trial assessment data.
// No I/O; no overwriting of raw evidence.
// Follows the same pattern as derived_calc.dart.

import 'dart:math' as math;

import '../../../core/assessment_result_direction.dart';
import '../../export/standalone_report_data.dart';
import 'anova.dart';

enum AssessmentCompleteness {
  noData, // 0 plots have a valid numeric value
  inProgress, // some plots rated, not all
  complete, // all plots rated
}

enum CvSignal { low, typical, high, suppressed }

class CvInterpretation {
  final CvSignal signal;
  final String displayValue;
  final String message;
  final bool showCvNumber;

  const CvInterpretation({
    required this.signal,
    required this.displayValue,
    required this.message,
    required this.showCvNumber,
  });
}

/// Broad category of an assessment, used to interpret statistics sensibly.
enum AssessmentCategory {
  continuous,
  count,
  percent,
  unknown,
}

class CvBands {
  final double lowMax;
  final double typicalMax;
  const CvBands({required this.lowMax, required this.typicalMax});
}

const _cvBands = <AssessmentCategory, CvBands>{
  AssessmentCategory.continuous: CvBands(lowMax: 10, typicalMax: 25),
  AssessmentCategory.count: CvBands(lowMax: 20, typicalMax: 50),
  AssessmentCategory.percent: CvBands(lowMax: 25, typicalMax: 75),
  AssessmentCategory.unknown: CvBands(lowMax: 15, typicalMax: 40),
};

const double _percentLowMeanFloor = 10.0;
const int _minRepsForCv = 4;

// Power interpretation thresholds.
// Extension literature (U of Maryland, U of Delaware): treatment differences
// of ~10-20% of mean are typically the smallest detectable in well-run trials.
// Above ~40% of mean, a null result is essentially uninformative.
const double _adequateMax = 20.0;
const double _marginalMax = 40.0;

// Delta color suppression: CV at or above this threshold suppresses green/red
// coloring on treatment-vs-check comparisons. CV exactly at threshold is on
// the wrong side of the boundary — suppress. Unknown CV also suppresses.
const double kHighCvDeltaColorSuppressionThreshold = 50.0;

enum PowerVerdict { adequate, marginal, underpowered }

class PowerInterpretation {
  final PowerVerdict verdict;
  final String message;
  const PowerInterpretation({required this.verdict, required this.message});
}

PowerInterpretation interpretPower({
  required double detectableDifferencePercentOfMean,
}) {
  final dd = detectableDifferencePercentOfMean;
  if (dd <= _adequateMax) {
    return const PowerInterpretation(
      verdict: PowerVerdict.adequate,
      message: '',
    );
  }
  if (dd <= _marginalMax) {
    return PowerInterpretation(
      verdict: PowerVerdict.marginal,
      message:
          'Trial can reliably detect only moderate-to-large differences (>${dd.round()}% of mean).',
    );
  }
  return PowerInterpretation(
    verdict: PowerVerdict.underpowered,
    message:
        'Underpowered: treatments must differ by >${dd.round()}% of mean to detect. Interpret non-significant results with caution.',
  );
}

// TODO(parminder): review prefix mapping before CRO handoff
const _continuousPrefixes = [
  'YIELD', 'BIOMAS', 'HEIGHT', 'MOISTR', 'WEIGHT', 'GRNWGT', 'STWGT',
];
const _countPrefixes = [
  'STAND', 'WEDCNT', 'INSCNT', 'POPCNT', 'PLTCNT',
];
const _percentPrefixes = [
  'CONTRO', 'PHYGEN', 'PHYCHL', 'PHYNEC', 'CANOPY', 'WEDCON',
  'PESINC', 'WEDINC', 'DISINC', 'DISSEV', 'LODGIN', 'COVER',
];

/// Classifies an ARM assessment code into a broad category for stats interpretation.
AssessmentCategory classifyAssessmentCode(String? code) {
  if (code == null) return AssessmentCategory.unknown;
  final upper = code.trim().toUpperCase();
  if (upper.isEmpty) return AssessmentCategory.unknown;
  for (final p in _continuousPrefixes) {
    if (upper.startsWith(p)) return AssessmentCategory.continuous;
  }
  for (final p in _countPrefixes) {
    if (upper.startsWith(p)) return AssessmentCategory.count;
  }
  for (final p in _percentPrefixes) {
    if (upper.startsWith(p)) return AssessmentCategory.percent;
  }
  return AssessmentCategory.unknown;
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
    this.totalReps = 0,
    this.anovaResult,
    this.sessionId,
    this.sessionDate,
  });

  final AssessmentProgress progress;
  final String unit;
  final ResultDirection resultDirection;
  final List<TreatmentMean> treatmentMeans;

  final double? trialCV;
  final CvInterpretation? cvInterpretation;
  final List<PlotOutlier>? outliers; // v2
  final List<RepConsistencyIssue> repConsistencyIssues;
  final int totalReps;
  final AnovaResult? anovaResult;

  /// DB session ID for which statistics were computed. Null when pooled or
  /// when no session context is available (standalone, no ratings yet).
  final int? sessionId;

  /// ISO-8601 date string from arm_session_metadata. Null for standalone trials
  /// or assessments with no ARM session metadata.
  final String? sessionDate;

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

/// Category-aware CV interpretation. Evaluates in priority order:
/// null CV → suppressed; low n → suppressed; low-mean percent → suppressed;
/// then band lookup by category.
CvInterpretation interpretCV({
  required double? cv,
  required double mean,
  required int n,
  required AssessmentCategory category,
}) {
  if (cv == null) {
    return const CvInterpretation(
      signal: CvSignal.suppressed,
      displayValue: '',
      message: 'CV could not be computed.',
      showCvNumber: false,
    );
  }
  if (n < _minRepsForCv) {
    return CvInterpretation(
      signal: CvSignal.suppressed,
      displayValue: 'CV ${cv.toStringAsFixed(1)}%',
      message: 'Too few replications for a reliable CV estimate.',
      showCvNumber: false,
    );
  }
  if (category == AssessmentCategory.percent &&
      mean.abs() < _percentLowMeanFloor) {
    return CvInterpretation(
      signal: CvSignal.suppressed,
      displayValue: 'CV ${cv.toStringAsFixed(1)}%',
      message:
          'Mean is low enough that CV is not informative. Evaluate trial sensitivity via detectable difference instead.',
      showCvNumber: false,
    );
  }

  final bands = _cvBands[category] ?? _cvBands[AssessmentCategory.unknown]!;
  final display = 'CV ${cv.toStringAsFixed(1)}%';

  if (cv <= bands.lowMax) {
    return CvInterpretation(
      signal: CvSignal.low,
      displayValue: display,
      message: 'Low variability.',
      showCvNumber: true,
    );
  }
  if (cv <= bands.typicalMax) {
    final msg = switch (category) {
      AssessmentCategory.continuous =>
        'Within typical range for yield/biomass data.',
      AssessmentCategory.count =>
        'Within typical range for count data.',
      AssessmentCategory.percent =>
        'Within typical range for visual % ratings.',
      AssessmentCategory.unknown => 'Within typical range.',
    };
    return CvInterpretation(
      signal: CvSignal.typical,
      displayValue: display,
      message: msg,
      showCvNumber: true,
    );
  }

  final msg = switch (category) {
    AssessmentCategory.continuous =>
      'Higher than typical for yield data. Review per-plot detail for field variability or outliers.',
    AssessmentCategory.count =>
      'Higher than typical for count data. Review per-plot detail for outliers.',
    AssessmentCategory.percent =>
      'Higher than typical. Visual ratings near 0% or 100% inherently produce high CVs — check per-plot detail.',
    AssessmentCategory.unknown => 'Higher than typical. Review per-plot detail.',
  };
  return CvInterpretation(
    signal: CvSignal.high,
    displayValue: display,
    message: msg,
    showCvNumber: true,
  );
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
  Set<int> allReps, {
  String? assessmentCode,
  int? sessionId,
  String? sessionDate,
}) {
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

  // Grand mean and total n for CV interpretation.
  var totalN = 0;
  var sumWeightedMean = 0.0;
  for (final m in means) {
    totalN += m.n;
    sumWeightedMean += m.n * m.mean;
  }
  final grandMean = totalN > 0 ? sumWeightedMean / totalN : 0.0;
  final category = classifyAssessmentCode(assessmentCode);

  // Compute ANOVA when data is complete (all plots rated).
  AnovaResult? anova;
  if (progress.completeness == AssessmentCompleteness.complete &&
      means.length >= 2) {
    anova = _computeAnovaForAssessment(rows, assessmentName, allReps);
  }

  return AssessmentStatistics(
    progress: progress,
    unit: unit,
    resultDirection: direction,
    treatmentMeans: means,
    trialCV: cv,
    cvInterpretation: interpretCV(
      cv: cv,
      mean: grandMean,
      n: totalN,
      category: category,
    ),
    outliers: null, // v2
    repConsistencyIssues: repIssues,
    totalReps: allReps.length,
    anovaResult: anova,
    sessionId: sessionId,
    sessionDate: sessionDate,
  );
}

/// Builds ANOVA input from raw rating rows. Attempts RCBD first (when reps
/// exist and data is balanced), falls back to one-way CRD.
AnovaResult? _computeAnovaForAssessment(
  List<RatingResultRow> rows,
  String assessmentName,
  Set<int> allReps,
) {
  // Enforce single-session contract: ANOVA on pooled multi-session data is
  // scientifically invalid. Caller must pre-filter rows to one session.
  final distinctSessionIds = rows
      .where((r) => r.assessmentName == assessmentName && r.sessionId != null)
      .map((r) => r.sessionId!)
      .toSet();
  if (distinctSessionIds.length > 1) {
    throw ArgumentError(
      '_computeAnovaForAssessment: rows span ${distinctSessionIds.length} '
      'sessions $distinctSessionIds. Filter to a single session before calling.',
    );
  }

  // Build treatmentCode → {rep → mean of values in that cell}.
  // In a proper RCBD each cell has exactly one observation; if multiple
  // plots share the same (treatment, rep), average them.
  final byTrtRep = <String, Map<int, List<double>>>{};
  for (final row in rows) {
    if (row.assessmentName != assessmentName) continue;
    if (row.resultStatus != 'RECORDED') continue;
    final v = double.tryParse(row.value);
    if (v == null) continue;
    byTrtRep
        .putIfAbsent(row.treatmentCode, () => {})
        .putIfAbsent(row.rep, () => [])
        .add(v);
  }

  if (byTrtRep.length < 2) return null;

  // Try RCBD if reps are present and >= 2.
  if (allReps.length >= 2) {
    final rcbdInput = <String, Map<int, double>>{};
    for (final entry in byTrtRep.entries) {
      rcbdInput[entry.key] = {};
      for (final repEntry in entry.value.entries) {
        final vals = repEntry.value;
        rcbdInput[entry.key]![repEntry.key] =
            vals.reduce((a, b) => a + b) / vals.length;
      }
    }
    final result = computeRcbdAnova(rcbdInput);
    if (result != null) return result;
  }

  // Fallback: one-way CRD.
  final crdInput = <String, List<double>>{};
  for (final entry in byTrtRep.entries) {
    crdInput[entry.key] = [];
    for (final vals in entry.value.values) {
      crdInput[entry.key]!.addAll(vals);
    }
  }
  return computeOneWayAnova(crdInput);
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
