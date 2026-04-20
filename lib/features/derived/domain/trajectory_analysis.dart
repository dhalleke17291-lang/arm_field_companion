import 'dart:math' as math;

import 'trial_statistics.dart';

/// A single (timing, mean value) point in a treatment's trajectory.
class TrajectoryPoint {
  final int daysAfterTreatment;
  final double mean;
  final double? sem;
  final int n;
  const TrajectoryPoint({
    required this.daysAfterTreatment,
    required this.mean,
    this.sem,
    required this.n,
  });
}

/// A single treatment's trajectory across all timings of one assessment type.
class TreatmentTrajectory {
  final int treatmentNumber;
  final String treatmentLabel;
  final List<TrajectoryPoint> points;
  const TreatmentTrajectory({
    required this.treatmentNumber,
    required this.treatmentLabel,
    required this.points,
  });
}

/// Full trajectory dataset for one assessment type across timings.
class AssessmentTrajectorySeries {
  final String assessmentCode;
  final AssessmentCategory category;
  final List<int> timings;
  final List<TreatmentTrajectory> treatments;
  const AssessmentTrajectorySeries({
    required this.assessmentCode,
    required this.category,
    required this.timings,
    required this.treatments,
  });

  bool get hasMinimumPoints => timings.length >= 3;
}

/// Trajectory interpretation hint for a specific assessment code.
class TrajectoryInterpretation {
  final String header;
  final String body;
  const TrajectoryInterpretation({
    required this.header,
    required this.body,
  });
}

/// Returns a trajectory interpretation hint based on assessment code + category.
/// Null when no specific hint applies.
// TODO(parminder): review code-prefix list before CRO handoff
TrajectoryInterpretation? classifyTrajectoryInterpretation({
  required String assessmentCode,
  required AssessmentCategory category,
}) {
  final upper = assessmentCode.trim().toUpperCase();

  if (category == AssessmentCategory.percent) {
    if (upper.startsWith('CONTRO') || upper.startsWith('WEDCON')) {
      return const TrajectoryInterpretation(
        header: 'Weed control trajectory',
        body:
            'Higher values indicate better control. Treatments that rise quickly '
            'and sustain high values are more effective; treatments whose values '
            'decline over time may indicate loss of residual activity.',
      );
    }
    if (upper.startsWith('PHYGEN') ||
        upper.startsWith('PHYCHL') ||
        upper.startsWith('PHYNEC')) {
      return const TrajectoryInterpretation(
        header: 'Crop injury trajectory',
        body:
            'Lower values indicate better crop safety. Injury that declines over '
            'time shows crop recovery; injury that persists or worsens suggests '
            'lasting damage.',
      );
    }
    if (upper.startsWith('PESINC') ||
        upper.startsWith('DISINC') ||
        upper.startsWith('DISSEV')) {
      return const TrajectoryInterpretation(
        header: 'Pest/disease pressure trajectory',
        body:
            'Values show pressure level over time. Treated plots should show lower '
            'or declining values; untreated plots commonly show rising pressure as '
            'the season progresses.',
      );
    }
    if (upper.startsWith('LODGIN')) {
      return const TrajectoryInterpretation(
        header: 'Lodging trajectory',
        body:
            'Lodging typically increases as the season progresses. Treatments that '
            'hold lodging low at late timings indicate stronger stand integrity.',
      );
    }
  }

  if (category == AssessmentCategory.count) {
    return const TrajectoryInterpretation(
      header: 'Count trajectory',
      body:
          'Values show count over time. Interpret with reference to the trial\'s '
          'specific protocol (e.g., stand counts, insect counts, weed counts).',
    );
  }

  if (category == AssessmentCategory.continuous) {
    return const TrajectoryInterpretation(
      header: 'Measurement trajectory',
      body: 'Values show the measurement over time.',
    );
  }

  return null;
}

/// Assembles a trajectory series by grouping assessments by code and ordering
/// by DAT. Returns null if fewer than 3 timings exist.
///
/// [assessmentData] is a list of (DAT, treatmentNumber, treatmentLabel, values)
/// tuples from the trial's rating data.
AssessmentTrajectorySeries? buildTrajectory({
  required String assessmentCode,
  required List<TrajectoryDataRow> rows,
}) {
  if (rows.isEmpty) return null;

  final category = classifyAssessmentCode(assessmentCode);

  // Group by DAT to find unique timings.
  final datSet = <int>{};
  for (final r in rows) {
    if (r.daysAfterTreatment != null) {
      datSet.add(r.daysAfterTreatment!);
    }
  }
  final timings = datSet.toList()..sort();
  if (timings.length < 3) return null;

  // Group by (treatment, DAT) → list of values.
  final grouped = <(int, int), List<double>>{};
  final treatmentLabels = <int, String>{};
  for (final r in rows) {
    if (r.daysAfterTreatment == null) continue;
    final key = (r.treatmentNumber, r.daysAfterTreatment!);
    grouped.putIfAbsent(key, () => []).add(r.value);
    treatmentLabels[r.treatmentNumber] = r.treatmentLabel;
  }

  // Build per-treatment trajectories.
  final treatmentNumbers = treatmentLabels.keys.toList()..sort();
  final treatments = <TreatmentTrajectory>[];

  for (final trt in treatmentNumbers) {
    final points = <TrajectoryPoint>[];
    for (final dat in timings) {
      final vals = grouped[(trt, dat)];
      if (vals == null || vals.isEmpty) continue;
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      double? sem;
      if (vals.length > 1) {
        final variance = vals
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            (vals.length - 1);
        sem = math.sqrt(variance) / math.sqrt(vals.length.toDouble());
      }
      points.add(TrajectoryPoint(
        daysAfterTreatment: dat,
        mean: mean,
        sem: sem,
        n: vals.length,
      ));
    }
    if (points.isNotEmpty) {
      treatments.add(TreatmentTrajectory(
        treatmentNumber: trt,
        treatmentLabel: treatmentLabels[trt] ?? 'T$trt',
        points: points,
      ));
    }
  }

  if (treatments.isEmpty) return null;

  return AssessmentTrajectorySeries(
    assessmentCode: assessmentCode,
    category: category,
    timings: timings,
    treatments: treatments,
  );
}

/// AUDPS (Simko & Piepho 2012): time-weighted trajectory summary.
/// Returns null if fewer than 3 points.
double? computeAudps(TreatmentTrajectory trajectory) {
  final pts = trajectory.points;
  if (pts.length < 3) return null;

  // Standard trapezoidal AUDPC.
  var audpc = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final dt = (pts[i + 1].daysAfterTreatment - pts[i].daysAfterTreatment)
        .toDouble();
    audpc += (pts[i].mean + pts[i + 1].mean) / 2 * dt;
  }

  // Simko & Piepho endpoint correction.
  final totalTime =
      (pts.last.daysAfterTreatment - pts.first.daysAfterTreatment).toDouble();
  final correction =
      (pts.first.mean + pts.last.mean) / 2 * totalTime / (pts.length - 1);

  return audpc + correction;
}

/// Input row for trajectory assembly.
class TrajectoryDataRow {
  final int? daysAfterTreatment;
  final int treatmentNumber;
  final String treatmentLabel;
  final double value;
  const TrajectoryDataRow({
    required this.daysAfterTreatment,
    required this.treatmentNumber,
    required this.treatmentLabel,
    required this.value,
  });
}
