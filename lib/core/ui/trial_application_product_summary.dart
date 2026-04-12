import '../database/app_database.dart';

/// One-line product summary for a trial application event, aligned with the
/// Applications tab (tank-mix rows when present, else legacy event fields).
String trialApplicationProductSummaryLine(
  TrialApplicationEvent event,
  List<TrialApplicationProduct> products,
) {
  if (products.isEmpty) {
    final name = event.productName?.trim();
    if (name == null || name.isEmpty) return '';
    final rate = event.rate;
    final unit = event.rateUnit?.trim();
    if (rate != null && unit != null && unit.isNotEmpty) {
      return '$name · $rate $unit';
    }
    if (rate != null) return '$name · $rate';
    return name;
  }
  if (products.length == 1) {
    final p = products.first;
    final rateLine = (p.rate != null && p.rateUnit != null)
        ? '${p.rate} ${p.rateUnit}'
        : (p.rate != null ? '${p.rate}' : null);
    if (rateLine != null) return '${p.productName} · $rateLine';
    return p.productName;
  }
  return '${products.first.productName} + ${products.length - 1} more';
}
