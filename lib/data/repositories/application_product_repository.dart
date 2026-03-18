import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

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

  /// Replaces all products for the event inside a single transaction.
  Future<void> saveProductsForEvent(
    String trialApplicationEventId,
    List<({String productName, double? rate, String? rateUnit})> rows,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.trialApplicationProducts)
            ..where((t) =>
                t.trialApplicationEventId.equals(trialApplicationEventId)))
          .go();
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        await _db.into(_db.trialApplicationProducts).insert(
              TrialApplicationProductsCompanion.insert(
                trialApplicationEventId: trialApplicationEventId,
                productName: r.productName,
                rate: r.rate != null ? Value(r.rate) : const Value.absent(),
                rateUnit:
                    r.rateUnit != null ? Value(r.rateUnit) : const Value.absent(),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }
}
