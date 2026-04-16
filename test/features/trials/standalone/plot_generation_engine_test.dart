import 'dart:math';

import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final r42 = Random(42);

  test('RCBD 4×4: 16 plots, each treatment once per rep', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      plotsPerRep: 4,
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
      plotsPerRep: 2,
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
      plotsPerRep: 10,
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
      plotsPerRep: 4,
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
      plotsPerRep: 4,
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
      plotsPerRep: 3,
      repCount: 2,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
    );
    expect(g.treatmentIndexPerPlot, [0, 1, 2, 0, 1, 2]);
  });

  test('Plot numbering and global sort index', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      plotsPerRep: 4,
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

  test('RCBD 4 treatments, 6 plots per rep, 4 reps: 24 data, each trt ≥ once per rep', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      plotsPerRep: 6,
      repCount: 4,
      experimentalDesign: PlotGenerationEngine.designRcbd,
      random: Random(5),
    );
    expect(g.plots.length, 24);
    expect(g.plots.every((p) => !p.isGuardRow), true);
    for (var rep = 0; rep < 4; rep++) {
      final slice = g.treatmentIndexPerPlot.sublist(rep * 6, rep * 6 + 6);
      for (var t = 0; t < 4; t++) {
        expect(slice.contains(t), true);
      }
    }
  });

  test('4 treatments, 4 plots per rep, 4 reps, 2 guard rows per end: 32 total', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 4,
      plotsPerRep: 4,
      repCount: 4,
      experimentalDesign: PlotGenerationEngine.designRcbd,
      guardRowsPerRep: 2,
      random: Random(1),
    );
    expect(g.plots.length, 32);
    expect(g.plots.where((p) => p.isGuardRow).length, 16);
    expect(
      g.treatmentIndexPerPlot
          .where((i) => i == PlotGenerationEngine.noTreatmentIndex)
          .length,
      16,
    );
    final dataIdx =
        g.treatmentIndexPerPlot.where((i) => i >= 0).toList();
    expect(dataIdx.length, 16);
    expect(
      g.plots.map((p) => p.plotId).toList(),
      [
        'G1-S1', 'G1-S2', '101', '102', '103', '104', 'G1-E1', 'G1-E2',
        'G2-S1', 'G2-S2', '201', '202', '203', '204', 'G2-E1', 'G2-E2',
        'G3-S1', 'G3-S2', '301', '302', '303', '304', 'G3-E1', 'G3-E2',
        'G4-S1', 'G4-S2', '401', '402', '403', '404', 'G4-E1', 'G4-E2',
      ],
    );
    final dataIds = g.plots.where((p) => !p.isGuardRow).map((p) => p.plotId).toSet();
    final guardIds = g.plots.where((p) => p.isGuardRow).map((p) => p.plotId).toSet();
    expect(dataIds.intersection(guardIds), isEmpty);
  });

  test('guards use G-rep-S/E; data uses rep×100+1..plotsPerRep (no id collision)', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 2,
      plotsPerRep: 6,
      repCount: 2,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
      guardRowsPerRep: 2,
    );
    expect(g.plots.length, 20);
    expect(g.plots.take(2).map((p) => p.plotId).toList(), ['G1-S1', 'G1-S2']);
    expect(
      g.plots.skip(2).take(6).map((p) => p.plotId).toList(),
      ['101', '102', '103', '104', '105', '106'],
    );
    expect(g.plots.skip(8).take(2).map((p) => p.plotId).toList(), ['G1-E1', 'G1-E2']);
    expect(g.plots.skip(10).take(2).map((p) => p.plotId).toList(), ['G2-S1', 'G2-S2']);
    expect(
      g.plots.skip(12).take(6).map((p) => p.plotId).toList(),
      ['201', '202', '203', '204', '205', '206'],
    );
    expect(g.plots.skip(18).map((p) => p.plotId).toList(), ['G2-E1', 'G2-E2']);
    final dataIds = g.plots.where((p) => !p.isGuardRow).map((p) => p.plotId).toSet();
    final guardIds = g.plots.where((p) => p.isGuardRow).map((p) => p.plotId).toSet();
    expect(dataIds.intersection(guardIds), isEmpty);
    for (final p in g.plots.where((x) => x.isGuardRow)) {
      expect(RegExp(r'^G\d+-[SE]\d+$').hasMatch(p.plotId), true);
    }
  });

  test('Guard plots have no treatment index', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 2,
      plotsPerRep: 2,
      repCount: 1,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
      guardRowsPerRep: 1,
    );
    expect(g.plots.length, 4);
    expect(g.plots.map((p) => p.plotId).toList(), ['G1-S1', '101', '102', 'G1-E1']);
    for (var i = 0; i < g.plots.length; i++) {
      if (g.plots[i].isGuardRow) {
        expect(g.treatmentIndexPerPlot[i], PlotGenerationEngine.noTreatmentIndex);
      } else {
        expect(g.treatmentIndexPerPlot[i], greaterThanOrEqualTo(0));
      }
    }
  });

  test('plotsPerRep < treatmentCount throws', () {
    expect(
      () => PlotGenerationEngine.generate(
        treatmentCount: 4,
        plotsPerRep: 3,
        repCount: 1,
        experimentalDesign: PlotGenerationEngine.designRcbd,
      ),
      throwsArgumentError,
    );
  });

  test('Non-randomized 3 treatments, 6 plots per rep: cycles', () {
    final g = PlotGenerationEngine.generate(
      treatmentCount: 3,
      plotsPerRep: 6,
      repCount: 1,
      experimentalDesign: PlotGenerationEngine.designNonRandomized,
    );
    expect(g.treatmentIndexPerPlot, [0, 1, 2, 0, 1, 2]);
  });

  group('RCBD hard constraints (H1/H2/H3)', () {
    List<List<int>> toReps(List<int> flat, int plotsPerRep) {
      final out = <List<int>>[];
      for (var i = 0; i < flat.length; i += plotsPerRep) {
        out.add(flat.sublist(i, i + plotsPerRep));
      }
      return out;
    }

    test('4 treatments × 6 reps: no canonical rep, no identical pair', () {
      final g = PlotGenerationEngine.generate(
        treatmentCount: 4,
        plotsPerRep: 4,
        repCount: 6,
        experimentalDesign: PlotGenerationEngine.designRcbd,
        random: Random(1),
      );
      final reps = toReps(g.treatmentIndexPerPlot, 4);
      final canonical = [0, 1, 2, 3];
      for (var i = 0; i < reps.length; i++) {
        expect(reps[i], isNot(equals(canonical)),
            reason: 'Rep ${i + 1} is canonical');
      }
      for (var i = 0; i < reps.length; i++) {
        for (var j = i + 1; j < reps.length; j++) {
          expect(reps[i], isNot(equals(reps[j])),
              reason: 'Rep ${i + 1} == Rep ${j + 1}');
        }
      }
    });

    test('2 treatments × 4 reps: H3 relaxes to adjacent-only', () {
      final g = PlotGenerationEngine.generate(
        treatmentCount: 2,
        plotsPerRep: 2,
        repCount: 4,
        experimentalDesign: PlotGenerationEngine.designRcbd,
        random: Random(7),
      );
      final reps = toReps(g.treatmentIndexPerPlot, 2);
      for (var i = 1; i < reps.length; i++) {
        expect(reps[i], isNot(equals(reps[i - 1])),
            reason: 'Rep ${i + 1} duplicates Rep $i (adjacent)');
      }
    });

    test('3 treatments × 10 reps: adjacent-only H3, no canonical rep', () {
      final g = PlotGenerationEngine.generate(
        treatmentCount: 3,
        plotsPerRep: 3,
        repCount: 10,
        experimentalDesign: PlotGenerationEngine.designRcbd,
        random: Random(3),
      );
      final reps = toReps(g.treatmentIndexPerPlot, 3);
      final canonical = [0, 1, 2];
      for (var i = 0; i < reps.length; i++) {
        expect(reps[i], isNot(equals(canonical)),
            reason: 'Rep ${i + 1} is canonical');
      }
      for (var i = 1; i < reps.length; i++) {
        expect(reps[i], isNot(equals(reps[i - 1])),
            reason: 'Rep ${i + 1} duplicates Rep $i (adjacent)');
      }
    });

    test('Reproducibility: same seed + inputs → identical layout', () {
      final g1 = PlotGenerationEngine.generate(
        treatmentCount: 4,
        plotsPerRep: 4,
        repCount: 6,
        experimentalDesign: PlotGenerationEngine.designRcbd,
        random: Random(42),
      );
      final g2 = PlotGenerationEngine.generate(
        treatmentCount: 4,
        plotsPerRep: 4,
        repCount: 6,
        experimentalDesign: PlotGenerationEngine.designRcbd,
        random: Random(42),
      );
      expect(g1.treatmentIndexPerPlot, equals(g2.treatmentIndexPerPlot));
    });
  });

  group('validateRcbdLayout', () {
    test('flags canonical first rep + duplicate reps (screenshot failure)',
        () {
      final reps = [
        [0, 1, 2, 3],
        [0, 1, 2, 3],
        [1, 3, 0, 2],
      ];
      final report = validateRcbdLayout(reps, 4);
      expect(report.isValid, false);
      expect(report.hardViolations.any((v) => v.contains('canonical')), true,
          reason: 'should flag canonical Rep 1');
      expect(report.hardViolations.any((v) => v.contains('identical')), true,
          reason: 'should flag Rep 1 == Rep 2');
    });

    test('valid layout passes', () {
      final reps = [
        [2, 0, 3, 1],
        [3, 1, 0, 2],
        [1, 2, 0, 3],
      ];
      final report = validateRcbdLayout(reps, 4);
      expect(report.isValid, true);
      expect(report.hardViolations, isEmpty);
    });

    test('flags unbalanced rep (H1)', () {
      final reps = [
        [0, 0, 2, 3],
        [1, 2, 0, 3],
      ];
      final report = validateRcbdLayout(reps, 4);
      expect(report.isValid, false);
      expect(report.hardViolations.any((v) => v.contains('Rep 1')), true);
    });

    test('counts S1 vertical adjacencies', () {
      final reps = [
        [0, 1, 2, 3],
        [0, 1, 2, 3],
      ];
      final report = validateRcbdLayout(reps, 4);
      expect(report.softViolations.any((v) => v.contains('4 same-treatment')),
          true);
    });
  });
}
