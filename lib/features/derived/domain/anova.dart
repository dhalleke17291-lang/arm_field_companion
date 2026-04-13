// One-way and RCBD ANOVA with LSD means separation and significance letters.
// Pure functions. No I/O. No database access.
//
// Follows the same pattern as trial_statistics.dart: takes raw data in,
// returns immutable result objects out.

import 'dart:math' as math;

import 'stat_distributions.dart';

// ── Result models ──────────────────────────────────────────────────────────

/// Significance level thresholds used for display.
enum SignificanceLevel {
  /// p < 0.01
  highlySignificant,

  /// p < 0.05
  significant,

  /// p < 0.10
  marginallysignificant,

  /// p >= 0.10
  notSignificant,
}

SignificanceLevel classifyPValue(double p) {
  if (p < 0.01) return SignificanceLevel.highlySignificant;
  if (p < 0.05) return SignificanceLevel.significant;
  if (p < 0.10) return SignificanceLevel.marginallysignificant;
  return SignificanceLevel.notSignificant;
}

String significanceLevelLabel(SignificanceLevel level) {
  switch (level) {
    case SignificanceLevel.highlySignificant:
      return 'Highly significant (p < 0.01)';
    case SignificanceLevel.significant:
      return 'Significant (p < 0.05)';
    case SignificanceLevel.marginallysignificant:
      return 'Marginal (p < 0.10)';
    case SignificanceLevel.notSignificant:
      return 'Not significant';
  }
}

/// Single row in the ANOVA table.
class AnovaSourceRow {
  const AnovaSourceRow({
    required this.source,
    required this.df,
    required this.sumOfSquares,
    required this.meanSquare,
    this.fStatistic,
    this.pValue,
  });

  final String source;
  final int df;
  final double sumOfSquares;
  final double meanSquare;
  final double? fStatistic;
  final double? pValue;
}

/// Complete ANOVA result with means separation.
class AnovaResult {
  const AnovaResult({
    required this.sourceRows,
    required this.treatmentF,
    required this.treatmentPValue,
    required this.significance,
    required this.errorMeanSquare,
    required this.errorDf,
    required this.grandMean,
    required this.totalN,
    required this.model,
    this.lsd,
    this.treatmentMeansWithLetters = const [],
  });

  /// Rows for the ANOVA summary table (Treatment, [Rep], Error, Total).
  final List<AnovaSourceRow> sourceRows;

  final double treatmentF;
  final double treatmentPValue;
  final SignificanceLevel significance;

  /// MSE — used for LSD calculation and downstream comparisons.
  final double errorMeanSquare;
  final int errorDf;
  final double grandMean;
  final int totalN;

  /// 'CRD' for one-way, 'RCBD' for randomized complete block.
  final String model;

  /// LSD value at alpha=0.05 (null when not computed or n unbalanced).
  final double? lsd;

  /// Treatment means with significance group letters, sorted by mean descending.
  final List<TreatmentMeanWithLetter> treatmentMeansWithLetters;

  bool get isSignificant => treatmentPValue < 0.05;
}

/// Treatment mean annotated with significance group letter(s).
class TreatmentMeanWithLetter {
  const TreatmentMeanWithLetter({
    required this.treatmentCode,
    required this.mean,
    required this.n,
    required this.letter,
  });

  final String treatmentCode;
  final double mean;
  final int n;

  /// Significance group letter(s): 'a', 'b', 'ab', etc.
  /// Treatments sharing a letter are NOT significantly different.
  final String letter;
}

// ── One-way ANOVA (CRD) ──────────────────────────────────────────────────

/// Computes one-way ANOVA (completely randomized design).
///
/// [valuesByTreatment]: map of treatmentCode → list of numeric observations.
/// Returns null when fewer than 2 treatments or fewer than 2 total observations.
AnovaResult? computeOneWayAnova(Map<String, List<double>> valuesByTreatment,
    {double alpha = 0.05}) {
  final treatments = valuesByTreatment.entries
      .where((e) => e.value.isNotEmpty)
      .toList();
  if (treatments.length < 2) return null;

  final k = treatments.length;
  final allValues = treatments.expand((e) => e.value).toList();
  final n = allValues.length;
  if (n < k + 1) return null; // need at least 1 df for error

  final grandMean = allValues.reduce((a, b) => a + b) / n;

  // SS Treatment = Σ nᵢ(ȳᵢ - ȳ..)²
  var ssTreatment = 0.0;
  final treatmentMeans = <String, ({double mean, int n})>{};
  for (final entry in treatments) {
    final vals = entry.value;
    final ni = vals.length;
    final tMean = vals.reduce((a, b) => a + b) / ni;
    treatmentMeans[entry.key] = (mean: tMean, n: ni);
    ssTreatment += ni * (tMean - grandMean) * (tMean - grandMean);
  }

  // SS Total = Σ (yᵢⱼ - ȳ..)²
  var ssTotal = 0.0;
  for (final v in allValues) {
    ssTotal += (v - grandMean) * (v - grandMean);
  }

  // SS Error = SS Total - SS Treatment
  final ssError = ssTotal - ssTreatment;

  final dfTreatment = k - 1;
  final dfError = n - k;
  final dfTotal = n - 1;

  if (dfError <= 0) return null;

  final msTreatment = ssTreatment / dfTreatment;
  final msError = ssError / dfError;
  final fStat = msError > 0 ? msTreatment / msError : double.infinity;
  final pValue = msError > 0
      ? fDistributionPValue(fStat, dfTreatment.toDouble(), dfError.toDouble())
      : 0.0;

  // LSD at specified alpha (balanced case: uses harmonic mean of n's).
  final harmonicN = _harmonicMeanN(treatments.map((e) => e.value.length));
  final tCrit = tCriticalTwoTailed(alpha, dfError.toDouble());
  final lsd = tCrit * _sqrt(2 * msError / harmonicN);

  // Protected LSD (Fisher's LSD): only perform pairwise comparisons
  // when the overall F-test is significant. When F is non-significant,
  // all treatments get the same letter 'a'. This matches ARM default behavior.
  final sortedMeans = treatmentMeans.entries.toList()
    ..sort((a, b) => b.value.mean.compareTo(a.value.mean));
  final isOverallSignificant = pValue < alpha;
  final letters = isOverallSignificant
      ? _assignSignificanceLetters(
          sortedMeans.map((e) => (code: e.key, mean: e.value.mean)).toList(),
          lsd,
        )
      : List.filled(sortedMeans.length, 'a');

  final meansWithLetters = <TreatmentMeanWithLetter>[];
  for (var i = 0; i < sortedMeans.length; i++) {
    final entry = sortedMeans[i];
    meansWithLetters.add(TreatmentMeanWithLetter(
      treatmentCode: entry.key,
      mean: entry.value.mean,
      n: entry.value.n,
      letter: letters[i],
    ));
  }

  return AnovaResult(
    sourceRows: [
      AnovaSourceRow(
        source: 'Treatment',
        df: dfTreatment,
        sumOfSquares: ssTreatment,
        meanSquare: msTreatment,
        fStatistic: fStat,
        pValue: pValue,
      ),
      AnovaSourceRow(
        source: 'Error',
        df: dfError,
        sumOfSquares: ssError,
        meanSquare: msError,
      ),
      AnovaSourceRow(
        source: 'Total',
        df: dfTotal,
        sumOfSquares: ssTotal,
        meanSquare: ssTotal / dfTotal,
      ),
    ],
    treatmentF: fStat,
    treatmentPValue: pValue,
    significance: classifyPValue(pValue),
    errorMeanSquare: msError,
    errorDf: dfError,
    grandMean: grandMean,
    totalN: n,
    model: 'CRD',
    lsd: lsd,
    treatmentMeansWithLetters: meansWithLetters,
  );
}

// ── RCBD ANOVA ───────────────────────────────────────────────────────────

/// Computes RCBD (randomized complete block design) ANOVA.
///
/// [valuesByTreatmentAndRep]: treatmentCode → { rep → value }.
/// Each treatment should have one observation per rep.
/// Returns null when fewer than 2 treatments or 2 reps.
AnovaResult? computeRcbdAnova(
  Map<String, Map<int, double>> valuesByTreatmentAndRep, {
  double alpha = 0.05,
}) {
  final treatments = valuesByTreatmentAndRep.entries
      .where((e) => e.value.isNotEmpty)
      .toList();
  if (treatments.length < 2) return null;

  // Collect all reps that have data across all treatments.
  final allReps = <int>{};
  for (final entry in treatments) {
    allReps.addAll(entry.value.keys);
  }
  if (allReps.length < 2) return null;

  final k = treatments.length; // number of treatments
  final r = allReps.length; // number of reps/blocks
  final n = k * r;

  // Build balanced data matrix (treatment × rep). Skip if unbalanced.
  final data = <String, Map<int, double>>{};
  for (final entry in treatments) {
    data[entry.key] = {};
    for (final rep in allReps) {
      final val = entry.value[rep];
      if (val == null) {
        // Unbalanced — fall back to one-way.
        final flat = <String, List<double>>{};
        for (final t in treatments) {
          flat[t.key] = t.value.values.toList();
        }
        return computeOneWayAnova(flat, alpha: alpha);
      }
      data[entry.key]![rep] = val;
    }
  }

  // Grand mean.
  var grandSum = 0.0;
  for (final trt in data.values) {
    for (final v in trt.values) {
      grandSum += v;
    }
  }
  final grandMean = grandSum / n;

  // Treatment means.
  final trtMeans = <String, double>{};
  for (final entry in data.entries) {
    trtMeans[entry.key] =
        entry.value.values.reduce((a, b) => a + b) / r;
  }

  // Rep (block) means.
  final repMeans = <int, double>{};
  for (final rep in allReps) {
    var sum = 0.0;
    for (final trt in data.values) {
      sum += trt[rep]!;
    }
    repMeans[rep] = sum / k;
  }

  // Sum of squares.
  var ssTreatment = 0.0;
  for (final mean in trtMeans.values) {
    ssTreatment += r * (mean - grandMean) * (mean - grandMean);
  }

  var ssRep = 0.0;
  for (final mean in repMeans.values) {
    ssRep += k * (mean - grandMean) * (mean - grandMean);
  }

  var ssTotal = 0.0;
  for (final trt in data.entries) {
    for (final v in trt.value.values) {
      ssTotal += (v - grandMean) * (v - grandMean);
    }
  }

  final ssError = ssTotal - ssTreatment - ssRep;

  final dfTreatment = k - 1;
  final dfRep = r - 1;
  final dfError = (k - 1) * (r - 1);
  final dfTotal = n - 1;

  if (dfError <= 0) return null;

  final msTreatment = ssTreatment / dfTreatment;
  final msRep = ssRep / dfRep;
  final msError = ssError / dfError;

  final fTreatment = msError > 0 ? msTreatment / msError : double.infinity;
  final pTreatment = msError > 0
      ? fDistributionPValue(
          fTreatment, dfTreatment.toDouble(), dfError.toDouble())
      : 0.0;

  // LSD for RCBD.
  final tCrit = tCriticalTwoTailed(alpha, dfError.toDouble());
  final lsd = tCrit * _sqrt(2 * msError / r);

  // Protected LSD: pairwise comparisons only when overall F significant.
  final sortedMeans = trtMeans.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final isOverallSignificant = pTreatment < alpha;
  final letters = isOverallSignificant
      ? _assignSignificanceLetters(
          sortedMeans.map((e) => (code: e.key, mean: e.value)).toList(),
          lsd,
        )
      : List.filled(sortedMeans.length, 'a');

  final meansWithLetters = <TreatmentMeanWithLetter>[];
  for (var i = 0; i < sortedMeans.length; i++) {
    final entry = sortedMeans[i];
    meansWithLetters.add(TreatmentMeanWithLetter(
      treatmentCode: entry.key,
      mean: entry.value,
      n: r,
      letter: letters[i],
    ));
  }

  return AnovaResult(
    sourceRows: [
      AnovaSourceRow(
        source: 'Treatment',
        df: dfTreatment,
        sumOfSquares: ssTreatment,
        meanSquare: msTreatment,
        fStatistic: fTreatment,
        pValue: pTreatment,
      ),
      AnovaSourceRow(
        source: 'Rep (Block)',
        df: dfRep,
        sumOfSquares: ssRep,
        meanSquare: msRep,
      ),
      AnovaSourceRow(
        source: 'Error',
        df: dfError,
        sumOfSquares: ssError,
        meanSquare: msError,
      ),
      AnovaSourceRow(
        source: 'Total',
        df: dfTotal,
        sumOfSquares: ssTotal,
        meanSquare: ssTotal / dfTotal,
      ),
    ],
    treatmentF: fTreatment,
    treatmentPValue: pTreatment,
    significance: classifyPValue(pTreatment),
    errorMeanSquare: msError,
    errorDf: dfError,
    grandMean: grandMean,
    totalN: n,
    model: 'RCBD',
    lsd: lsd,
    treatmentMeansWithLetters: meansWithLetters,
  );
}

// ── Significance letter assignment ───────────────────────────────────────

/// Assigns compact letter display (CLD) groups.
///
/// [sortedMeans]: treatments sorted descending by mean.
/// [lsd]: minimum significant difference.
///
/// Standard CLD algorithm:
/// 1. Build pairwise significance matrix.
/// 2. Create overlapping groups — each group is a maximal set of treatments
///    where no pair within the group is significantly different.
/// 3. Assign letters to groups.
///
/// Returns a list of letter strings parallel to [sortedMeans].
List<String> _assignSignificanceLetters(
  List<({String code, double mean})> sortedMeans,
  double lsd,
) {
  final n = sortedMeans.length;
  if (n == 0) return [];
  if (n == 1) return ['a'];

  // Step 1: Pairwise significance. sig[i][j] = true if i and j are
  // significantly different (|mean_i - mean_j| > lsd).
  final sig = List.generate(n, (_) => List.filled(n, false));
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final diff = (sortedMeans[i].mean - sortedMeans[j].mean).abs();
      if (diff > lsd) {
        sig[i][j] = true;
        sig[j][i] = true;
      }
    }
  }

  // Step 2: Create groups by sweeping from each treatment downward.
  // For each treatment i, form the maximal group starting at i that
  // contains only non-significant pairs. Each treatment can belong
  // to multiple groups.
  final membership = List.generate(n, (_) => <int>{});
  var groupIdx = 0;

  for (var start = 0; start < n; start++) {
    // Only start a new group from 'start' if it would contain at least
    // one treatment not already sharing a group with 'start'.
    final currentGroup = <int>[start];
    for (var j = start + 1; j < n; j++) {
      var canJoin = true;
      for (final member in currentGroup) {
        if (sig[member][j]) {
          canJoin = false;
          break;
        }
      }
      if (canJoin) currentGroup.add(j);
    }

    // Check if this group adds new information (connects treatments
    // that don't already share a group).
    var addsNew = membership[start].isEmpty;
    if (!addsNew) {
      for (final j in currentGroup) {
        if (j != start &&
            membership[start].intersection(membership[j]).isEmpty) {
          addsNew = true;
          break;
        }
      }
    }

    if (addsNew) {
      for (final idx in currentGroup) {
        membership[idx].add(groupIdx);
      }
      groupIdx++;
    }
  }

  // Step 3: Convert to letters.
  final result = <String>[];
  for (var i = 0; i < n; i++) {
    final letterIndices = membership[i].toList()..sort();
    final buf = StringBuffer();
    for (final idx in letterIndices) {
      buf.write(String.fromCharCode(97 + idx)); // 'a', 'b', 'c', ...
    }
    result.add(buf.isEmpty ? 'a' : buf.toString());
  }
  return result;
}

// ── Helpers ───────────────────────────────────────────────────────────────

double _sqrt(double x) => math.sqrt(x.abs());

double _harmonicMeanN(Iterable<int> sizes) {
  final list = sizes.toList();
  if (list.isEmpty) return 1;
  var sum = 0.0;
  for (final n in list) {
    if (n > 0) sum += 1.0 / n;
  }
  return list.length / sum;
}
