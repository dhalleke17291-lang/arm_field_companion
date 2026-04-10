import 'dart:math';

import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final r42 = Random(42);

  test('RCBD 4×4: 16 plots, each treatment once per rep', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      repCount: 4,
      experimentalDesign: PlotGenerationEngine.designRcbd,
      random: r42,
    );
    expect(g.plots.length, 16);
    expect(g.treatmentIndexPerPlot.length, 16);
    for (var rep = 0; rep < 4; rep++) {
      final slice = g.treatmentIndexPerPlot.sublist(rep * 4, rep * 4 + 4);
      expect(slice.toSet().length, 4);
      for (var t = 0; t < 4; t++) {
        expect(slice.contains(t), true);
      }
    }
  });

  test('RCBD 2×1: 2 plots', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 2,
      repCount: 1,
      experimentalDesign: PlotGenerationEngine.designRcbd,
      random: Random(1),
    );
    expect(g.plots.length, 2);
    expect(g.treatmentIndexPerPlot.toSet(), {0, 1});
  });

  test('RCBD 10×3: 30 plots', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 10,
      repCount: 3,
      experimentalDesign: PlotGenerationEngine.designRcbd,
      random: Random(0),
    );
    expect(g.plots.length, 30);
    for (var rep = 0; rep < 3; rep++) {
      final slice = g.treatmentIndexPerPlot.sublist(rep * 10, rep * 10 + 10);
      expect(slice.toSet().length, 10);
    }
  });

  test('CRD 4×4: each treatment exactly 4 times', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      repCount: 4,
      experimentalDesign: PlotGenerationEngine.designCrd,
      random: Random(99),
    );
    expect(g.plots.length, 16);
    final counts = List<int>.filled(4, 0);
    for (final i in g.treatmentIndexPerPlot) {
      counts[i]++;
    }
    expect(counts, [4, 4, 4, 4]);
  });

  test('Non-randomized 4×4: identical order each rep', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      repCount: 4,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
    );
    const expected = [0, 1, 2, 3];
    for (var rep = 0; rep < 4; rep++) {
      expect(
        g.treatmentIndexPerPlot.sublist(rep * 4, rep * 4 + 4),
        expected,
      );
    }
  });

  test('Non-randomized 3×2: T1,T2,T3 both reps', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 3,
      repCount: 2,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
    );
    expect(g.treatmentIndexPerPlot, [0, 1, 2, 0, 1, 2]);
  });

  test('Plot numbering and global sort index', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      repCount: 3,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
    );
    expect(g.plots.map((p) => p.plotId).toList(), [
      '101',
      '102',
      '103',
      '104',
      '201',
      '202',
      '203',
      '204',
      '301',
      '302',
      '303',
      '304',
    ]);
    for (var i = 0; i < g.plots.length; i++) {
      expect(g.plots[i].plotSortIndex, i + 1);
      final rep = i ~/ 4 + 1;
      expect(g.plots[i].rep, rep);
    }
  });
}
