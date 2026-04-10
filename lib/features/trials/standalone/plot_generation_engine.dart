import 'dart:math';

/// Plot row for standalone layout (before DB insert).
class PlotLayoutRow {
  const PlotLayoutRow({
    required this.plotId,
    required this.rep,
    required this.plotSortIndex,
    this.isGuardRow = false,
  });

  final String plotId;
  final int rep;
  final int plotSortIndex;
  final bool isGuardRow;
}

/// Output of [PlotGenerationEngine.generate]: plots and parallel treatment indices.
class PlotGenerationResult {
  const PlotGenerationResult({
    required this.plots,
    required this.treatmentIndexPerPlot,
  });

  final List<PlotLayoutRow> plots;
  /// Same length as [plots]. [PlotGenerationEngine.noTreatmentIndex] for guard plots.
  final List<int> treatmentIndexPerPlot;
}

/// Pure plot layout + assignment planning for standalone trials.
class PlotGenerationEngine {
  PlotGenerationEngine._();

  /// Sentinel: no treatment assignment (guard plot).
  static const int noTreatmentIndex = -1;

  static const String designRcbd = 'RCBD';
  static const String designCrd = 'CRD';
  static const String designNonRandomized = 'Non-randomized';

  /// [treatmentCount] must be >= 2; [plotsPerRep] >= [treatmentCount]; [repCount] >= 1.
  /// [guardRowsPerRep] guards at start and end of each rep (each side gets this many).
  static PlotGenerationResult generate({
    required int treatmentCount,
    required int plotsPerRep,
    required int repCount,
    required String experimentalDesign,
    int guardRowsPerRep = 0,
    Random? random,
  }) {
    if (treatmentCount < 2) {
      throw ArgumentError.value(treatmentCount, 'treatmentCount', 'must be >= 2');
    }
    if (plotsPerRep < treatmentCount) {
      throw ArgumentError.value(
        plotsPerRep,
        'plotsPerRep',
        'must be >= treatmentCount ($treatmentCount)',
      );
    }
    if (repCount < 1) {
      throw ArgumentError.value(repCount, 'repCount', 'must be >= 1');
    }
    if (guardRowsPerRep < 0) {
      throw ArgumentError.value(guardRowsPerRep, 'guardRowsPerRep', 'must be >= 0');
    }

    final rng = random ?? Random();

    final flatDataPattern = _dataPatternForDesign(
      experimentalDesign: experimentalDesign,
      treatmentCount: treatmentCount,
      plotsPerRep: plotsPerRep,
      repCount: repCount,
      random: rng,
    );

    final plots = <PlotLayoutRow>[];
    final treatmentIndexPerPlot = <int>[];
    var sort = 1;
    var flatDataIdx = 0;

    for (var r = 1; r <= repCount; r++) {
      var localPos = 1;
      for (var g = 0; g < guardRowsPerRep; g++) {
        plots.add(PlotLayoutRow(
          plotId: '${r * 100 + localPos}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: true,
        ));
        treatmentIndexPerPlot.add(noTreatmentIndex);
        sort++;
        localPos++;
      }
      for (var p = 0; p < plotsPerRep; p++) {
        plots.add(PlotLayoutRow(
          plotId: '${r * 100 + localPos}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: false,
        ));
        treatmentIndexPerPlot.add(flatDataPattern[flatDataIdx]);
        flatDataIdx++;
        sort++;
        localPos++;
      }
      for (var g = 0; g < guardRowsPerRep; g++) {
        plots.add(PlotLayoutRow(
          plotId: '${r * 100 + localPos}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: true,
        ));
        treatmentIndexPerPlot.add(noTreatmentIndex);
        sort++;
        localPos++;
      }
    }

    assert(plots.length == treatmentIndexPerPlot.length);
    return PlotGenerationResult(plots: plots, treatmentIndexPerPlot: treatmentIndexPerPlot);
  }

  static List<int> _dataPatternForDesign({
    required String experimentalDesign,
    required int treatmentCount,
    required int plotsPerRep,
    required int repCount,
    required Random random,
  }) {
    switch (experimentalDesign) {
      case designRcbd:
        final out = <int>[];
        for (var r = 0; r < repCount; r++) {
          final row = List<int>.generate(plotsPerRep, (i) => i % treatmentCount);
          row.shuffle(random);
          out.addAll(row);
        }
        return out;
      case designCrd:
        final total = plotsPerRep * repCount;
        return _crdPool(treatmentCount, total, random);
      case designNonRandomized:
        final out = <int>[];
        for (var r = 0; r < repCount; r++) {
          for (var p = 0; p < plotsPerRep; p++) {
            out.add(p % treatmentCount);
          }
        }
        return out;
      default:
        throw ArgumentError.value(
          experimentalDesign,
          'experimentalDesign',
          'use $designRcbd, $designCrd, or $designNonRandomized',
        );
    }
  }

  static List<int> _crdPool(int treatmentCount, int totalSlots, Random random) {
    final base = totalSlots ~/ treatmentCount;
    final rem = totalSlots % treatmentCount;
    final pool = <int>[];
    for (var t = 0; t < treatmentCount; t++) {
      for (var i = 0; i < base; i++) {
        pool.add(t);
      }
    }
    for (var t = 0; t < rem; t++) {
      pool.add(t);
    }
    pool.shuffle(random);
    return pool;
  }
}
