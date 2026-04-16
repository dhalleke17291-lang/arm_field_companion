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
      for (var g = 0; g < guardRowsPerRep; g++) {
        plots.add(PlotLayoutRow(
          plotId: 'G$r-S${g + 1}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: true,
        ));
        treatmentIndexPerPlot.add(noTreatmentIndex);
        sort++;
      }
      for (var p = 0; p < plotsPerRep; p++) {
        plots.add(PlotLayoutRow(
          plotId: '${r * 100 + p + 1}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: false,
        ));
        treatmentIndexPerPlot.add(flatDataPattern[flatDataIdx]);
        flatDataIdx++;
        sort++;
      }
      for (var g = 0; g < guardRowsPerRep; g++) {
        plots.add(PlotLayoutRow(
          plotId: 'G$r-E${g + 1}',
          rep: r,
          plotSortIndex: sort,
          isGuardRow: true,
        ));
        treatmentIndexPerPlot.add(noTreatmentIndex);
        sort++;
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
        return _rcbdDataPattern(
          treatmentCount: treatmentCount,
          plotsPerRep: plotsPerRep,
          repCount: repCount,
          random: random,
        );
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

  /// Max retries when hard constraints reject a candidate layout.
  static const int _kRcbdMaxAttempts = 500;

  /// RCBD data pattern with hard-constraint enforcement (H1/H2/H3) and
  /// soft-score minimization (S1 vertical-adjacency count).
  ///
  /// H1: Each rep is a balanced multiset — each treatment appears
  ///     exactly `plotsPerRep / treatmentCount` times. Guaranteed by
  ///     construction (duplicate-rep-then-shuffle).
  /// H2: When `treatmentCount >= 3` and `plotsPerRep == treatmentCount`,
  ///     no rep equals the canonical input order `[0, 1, ..., t-1]`.
  /// H3: No two reps share identical sequences when feasible
  ///     (`repCount <= distinct permutations`); else relax to forbidding
  ///     only adjacent-rep duplicates.
  /// S1: Soft — vertical same-treatment adjacencies between adjacent reps.
  ///     Score is the total adjacency count; 0 is the target. Best
  ///     hard-passing candidate over [_kRcbdMaxAttempts] is returned.
  static List<int> _rcbdDataPattern({
    required int treatmentCount,
    required int plotsPerRep,
    required int repCount,
    required Random random,
  }) {
    final enforceNonCanonical =
        treatmentCount >= 3 && plotsPerRep == treatmentCount;
    final distinctPerms = _distinctRcbdPerms(plotsPerRep, treatmentCount);
    final enforceAllPairsUnique = repCount <= distinctPerms;

    List<List<int>>? bestHardPassing;
    int bestScore = 1 << 30;
    List<List<int>>? lastResort;

    for (var attempt = 0; attempt < _kRcbdMaxAttempts; attempt++) {
      final reps = <List<int>>[];
      for (var r = 0; r < repCount; r++) {
        final row =
            List<int>.generate(plotsPerRep, (i) => i % treatmentCount);
        row.shuffle(random);
        reps.add(row);
      }

      if (!_passesHardRcbdConstraints(
        reps,
        treatmentCount: treatmentCount,
        enforceNonCanonical: enforceNonCanonical,
        enforceAllPairsUnique: enforceAllPairsUnique,
      )) {
        lastResort ??= reps;
        continue;
      }

      final score = _rcbdAdjacencyScore(reps);
      if (score == 0) {
        return reps.expand((r) => r).toList();
      }
      if (score < bestScore) {
        bestScore = score;
        bestHardPassing = reps;
      }
    }

    // Fallback order: best hard-passing candidate > any hard-failing
    // candidate (still H1-balanced, flag via validator).
    final chosen = bestHardPassing ??
        lastResort ??
        [
          for (var r = 0; r < repCount; r++)
            List<int>.generate(plotsPerRep, (i) => i % treatmentCount)
        ];
    return chosen.expand((r) => r).toList();
  }

  /// S1: count of vertical same-treatment adjacencies across all adjacent
  /// rep pairs.
  static int _rcbdAdjacencyScore(List<List<int>> reps) {
    var total = 0;
    for (var r = 1; r < reps.length; r++) {
      final a = reps[r - 1];
      final b = reps[r];
      final len = a.length < b.length ? a.length : b.length;
      for (var c = 0; c < len; c++) {
        if (a[c] == b[c]) total++;
      }
    }
    return total;
  }

  /// Exact count of distinct orderings of `[0, 1, ..., t-1]` repeated
  /// `plotsPerRep / t` times (multinomial). Capped at a large sentinel
  /// to avoid overflow; only used to decide if H3 is feasible.
  static int _distinctRcbdPerms(int plotsPerRep, int treatmentCount) {
    final dup = plotsPerRep ~/ treatmentCount;
    // Compute plotsPerRep! / (dup!)^treatmentCount
    int num = 1;
    for (var k = 2; k <= plotsPerRep; k++) {
      num *= k;
      if (num > 1 << 40) return 1 << 40; // cap: H3 will be considered feasible
    }
    int dupFact = 1;
    for (var k = 2; k <= dup; k++) {
      dupFact *= k;
    }
    int denom = 1;
    for (var t = 0; t < treatmentCount; t++) {
      denom *= dupFact;
    }
    return num ~/ denom;
  }

  static bool _passesHardRcbdConstraints(
    List<List<int>> reps, {
    required int treatmentCount,
    required bool enforceNonCanonical,
    required bool enforceAllPairsUnique,
  }) {
    if (enforceNonCanonical) {
      final canonical =
          List<int>.generate(reps.first.length, (i) => i % treatmentCount);
      for (final r in reps) {
        if (_seqEquals(r, canonical)) return false;
      }
    }
    if (enforceAllPairsUnique) {
      for (var i = 0; i < reps.length; i++) {
        for (var j = i + 1; j < reps.length; j++) {
          if (_seqEquals(reps[i], reps[j])) return false;
        }
      }
    } else {
      // Relaxed: forbid adjacent-rep duplicates only.
      for (var i = 1; i < reps.length; i++) {
        if (_seqEquals(reps[i - 1], reps[i])) return false;
      }
    }
    return true;
  }

  static bool _seqEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Result of validating an RCBD layout.
class RcbdValidationReport {
  const RcbdValidationReport({
    required this.isValid,
    required this.hardViolations,
    required this.softViolations,
  });

  /// True when no hard constraints are violated.
  final bool isValid;

  /// Human-readable hard constraint violations (H1/H2/H3).
  final List<String> hardViolations;

  /// Human-readable soft constraint observations (S1 adjacency stripes).
  final List<String> softViolations;
}

/// Validates an RCBD layout shape-by-shape. Can be used on:
/// - Newly generated layouts (sanity check)
/// - Imported ARM / CSV layouts
/// - Future: manual-edit review
///
/// [reps] is indexed `[rep][column] = treatmentIndex` (0-based treatment index).
/// [treatmentCount] is the number of distinct treatments expected.
RcbdValidationReport validateRcbdLayout(
  List<List<int>> reps,
  int treatmentCount,
) {
  final hard = <String>[];
  final soft = <String>[];

  if (reps.isEmpty) {
    return const RcbdValidationReport(
      isValid: false,
      hardViolations: ['Layout is empty'],
      softViolations: [],
    );
  }

  final plotsPerRep = reps.first.length;

  // H1: each rep has each treatment exactly plotsPerRep/treatmentCount times.
  final expectedPerTrt = plotsPerRep ~/ treatmentCount;
  for (var r = 0; r < reps.length; r++) {
    if (reps[r].length != plotsPerRep) {
      hard.add('Rep ${r + 1} has ${reps[r].length} plots; expected $plotsPerRep');
      continue;
    }
    final counts = List<int>.filled(treatmentCount, 0);
    for (final t in reps[r]) {
      if (t < 0 || t >= treatmentCount) {
        hard.add('Rep ${r + 1} has invalid treatment index $t');
        continue;
      }
      counts[t]++;
    }
    for (var t = 0; t < treatmentCount; t++) {
      if (counts[t] != expectedPerTrt) {
        hard.add(
          'Rep ${r + 1} has ${counts[t]} of treatment ${t + 1}; expected $expectedPerTrt',
        );
      }
    }
  }

  // H2: no rep equals canonical order (when treatmentCount >= 3 and plotsPerRep == treatmentCount).
  if (treatmentCount >= 3 && plotsPerRep == treatmentCount) {
    final canonical =
        List<int>.generate(plotsPerRep, (i) => i % treatmentCount);
    for (var r = 0; r < reps.length; r++) {
      if (_validatorSeqEquals(reps[r], canonical)) {
        hard.add('Rep ${r + 1} is in canonical order');
      }
    }
  }

  // H3: no two reps identical.
  for (var i = 0; i < reps.length; i++) {
    for (var j = i + 1; j < reps.length; j++) {
      if (reps[i].length == reps[j].length &&
          _validatorSeqEquals(reps[i], reps[j])) {
        hard.add('Rep ${i + 1} and Rep ${j + 1} are identical');
      }
    }
  }

  // S1: vertical same-treatment adjacencies between reps i and i+1.
  for (var r = 1; r < reps.length; r++) {
    if (reps[r].length != reps[r - 1].length) continue;
    var adj = 0;
    for (var c = 0; c < reps[r].length; c++) {
      if (reps[r][c] == reps[r - 1][c]) adj++;
    }
    if (adj > 0) {
      soft.add(
        '$adj same-treatment vertical adjacencies between Rep $r and Rep ${r + 1}',
      );
    }
  }

  return RcbdValidationReport(
    isValid: hard.isEmpty,
    hardViolations: hard,
    softViolations: soft,
  );
}

bool _validatorSeqEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
