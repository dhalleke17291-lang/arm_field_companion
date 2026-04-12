// Pure Dart statistical distribution functions.
// No external dependencies. Offline-safe.
//
// Implements regularized incomplete beta function via continued fraction
// expansion, used for F-distribution and t-distribution CDFs.

import 'dart:math' as math;

/// Lanczos approximation for ln(Gamma(x)).
double _lnGamma(double x) {
  const g = 7.0;
  const coef = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  if (x < 0.5) {
    return math.log(math.pi / math.sin(math.pi * x)) - _lnGamma(1 - x);
  }

  final xx = x - 1;
  var sum = coef[0];
  for (var i = 1; i < coef.length; i++) {
    sum += coef[i] / (xx + i);
  }
  final t = xx + g + 0.5;
  return 0.5 * math.log(2 * math.pi) +
      (xx + 0.5) * math.log(t) -
      t +
      math.log(sum);
}

/// Log of the beta function B(a, b).
double _lnBeta(double a, double b) {
  return _lnGamma(a) + _lnGamma(b) - _lnGamma(a + b);
}

/// Regularized incomplete beta function I_x(a, b).
/// Uses the continued fraction representation (DLMF 8.17.22).
double _betaIncomplete(double x, double a, double b,
    {int maxIter = 200, double eps = 1e-12}) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;

  // Use symmetry I_x(a,b) = 1 - I_{1-x}(b,a) for better convergence.
  if (x > (a + 1) / (a + b + 2)) {
    return 1 - _betaIncomplete(1 - x, b, a, maxIter: maxIter, eps: eps);
  }

  final lnPrefactor = a * math.log(x) + b * math.log(1 - x) - _lnBeta(a, b);

  // Evaluate continued fraction using modified Lentz's method.
  // The CF representation: I_x(a,b) = (x^a (1-x)^b) / (a B(a,b)) * 1/(1+ d1/(1+ d2/(1+ ...)))
  // where d_{2m} = m(b-m)x / ((a+2m-1)(a+2m))
  //       d_{2m+1} = -(a+m)(a+b+m)x / ((a+2m)(a+2m+1))

  const tiny = 1e-30;
  var f = tiny;
  var c = f;
  var d = 0.0;

  for (var i = 0; i <= maxIter; i++) {
    double numerator;
    if (i == 0) {
      numerator = 1.0; // first numerator
    } else if (i.isEven) {
      final m = i ~/ 2;
      numerator = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m));
    } else {
      final m = (i - 1) ~/ 2;
      numerator =
          -((a + m) * (a + b + m) * x) / ((a + 2 * m) * (a + 2 * m + 1));
    }

    d = 1 + numerator * d;
    if (d.abs() < tiny) d = tiny;
    d = 1 / d;

    c = 1 + numerator / c;
    if (c.abs() < tiny) c = tiny;

    f *= d * c;

    if (i > 0 && (d * c - 1).abs() < eps) break;
  }

  return math.exp(lnPrefactor) * f / a;
}

/// CDF of the F-distribution: P(F <= x | d1, d2).
double fDistributionCdf(double x, double d1, double d2) {
  if (x <= 0) return 0;
  final z = d1 * x / (d1 * x + d2);
  return _betaIncomplete(z, d1 / 2, d2 / 2);
}

/// One-tailed p-value: P(F >= observed | d1, d2).
double fDistributionPValue(double fStatistic, double d1, double d2) {
  return 1 - fDistributionCdf(fStatistic, d1, d2);
}

/// CDF of Student's t-distribution: P(T <= t | df).
double tDistributionCdf(double t, double df) {
  if (t == 0) return 0.5;
  final x = df / (df + t * t);
  final ibeta = _betaIncomplete(x, df / 2, 0.5);
  if (t > 0) {
    return 1 - 0.5 * ibeta;
  }
  return 0.5 * ibeta;
}

/// Two-tailed critical value of Student's t-distribution.
/// Finds t such that P(|T| > t | df) = alpha.
double tCriticalTwoTailed(double alpha, double df,
    {double tol = 1e-6, int maxIter = 100}) {
  final target = 1 - alpha / 2;
  var lo = 0.0;
  var hi = 50.0;
  for (var i = 0; i < maxIter; i++) {
    final mid = (lo + hi) / 2;
    final cdf = tDistributionCdf(mid, df);
    if ((cdf - target).abs() < tol) return mid;
    if (cdf < target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}
