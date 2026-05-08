import 'dart:math';

enum CVTier { acceptable, moderate, high }

CVTier getCVTier(double cv) {
  if (cv < 15) return CVTier.acceptable;
  if (cv < 25) return CVTier.moderate;
  return CVTier.high;
}

double computeSD(List<double> values) {
  if (values.length < 2) return 0.0;
  final n = values.length;
  final mean = values.reduce((a, b) => a + b) / n;
  final variance = values.fold<double>(
        0.0, (sum, v) => sum + pow(v - mean, 2).toDouble()) /
      (n - 1);
  return sqrt(variance);
}

/// Tukey IQR outlier detection. Returns the indices of outlier values.
Set<int> detectOutlierIndices(List<double> values) {
  if (values.length < 4) return {};
  final sorted = List<double>.from(values)..sort();
  final q1 = _percentile(sorted, 25);
  final q3 = _percentile(sorted, 75);
  final iqr = q3 - q1;
  if (iqr == 0) return {};
  final lower = q1 - 1.5 * iqr;
  final upper = q3 + 1.5 * iqr;
  final result = <int>{};
  for (var i = 0; i < values.length; i++) {
    if (values[i] < lower || values[i] > upper) result.add(i);
  }
  return result;
}

bool detectZeroVariance(List<double> sds) => sds.any((sd) => sd == 0.0);

/// Pooled within-treatment CV% from per-treatment means, SDs, and ns.
///
/// Uses: pooledVar = Σ((nᵢ−1)·SDᵢ²) / Σ(nᵢ−1), CV = √pooledVar / |grandMean| × 100
double? computePooledCV({
  required List<double> means,
  required List<double> sds,
  required List<int> ns,
}) {
  assert(means.length == sds.length && sds.length == ns.length);
  var totalN = 0;
  var sumWeightedMean = 0.0;
  var sumWeightedVar = 0.0;
  var totalDf = 0;
  for (var i = 0; i < means.length; i++) {
    final n = ns[i];
    totalN += n;
    sumWeightedMean += n * means[i];
    final df = n - 1;
    if (df > 0) {
      sumWeightedVar += df * sds[i] * sds[i];
      totalDf += df;
    }
  }
  if (totalN < 2 || totalDf == 0) return null;
  final grandMean = sumWeightedMean / totalN;
  if (grandMean == 0) return null;
  final pooledSd = sqrt(sumWeightedVar / totalDf);
  return (pooledSd / grandMean.abs()) * 100;
}

({double q1, double median, double q3}) computeQuartiles(List<double> values) {
  if (values.isEmpty) return (q1: 0, median: 0, q3: 0);
  final sorted = List<double>.from(values)..sort();
  return (
    q1: _percentile(sorted, 25),
    median: _percentile(sorted, 50),
    q3: _percentile(sorted, 75),
  );
}

double _percentile(List<double> sorted, double p) {
  final index = (p / 100) * (sorted.length - 1);
  final lo = index.floor();
  final hi = index.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (index - lo);
}
