/// Pure descriptive statistics utilities.
///
/// All functions return [double.nan] when the result is mathematically
/// undefined (empty list, zero mean for CV).
/// No DB imports, no Riverpod, no domain-specific types.
library;

import 'dart:math' as math;

/// Arithmetic mean of [values]. Returns [double.nan] for an empty list.
double mean(List<double> values) {
  if (values.isEmpty) return double.nan;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Population variance of [values]. Returns [double.nan] for an empty list.
double variance(List<double> values) {
  if (values.isEmpty) return double.nan;
  final m = mean(values);
  return values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
      values.length;
}

/// Population standard deviation of [values].
/// Returns [double.nan] for an empty list.
double stdDev(List<double> values) {
  if (values.isEmpty) return double.nan;
  return math.sqrt(variance(values));
}

/// Coefficient of variation as a percentage (stdDev / mean × 100).
/// Returns [double.nan] for an empty list or when [mean] is zero.
double coefficientOfVariation(List<double> values) {
  if (values.isEmpty) return double.nan;
  final m = mean(values);
  if (m == 0.0) return double.nan;
  return (stdDev(values) / m) * 100.0;
}
