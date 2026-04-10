import 'dart:math';

/// Plot row for standalone layout (before DB insert).
class PlotLayoutRow {
  const PlotLayoutRow({
    required this.plotId,
    required this.rep,
    required this.plotSortIndex,
  });

  final String plotId;
  final int rep;
  final int plotSortIndex;
}

/// Output of [PlotGenerationEngine.generate]: plots and parallel treatment indices.
class PlotGenerationResult {
  const PlotGenerationResult({
    required this.plots,
    required this.treatmentIndexPerPlot,
  });

  final List<PlotLayoutRow> plots;
  /// Same length as [plots]; each value is an index into the treatment list (0-based).
  final List<int> treatmentIndexPerPlot;
}

/// Pure plot layout + assignment planning for standalone trials.
class PlotGenerationEngine {
  PlotGenerationEngine._();

  static const String designRcbd = 'RCBD';
  static const String designCrd = 'CRD';
  static const String designNonRandomized = 'Non-randomized';

  /// [treatmentCount] must be >= 2; [repCount] >= 1.
  /// [random] defaults to [Random]; pass a seeded instance in tests.
  static PlotGenerationResult generate({
    required int treatmentCount,
    required int repCount,
    required String experimentalDesign,
    Random? random,
  }) {
    if (treatmentCount < 2) {
      throw ArgumentError.value(treatmentCount, 'treatmentCount', 'must be >= 2');
    }
    if (repCount < 1) {
      throw ArgumentError.value(repCount, 'repCount', 'must be >= 1');
    }
    final rng = random ?? Random();
    final plots = _buildPlots(treatmentCount: treatmentCount, repCount: repCount);
    final indices = _treatmentIndices(
      treatmentCount: treatmentCount,
      repCount: repCount,
      experimentalDesign: experimentalDesign,
      random: rng,
    );
    assert(plots.length == indices.length);
    return PlotGenerationResult(plots: plots, treatmentIndexPerPlot: indices);
  }

  static List<PlotLayoutRow> _buildPlots({
    required int treatmentCount,
    required int repCount,
  }) {
    final out = <PlotLayoutRow>[];
    var sort = 1;
    for (var rep = 1; rep <= repCount; rep++) {
      for (var pos = 1; pos <= treatmentCount; pos++) {
        final plotNum = rep * 100 + pos;
        out.add(PlotLayoutRow(
          plotId: '$plotNum',
          rep: rep,
          plotSortIndex: sort,
        ));
        sort++;
      }
    }
    return out;
  }

  static List<int> _treatmentIndices({
    required int treatmentCount,
    required int repCount,
    required String experimentalDesign,
    required Random random,
  }) {
    switch (experimentalDesign) {
      case designRcbd:
        final out = <int>[];
        for (var r = 0; r < repCount; r++) {
          final perm = List<int>.generate(treatmentCount, (i) => i)..shuffle(random);
          out.addAll(perm);
        }
        return out;
      case designCrd:
        final pool = <int>[];
        for (var r = 0; r < repCount; r++) {
          for (var t = 0; t < treatmentCount; t++) {
            pool.add(t);
          }
        }
        pool.shuffle(random);
        return pool;
      case designNonRandomized:
        final out = <int>[];
        for (var r = 0; r < repCount; r++) {
          for (var t = 0; t < treatmentCount; t++) {
            out.add(t);
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
}
