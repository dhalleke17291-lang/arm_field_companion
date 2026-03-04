import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class PlotRepository {
  final AppDatabase _db;

  PlotRepository(this._db);

  Future<List<Plot>> getPlotsForTrial(int trialId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.rep),
            (p) => OrderingTerm.asc(p.plotSortIndex),
            (p) => OrderingTerm.asc(p.plotId),
          ]))
        .get();
  }

  Stream<List<Plot>> watchPlotsForTrial(int trialId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.rep),
            (p) => OrderingTerm.asc(p.plotSortIndex),
            (p) => OrderingTerm.asc(p.plotId),
          ]))
        .watch();
  }

  Future<Plot?> getPlotByPk(int plotPk) {
    return (_db.select(_db.plots)..where((p) => p.id.equals(plotPk)))
        .getSingleOrNull();
  }

  Future<Plot?> getPlotByPlotId(int trialId, String plotId) {
    return (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.plotId.equals(plotId)))
        .getSingleOrNull();
  }

  Future<int> insertPlot({
    required int trialId,
    required String plotId,
    int? plotSortIndex,
    int? rep,
    int? treatmentId,
    String? row,
    String? column,
  }) {
    return _db.into(_db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: plotId,
            plotSortIndex: Value(plotSortIndex),
            rep: Value(rep),
            treatmentId: Value(treatmentId),
            row: Value(row),
            column: Value(column),
          ),
        );
  }

  Future<void> insertPlotsBulk(List<PlotsCompanion> plots) async {
    await _db.transaction(() async {
      for (final plot in plots) {
        await _db.into(_db.plots).insert(plot);
      }
    });
  }

  Future<List<Plot>> getPlotsPage({
    required int trialId,
    required int offset,
    int limit = 50,
    int? repFilter,
    int? treatmentFilter,
  }) {
    final query = _db.select(_db.plots)
      ..where((p) {
        Expression<bool> condition = p.trialId.equals(trialId);
        if (repFilter != null) {
          condition = condition & p.rep.equals(repFilter);
        }
        if (treatmentFilter != null) {
          condition = condition & p.treatmentId.equals(treatmentFilter);
        }
        return condition;
      })
      ..orderBy([
        (p) => OrderingTerm.asc(p.rep),
        (p) => OrderingTerm.asc(p.plotSortIndex),
        (p) => OrderingTerm.asc(p.plotId),
      ])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<List<int>> getRepsForTrial(int trialId) async {
    final plots = await getPlotsForTrial(trialId);
    return plots
        .map((p) => p.rep)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }
}

class PlotNotFoundException implements Exception {
  final int plotPk;
  PlotNotFoundException(this.plotPk);

  @override
  String toString() => 'Plot with pk $plotPk not found.';
}
