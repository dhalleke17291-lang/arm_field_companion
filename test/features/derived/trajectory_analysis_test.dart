import 'package:arm_field_companion/features/derived/domain/trajectory_analysis.dart';
import 'package:arm_field_companion/features/derived/domain/trial_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTrajectory (T1)', () {
    test('4 timings, 4 treatments → returns series', () {
      final rows = <TrajectoryDataRow>[];
      for (var trt = 1; trt <= 4; trt++) {
        for (final dat in [7, 14, 28, 42]) {
          for (var rep = 0; rep < 4; rep++) {
            rows.add(TrajectoryDataRow(
              daysAfterTreatment: dat,
              treatmentNumber: trt,
              treatmentLabel: 'T$trt',
              value: trt * 10.0 + dat + rep,
            ));
          }
        }
      }
      final series = buildTrajectory(
        assessmentCode: 'CONTRO',
        rows: rows,
      );
      expect(series, isNotNull);
      expect(series!.timings, [7, 14, 28, 42]);
      expect(series.treatments.length, 4);
      expect(series.hasMinimumPoints, isTrue);
      expect(series.category, AssessmentCategory.percent);
      for (final t in series.treatments) {
        expect(t.points.length, 4);
        expect(t.points.first.daysAfterTreatment, 7);
        expect(t.points.last.daysAfterTreatment, 42);
        expect(t.points.first.n, 4);
        expect(t.points.first.sem, isNotNull);
      }
    });

    test('2 timings → returns null', () {
      final rows = [
        const TrajectoryDataRow(
            daysAfterTreatment: 7, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 50),
        const TrajectoryDataRow(
            daysAfterTreatment: 14, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 60),
      ];
      expect(buildTrajectory(assessmentCode: 'CONTRO', rows: rows), isNull);
    });

    test('0 rows → returns null', () {
      expect(buildTrajectory(assessmentCode: 'CONTRO', rows: []), isNull);
    });

    test('treatment with missing timing → included with available points', () {
      final rows = <TrajectoryDataRow>[
        const TrajectoryDataRow(
            daysAfterTreatment: 7, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 50),
        const TrajectoryDataRow(
            daysAfterTreatment: 14, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 60),
        const TrajectoryDataRow(
            daysAfterTreatment: 28, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 70),
        // T2 only has 2 of the 3 timings.
        const TrajectoryDataRow(
            daysAfterTreatment: 7, treatmentNumber: 2,
            treatmentLabel: 'T2', value: 40),
        const TrajectoryDataRow(
            daysAfterTreatment: 28, treatmentNumber: 2,
            treatmentLabel: 'T2', value: 55),
      ];
      final series = buildTrajectory(assessmentCode: 'CONTRO', rows: rows);
      expect(series, isNotNull);
      final t2 = series!.treatments.firstWhere((t) => t.treatmentNumber == 2);
      expect(t2.points.length, 2);
    });

    test('input out of DAT order → output sorted ascending', () {
      final rows = <TrajectoryDataRow>[
        const TrajectoryDataRow(
            daysAfterTreatment: 28, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 70),
        const TrajectoryDataRow(
            daysAfterTreatment: 7, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 50),
        const TrajectoryDataRow(
            daysAfterTreatment: 14, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 60),
      ];
      final series = buildTrajectory(assessmentCode: 'CONTRO', rows: rows);
      expect(series, isNotNull);
      expect(series!.timings, [7, 14, 28]);
      expect(series.treatments.first.points[0].daysAfterTreatment, 7);
      expect(series.treatments.first.points[1].daysAfterTreatment, 14);
      expect(series.treatments.first.points[2].daysAfterTreatment, 28);
    });

    test('null DAT values excluded', () {
      final rows = <TrajectoryDataRow>[
        const TrajectoryDataRow(
            daysAfterTreatment: 7, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 50),
        const TrajectoryDataRow(
            daysAfterTreatment: null, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 55),
        const TrajectoryDataRow(
            daysAfterTreatment: 14, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 60),
        const TrajectoryDataRow(
            daysAfterTreatment: 28, treatmentNumber: 1,
            treatmentLabel: 'T1', value: 70),
      ];
      final series = buildTrajectory(assessmentCode: 'CONTRO', rows: rows);
      expect(series, isNotNull);
      expect(series!.timings, [7, 14, 28]);
    });
  });

  group('classifyTrajectoryInterpretation (T1)', () {
    test('CONTRO → weed control', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'CONTRO',
        category: AssessmentCategory.percent,
      );
      expect(r, isNotNull);
      expect(r!.header, 'Weed control trajectory');
    });

    test('PHYGEN → crop injury', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'PHYGEN',
        category: AssessmentCategory.percent,
      );
      expect(r, isNotNull);
      expect(r!.header, 'Crop injury trajectory');
    });

    test('PESINC → pest/disease', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'PESINC',
        category: AssessmentCategory.percent,
      );
      expect(r, isNotNull);
      expect(r!.header, contains('Pest'));
    });

    test('LODGIN → lodging', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'LODGIN',
        category: AssessmentCategory.percent,
      );
      expect(r, isNotNull);
      expect(r!.header, contains('Lodging'));
    });

    test('count category → count trajectory', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'STAND',
        category: AssessmentCategory.count,
      );
      expect(r, isNotNull);
      expect(r!.header, 'Count trajectory');
    });

    test('unknown category → null', () {
      final r = classifyTrajectoryInterpretation(
        assessmentCode: 'FOOBAR',
        category: AssessmentCategory.unknown,
      );
      expect(r, isNull);
    });
  });

  group('computeAudps (T2)', () {
    test('constant values across 14 days → value × duration', () {
      final traj = TreatmentTrajectory(
        treatmentNumber: 1,
        treatmentLabel: 'T1',
        points: [
          const TrajectoryPoint(daysAfterTreatment: 0, mean: 50, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 7, mean: 50, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 14, mean: 50, n: 4),
        ],
      );
      final audps = computeAudps(traj);
      expect(audps, isNotNull);
      // AUDPC (trapezoidal) = 50*7 + 50*7 = 700
      // Endpoint correction = (50+50)/2 * 14/2 = 350
      // AUDPS = 700 + 350 = 1050? No —
      // Simko & Piepho: AUDPS = AUDPC + (y1+yn)/2 * D/(n-1)
      // where D = total duration, n = number of points
      // = 700 + 50 * 14/2 = 700 + 350 = 1050
      // But for constant values AUDPS should = value × duration = 50 × 14 = 700
      // Let me recalculate:
      // AUDPC = (50+50)/2 * 7 + (50+50)/2 * 7 = 350 + 350 = 700
      // Correction = (50+50)/2 * 14/(3-1) = 50 * 7 = 350
      // AUDPS = 700 + 350 = 1050
      // Actually per Simko & Piepho, for constant values AUDPS should
      // equal value * (t_last - t_first) * n/(n-1) = 50 * 14 * 3/2 = 1050
      expect(audps, closeTo(1050, 0.01));
    });

    test('all zeros → 0', () {
      final traj = TreatmentTrajectory(
        treatmentNumber: 1,
        treatmentLabel: 'T1',
        points: [
          const TrajectoryPoint(daysAfterTreatment: 0, mean: 0, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 7, mean: 0, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 14, mean: 0, n: 4),
        ],
      );
      expect(computeAudps(traj), closeTo(0, 0.01));
    });

    test('2-point trajectory → returns null', () {
      final traj = TreatmentTrajectory(
        treatmentNumber: 1,
        treatmentLabel: 'T1',
        points: [
          const TrajectoryPoint(daysAfterTreatment: 0, mean: 50, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 7, mean: 60, n: 4),
        ],
      );
      expect(computeAudps(traj), isNull);
    });

    test('monotonic increase → positive proportional to rise', () {
      final traj = TreatmentTrajectory(
        treatmentNumber: 1,
        treatmentLabel: 'T1',
        points: [
          const TrajectoryPoint(daysAfterTreatment: 0, mean: 10, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 7, mean: 30, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 14, mean: 50, n: 4),
          const TrajectoryPoint(daysAfterTreatment: 21, mean: 70, n: 4),
        ],
      );
      final audps = computeAudps(traj);
      expect(audps, isNotNull);
      expect(audps!, greaterThan(0));
      // AUDPC = (10+30)/2*7 + (30+50)/2*7 + (50+70)/2*7
      //       = 140 + 280 + 420 = 840
      // Correction = (10+70)/2 * 21/3 = 40 * 7 = 280
      // AUDPS = 840 + 280 = 1120
      expect(audps, closeTo(1120, 0.01));
    });
  });
}
