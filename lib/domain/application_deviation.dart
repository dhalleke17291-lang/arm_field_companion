import '../core/database/app_database.dart';

/// Result of checking one application product for deviation.
class ProductDeviationResult {
  const ProductDeviationResult({
    required this.productName,
    required this.plannedRate,
    required this.actualRate,
    required this.deviationPct,
    required this.exceedsTolerance,
    this.tankComputedRate,
    this.tankDeviationPct,
  });

  final String productName;
  final double? plannedRate;
  final double? actualRate;
  final double? deviationPct;
  final bool exceedsTolerance;

  /// Rate back-calculated from totalProductMixed / totalAreaSprayedHa.
  /// Null when those fields aren't populated.
  final double? tankComputedRate;
  /// Deviation of stated rate from tank-computed rate.
  final double? tankDeviationPct;
}

/// Checks all products for an application event against their planned values.
///
/// Tolerance: actual within ±[tolerancePct]% of planned is NOT flagged.
/// Default 5% per the build plan.
///
/// Also checks stated rate vs tank-computed rate when totalProductMixed
/// and totalAreaSprayedHa are available.
List<ProductDeviationResult> computeApplicationDeviations(
  TrialApplicationEvent event,
  List<TrialApplicationProduct> products, {
  double tolerancePct = 5.0,
}) {
  final results = <ProductDeviationResult>[];

  // Tank-level back-calculation (applies to all products equally).
  double? tankComputedRate;
  if (event.totalProductMixed != null &&
      event.totalAreaSprayedHa != null &&
      event.totalAreaSprayedHa! > 0) {
    tankComputedRate =
        event.totalProductMixed! / event.totalAreaSprayedHa!;
  }

  for (final p in products) {
    final planned = p.plannedRate;
    final actual = p.rate;

    double? devPct;
    bool exceeds = false;

    if (planned != null && actual != null && planned > 0) {
      devPct = ((actual - planned) / planned) * 100;
      exceeds = devPct.abs() > tolerancePct;
    }

    // Tank-vs-stated check: only meaningful when stated rate exists.
    double? tankDevPct;
    if (tankComputedRate != null && actual != null && actual > 0) {
      tankDevPct = ((actual - tankComputedRate) / actual) * 100;
    }

    results.add(ProductDeviationResult(
      productName: p.productName,
      plannedRate: planned,
      actualRate: actual,
      deviationPct: devPct,
      exceedsTolerance: exceeds,
      tankComputedRate: tankComputedRate,
      tankDeviationPct: tankDevPct,
    ));
  }

  return results;
}

/// Human-readable deviation flag for display.
String deviationLabel(double? pct) {
  if (pct == null) return '';
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(1)}%';
}
