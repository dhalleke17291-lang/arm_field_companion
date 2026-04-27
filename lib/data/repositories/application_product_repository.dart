import 'package:drift/drift.dart';

import '../../core/application_state.dart';
import '../../core/database/app_database.dart';

/// One row to persist for an application event's tank-mix / product list.
///
/// [plannedProduct], [plannedRate], [plannedRateUnit] mirror the treatment
/// protocol (from [TreatmentComponent]) when the application is tied to a
/// treatment; [rate] / [rateUnit] are the as-applied values recorded for this
/// event.
class ApplicationProductSaveRow {
  const ApplicationProductSaveRow({
    required this.productName,
    this.rate,
    this.rateUnit,
    this.lotCode,
    this.plannedProduct,
    this.plannedRate,
    this.plannedRateUnit,
  });

  final String productName;
  final double? rate;
  final String? rateUnit;
  final String? lotCode;
  final String? plannedProduct;
  final double? plannedRate;
  final String? plannedRateUnit;
}

class ApplicationProductRepository {
  ApplicationProductRepository(this._db);

  final AppDatabase _db;

  Future<List<TrialApplicationProduct>> getProductsForEvent(
      String trialApplicationEventId) {
    return (_db.select(_db.trialApplicationProducts)
          ..where((p) =>
              p.trialApplicationEventId.equals(trialApplicationEventId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  Stream<List<TrialApplicationProduct>> watchProductsForEvent(
      String trialApplicationEventId) {
    return (_db.select(_db.trialApplicationProducts)
          ..where((p) =>
              p.trialApplicationEventId.equals(trialApplicationEventId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  /// Tolerance for rate deviation flagging (matches [computeApplicationDeviations]).
  static const double _deviationTolerancePct = 5.0;

  /// Computes whether actual rate deviates from planned by more than tolerance.
  static bool _computeDeviationFlag(double? actual, double? planned) {
    if (planned == null || actual == null || planned <= 0) return false;
    final devPct = ((actual - planned) / planned) * 100;
    return devPct.abs() > _deviationTolerancePct;
  }

  /// Replaces all products for the event inside a single transaction.
  /// Computes and persists [deviationFlag] per product row.
  Future<void> saveProductsForEvent(
    String trialApplicationEventId,
    List<ApplicationProductSaveRow> rows,
  ) async {
    // Block product updates when the parent application is confirmed.
    final parent = await (_db.select(_db.trialApplicationEvents)
          ..where((e) => e.id.equals(trialApplicationEventId)))
        .getSingleOrNull();
    if (parent != null &&
        (parent.appliedAt != null ||
            parent.status == kAppStatusApplied ||
            parent.status == 'complete')) {
      return;
    }
    await _db.transaction(() async {
      await (_db.delete(_db.trialApplicationProducts)
            ..where((t) =>
                t.trialApplicationEventId.equals(trialApplicationEventId)))
          .go();
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final flag = _computeDeviationFlag(r.rate, r.plannedRate);
        await _db.into(_db.trialApplicationProducts).insert(
              TrialApplicationProductsCompanion.insert(
                trialApplicationEventId: trialApplicationEventId,
                productName: r.productName,
                rate: r.rate != null ? Value(r.rate) : const Value.absent(),
                rateUnit:
                    r.rateUnit != null ? Value(r.rateUnit) : const Value.absent(),
                lotCode: r.lotCode != null
                    ? Value(r.lotCode)
                    : const Value.absent(),
                sortOrder: Value(i),
                plannedProduct: r.plannedProduct != null
                    ? Value(r.plannedProduct)
                    : const Value.absent(),
                plannedRate: r.plannedRate != null
                    ? Value(r.plannedRate)
                    : const Value.absent(),
                plannedRateUnit: r.plannedRateUnit != null
                    ? Value(r.plannedRateUnit)
                    : const Value.absent(),
                deviationFlag: Value(flag),
              ),
            );
      }
    });
  }
}
