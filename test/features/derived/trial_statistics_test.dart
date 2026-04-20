import 'package:flutter_test/flutter_test.dart';
import 'package:arm_field_companion/core/assessment_result_direction.dart';
import 'package:arm_field_companion/features/derived/domain/trial_statistics.dart';
import 'package:arm_field_companion/features/export/standalone_report_data.dart';

const String _kAssessment = 'Weed Control';
const String _kOtherAssessment = 'Crop Injury';

RatingResultRow _row({
  required String plotId,
  required int rep,
  required String treatmentCode,
  required String assessmentName,
  required String value,
  String resultStatus = 'RECORDED',
  String resultDirection = 'neutral',
  String unit = '%',
}) =>
    RatingResultRow(
      plotId: plotId,
      rep: rep,
      treatmentCode: treatmentCode,
      assessmentName: assessmentName,
      value: value,
      resultStatus: resultStatus,
      resultDirection: resultDirection,
      unit: unit,
    );

TreatmentMean _tm(String treatmentCode, double mean) => TreatmentMean(
      treatmentCode: treatmentCode,
      mean: mean,
      standardDeviation: 0,
      standardError: 0,
      n: 1,
      min: mean,
      max: mean,
      isPreliminary: false,
    );

void main() {
  group('computeCompleteness', () {
    test('returns noData when totalPlots is 0', () {
      expect(
        computeCompleteness([], _kAssessment, 0),
        AssessmentCompleteness.noData,
      );
      expect(
        computeCompleteness(
          [
            _row(
              plotId: '1',
              rep: 1,
              treatmentCode: 'T',
              assessmentName: _kAssessment,
              value: '1',
            ),
          ],
          _kAssessment,
          0,
        ),
        AssessmentCompleteness.noData,
      );
    });

    test('returns noData when no rows match assessmentName', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kOtherAssessment,
          value: '10',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.noData,
      );
    });

    test('returns noData when all rows are VOID', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
          resultStatus: 'VOID',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
          resultStatus: 'VOID',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
          resultStatus: 'VOID',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
          resultStatus: 'VOID',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.noData,
      );
    });

    test('returns inProgress when some plots rated', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.inProgress,
      );
    });

    test('returns complete when all plots rated', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.complete,
      );
    });

    test('returns complete when rated >= totalPlots', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
        ),
        _row(
          plotId: '501',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '50',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.complete,
      );
    });

    test('non-numeric values are excluded from rated count', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: 'N/A',
        ),
        _row(
          plotId: '102',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: 'N/A',
        ),
        _row(
          plotId: '103',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '104',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.inProgress,
      );
    });

    test('duplicate plotIds are counted only once for completeness', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '101',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '11',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.complete,
      );
    });

    test('non-RECORDED resultStatus rows are ignored for completeness', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
          resultStatus: 'AMENDED',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
          resultStatus: 'AMENDED',
        ),
      ];
      expect(
        computeCompleteness(rows, _kAssessment, 4),
        AssessmentCompleteness.inProgress,
      );
    });
  });

  group('computeMissingReps', () {
    test('returns empty when all reps present', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
      ];
      expect(
        computeMissingReps(rows, _kAssessment, {1, 2, 3, 4}),
        isEmpty,
      );
    });

    test('returns missing rep numbers sorted', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
      ];
      expect(
        computeMissingReps(rows, _kAssessment, {1, 2, 3, 4}),
        [3],
      );
    });

    test('returns multiple missing reps sorted', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
      ];
      expect(
        computeMissingReps(rows, _kAssessment, {1, 2, 3, 4}),
        [2, 3, 4],
      );
    });

    test('VOID rows do not count as rated', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '1',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '99',
          resultStatus: 'VOID',
        ),
      ];
      expect(
        computeMissingReps(rows, _kAssessment, {1, 2}),
        [2],
      );
    });

    test('returns all reps when no data', () {
      expect(
        computeMissingReps([], _kAssessment, {1, 2, 3, 4}),
        [1, 2, 3, 4],
      );
    });
  });

  group('computeTreatmentMeans', () {
    test('returns empty for no valid data', () {
      expect(
        computeTreatmentMeans([], _kAssessment, false),
        isEmpty,
      );
    });

    test('computes mean correctly for single treatment', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '95',
        ),
      ];
      final means = computeTreatmentMeans(rows, _kAssessment, false);
      expect(means, hasLength(1));
      expect(means.single.mean, closeTo(87.5, 0.0001));
    });

    test('computes SD correctly using sample variance n-1', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '95',
        ),
      ];
      final means = computeTreatmentMeans(rows, _kAssessment, false);
      expect(means.single.standardDeviation, closeTo(6.455, 0.01));
    });

    test('computes SE correctly', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '95',
        ),
      ];
      final means = computeTreatmentMeans(rows, _kAssessment, false);
      expect(means.single.standardError, closeTo(3.227, 0.01));
    });

    test('n, min, max are correct', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '95',
        ),
      ];
      final m = computeTreatmentMeans(rows, _kAssessment, false).single;
      expect(m.n, 4);
      expect(m.min, 80.0);
      expect(m.max, 95.0);
    });

    test('isPreliminary flag is set on all TreatmentMean entries', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
      ];
      final preliminaryTrue =
          computeTreatmentMeans(rows, _kAssessment, true);
      expect(preliminaryTrue.every((e) => e.isPreliminary), isTrue);
      final preliminaryFalse =
          computeTreatmentMeans(rows, _kAssessment, false);
      expect(preliminaryFalse.every((e) => e.isPreliminary), isFalse);
    });

    test('VOID rows excluded from means', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '95',
          resultStatus: 'VOID',
        ),
      ];
      final m = computeTreatmentMeans(rows, _kAssessment, false).single;
      expect(m.n, 3);
      expect(m.mean, closeTo(85.0, 0.0001));
    });

    test('non-numeric values are excluded', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '85',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '4',
          rep: 4,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: 'missing',
        ),
      ];
      expect(computeTreatmentMeans(rows, _kAssessment, false).single.n, 3);
    });

    test('multiple treatments computed independently', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '80',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '90',
        ),
        _row(
          plotId: '3',
          rep: 1,
          treatmentCode: 'TRT_B',
          assessmentName: _kAssessment,
          value: '60',
        ),
        _row(
          plotId: '4',
          rep: 2,
          treatmentCode: 'TRT_B',
          assessmentName: _kAssessment,
          value: '70',
        ),
      ];
      final means = computeTreatmentMeans(rows, _kAssessment, false);
      expect(means, hasLength(2));
      final a = means.firstWhere((e) => e.treatmentCode == 'TRT_A');
      final b = means.firstWhere((e) => e.treatmentCode == 'TRT_B');
      expect(a.mean, 85.0);
      expect(b.mean, 65.0);
    });

    test('only rows matching assessmentName are included', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '100',
        ),
        _row(
          plotId: '2',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kOtherAssessment,
          value: '50',
        ),
      ];
      final means = computeTreatmentMeans(rows, _kAssessment, false);
      expect(means, hasLength(1));
      expect(means.single.mean, 100.0);
    });

    test('negative and zero numeric values are handled correctly', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '-5',
        ),
        _row(
          plotId: '2',
          rep: 2,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '0',
        ),
        _row(
          plotId: '3',
          rep: 3,
          treatmentCode: 'TRT_A',
          assessmentName: _kAssessment,
          value: '5',
        ),
      ];
      final m = computeTreatmentMeans(rows, _kAssessment, false).single;
      expect(m.mean, closeTo(0.0, 0.001));
      expect(m.min, closeTo(-5.0, 0.001));
      expect(m.max, closeTo(5.0, 0.001));
      expect(m.n, 3);
    });
  });

  group('computeProgress', () {
    test('hasAnyData is false when there is no rated data', () {
      final progress = computeProgress(
        [],
        _kAssessment,
        1,
        4,
        {1},
      );
      expect(progress.hasAnyData, isFalse);
      expect(progress.ratedPlots, 0);
    });

    test('hasAnyData is true when some data exists', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
      ];
      final progress = computeProgress(
        rows,
        _kAssessment,
        1,
        4,
        {1},
      );
      expect(progress.hasAnyData, isTrue);
    });

    test('isPreliminary is true when completeness is inProgress', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
      ];
      final progress = computeProgress(
        rows,
        _kAssessment,
        1,
        4,
        {1, 2, 3, 4},
      );
      expect(progress.completeness, AssessmentCompleteness.inProgress);
      expect(progress.isPreliminary, isTrue);
    });

    test('isPreliminary is false when completeness is complete', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
        ),
      ];
      final progress = computeProgress(
        rows,
        _kAssessment,
        1,
        4,
        {1, 2, 3, 4},
      );
      expect(progress.completeness, AssessmentCompleteness.complete);
      expect(progress.isPreliminary, isFalse);
    });

    test('assessmentId and assessmentName are set from parameters', () {
      final progress = computeProgress(
        [],
        _kAssessment,
        42,
        4,
        {1},
      );
      expect(progress.assessmentId, 42);
      expect(progress.assessmentName, _kAssessment);
    });

    test('totalPlots matches parameter', () {
      final progress = computeProgress(
        [],
        _kAssessment,
        1,
        16,
        {1},
      );
      expect(progress.totalPlots, 16);
    });
  });

  group('classifyAssessmentCode', () {
    test('CONTRO → percent', () {
      expect(classifyAssessmentCode('CONTRO'), AssessmentCategory.percent);
    });
    test('YIELD → continuous', () {
      expect(classifyAssessmentCode('YIELD'), AssessmentCategory.continuous);
    });
    test('STAND → count', () {
      expect(classifyAssessmentCode('STAND'), AssessmentCategory.count);
    });
    test('null → unknown', () {
      expect(classifyAssessmentCode(null), AssessmentCategory.unknown);
    });
    test('empty → unknown', () {
      expect(classifyAssessmentCode(''), AssessmentCategory.unknown);
    });
    test('mixed case → matches', () {
      expect(classifyAssessmentCode('contro'), AssessmentCategory.percent);
    });
    test('whitespace trimmed', () {
      expect(classifyAssessmentCode('  LODGIN  '), AssessmentCategory.percent);
    });
    test('unknown code → unknown', () {
      expect(classifyAssessmentCode('FOOBAR'), AssessmentCategory.unknown);
    });
  });

  group('interpretCV (category-aware)', () {
    test('continuous CV 8% → low', () {
      final r = interpretCV(cv: 8, mean: 5000, n: 16, category: AssessmentCategory.continuous);
      expect(r.signal, CvSignal.low);
    });
    test('continuous CV 18% → typical', () {
      final r = interpretCV(cv: 18, mean: 5000, n: 16, category: AssessmentCategory.continuous);
      expect(r.signal, CvSignal.typical);
      expect(r.message, contains('yield/biomass'));
    });
    test('continuous CV 35% → high', () {
      final r = interpretCV(cv: 35, mean: 5000, n: 16, category: AssessmentCategory.continuous);
      expect(r.signal, CvSignal.high);
    });
    test('count CV 30% → typical', () {
      final r = interpretCV(cv: 30, mean: 50, n: 16, category: AssessmentCategory.count);
      expect(r.signal, CvSignal.typical);
      expect(r.message, contains('count'));
    });
    test('percent mean 22%, CV 66% → typical (TA6 regression)', () {
      final r = interpretCV(cv: 66, mean: 22, n: 16, category: AssessmentCategory.percent);
      expect(r.signal, CvSignal.typical);
    });
    test('percent mean 22%, CV 90% → high', () {
      final r = interpretCV(cv: 90, mean: 22, n: 16, category: AssessmentCategory.percent);
      expect(r.signal, CvSignal.high);
    });
    test('percent mean 8%, CV 150% → suppressed (low-mean floor)', () {
      final r = interpretCV(cv: 150, mean: 8, n: 16, category: AssessmentCategory.percent);
      expect(r.signal, CvSignal.suppressed);
      expect(r.message, contains('not informative'));
    });
    test('percent n=3 → suppressed (low n)', () {
      final r = interpretCV(cv: 30, mean: 50, n: 3, category: AssessmentCategory.percent);
      expect(r.signal, CvSignal.suppressed);
      expect(r.message, contains('Too few'));
    });
    test('unknown CV 20% → typical', () {
      final r = interpretCV(cv: 20, mean: 50, n: 16, category: AssessmentCategory.unknown);
      expect(r.signal, CvSignal.typical);
    });
    test('null CV → suppressed', () {
      final r = interpretCV(cv: null, mean: 50, n: 16, category: AssessmentCategory.unknown);
      expect(r.signal, CvSignal.suppressed);
      expect(r.showCvNumber, false);
    });
  });

  group('sortTreatmentMeans', () {
    test('higherIsBetter sorts by descending mean', () {
      final means = [
        _tm('TRT_A', 80),
        _tm('TRT_B', 95),
        _tm('TRT_C', 70),
      ];
      final sorted =
          sortTreatmentMeans(means, ResultDirection.higherIsBetter);
      expect(
        sorted.map((e) => e.treatmentCode).toList(),
        ['TRT_B', 'TRT_A', 'TRT_C'],
      );
    });

    test('lowerIsBetter sorts by ascending mean', () {
      final means = [
        _tm('TRT_A', 80),
        _tm('TRT_B', 95),
        _tm('TRT_C', 70),
      ];
      final sorted =
          sortTreatmentMeans(means, ResultDirection.lowerIsBetter);
      expect(
        sorted.map((e) => e.treatmentCode).toList(),
        ['TRT_C', 'TRT_A', 'TRT_B'],
      );
    });

    test('neutral sorts alphabetically by treatmentCode', () {
      final means = [
        _tm('TRT_C', 80),
        _tm('TRT_A', 95),
        _tm('TRT_B', 70),
      ];
      final sorted = sortTreatmentMeans(means, ResultDirection.neutral);
      expect(
        sorted.map((e) => e.treatmentCode).toList(),
        ['TRT_A', 'TRT_B', 'TRT_C'],
      );
    });

    test('does not mutate the input list', () {
      final means = [
        _tm('TRT_A', 80),
        _tm('TRT_B', 95),
      ];
      final codesBefore = means.map((e) => e.treatmentCode).toList();
      sortTreatmentMeans(means, ResultDirection.higherIsBetter);
      expect(
        means.map((e) => e.treatmentCode).toList(),
        codesBefore,
      );
    });
  });

  group('computeAssessmentStatistics', () {
    test('computes trialCV and cvInterpretation from treatment means', () {
      // Two treatments, 2 plots each, enough data for pooled CV.
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'A', assessmentName: _kAssessment, value: '10'),
        _row(plotId: '2', rep: 2, treatmentCode: 'A', assessmentName: _kAssessment, value: '12'),
        _row(plotId: '3', rep: 1, treatmentCode: 'B', assessmentName: _kAssessment, value: '20'),
        _row(plotId: '4', rep: 2, treatmentCode: 'B', assessmentName: _kAssessment, value: '22'),
      ];
      final result = computeAssessmentStatistics(
        rows,
        _kAssessment,
        1,
        '%',
        'neutral',
        4,
        {1, 2},
      );
      expect(result.trialCV, isNotNull);
      expect(result.trialCV, greaterThan(0));
      expect(result.cvInterpretation, isNotNull);
      expect(result.outliers, isNull);
    });

    test('trialCV is null when only one observation', () {
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T', assessmentName: _kAssessment, value: '10'),
      ];
      final result = computeAssessmentStatistics(
        rows,
        _kAssessment,
        1,
        '%',
        'neutral',
        4,
        {1},
      );
      expect(result.trialCV, isNull);
      expect(result.cvInterpretation?.signal, CvSignal.suppressed);
      expect(result.outliers, isNull);
    });

    test('maps resultDirectionString to ResultDirection', () {
      final rows = [
        _row(
          plotId: '1',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
      ];
      expect(
        computeAssessmentStatistics(
          rows,
          _kAssessment,
          1,
          '%',
          'higherBetter',
          4,
          {1},
        ).resultDirection,
        ResultDirection.higherIsBetter,
      );
      expect(
        computeAssessmentStatistics(
          rows,
          _kAssessment,
          1,
          '%',
          'lowerBetter',
          4,
          {1},
        ).resultDirection,
        ResultDirection.lowerIsBetter,
      );
      expect(
        computeAssessmentStatistics(
          rows,
          _kAssessment,
          1,
          '%',
          'unknown',
          4,
          {1},
        ).resultDirection,
        ResultDirection.neutral,
      );
    });

    test('hasAnyData is false when there is no rated data', () {
      final result = computeAssessmentStatistics(
        [],
        _kAssessment,
        1,
        '%',
        'neutral',
        4,
        {1},
      );
      expect(result.hasAnyData, isFalse);
    });

    test('isPreliminary is false when data is complete', () {
      final rows = [
        _row(
          plotId: '101',
          rep: 1,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '10',
        ),
        _row(
          plotId: '201',
          rep: 2,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '20',
        ),
        _row(
          plotId: '301',
          rep: 3,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '30',
        ),
        _row(
          plotId: '401',
          rep: 4,
          treatmentCode: 'T',
          assessmentName: _kAssessment,
          value: '40',
        ),
      ];
      final result = computeAssessmentStatistics(
        rows,
        _kAssessment,
        1,
        '%',
        'neutral',
        4,
        {1, 2, 3, 4},
      );
      expect(result.isPreliminary, isFalse);
    });
  });

  group('computeCheckComparison', () {
    TreatmentMean makeMean(String code, double mean) => TreatmentMean(
          treatmentCode: code,
          mean: mean,
          standardDeviation: 1,
          standardError: 0.5,
          n: 4,
          min: mean - 2,
          max: mean + 2,
          isPreliminary: false,
        );

    test('computes percent change relative to check', () {
      final means = [makeMean('UTC', 50), makeMean('T1', 25), makeMean('T2', 75)];
      final result = computeCheckComparison(means, 'UTC');
      expect(result.length, 2);
      expect(result['T1'], closeTo(-50.0, 0.01));
      expect(result['T2'], closeTo(50.0, 0.01));
      expect(result.containsKey('UTC'), false);
    });

    test('returns empty map when check code is null', () {
      final means = [makeMean('T1', 10)];
      expect(computeCheckComparison(means, null), isEmpty);
    });

    test('returns empty map when check code not found', () {
      final means = [makeMean('T1', 10)];
      expect(computeCheckComparison(means, 'MISSING'), isEmpty);
    });

    test('returns empty map when check mean is zero', () {
      final means = [makeMean('UTC', 0), makeMean('T1', 10)];
      expect(computeCheckComparison(means, 'UTC'), isEmpty);
    });

    test('returns empty map when means list is empty', () {
      expect(computeCheckComparison([], 'UTC'), isEmpty);
    });
  });

  group('computeRepConsistency', () {
    test('flags rep with inverted treatment ranking', () {
      // Consensus: T1 > T2 (T1 has higher values in reps 1 and 2).
      // Rep 3: T2 > T1 (inverted).
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T1', assessmentName: _kAssessment, value: '80'),
        _row(plotId: '2', rep: 1, treatmentCode: 'T2', assessmentName: _kAssessment, value: '40'),
        _row(plotId: '3', rep: 2, treatmentCode: 'T1', assessmentName: _kAssessment, value: '85'),
        _row(plotId: '4', rep: 2, treatmentCode: 'T2', assessmentName: _kAssessment, value: '35'),
        _row(plotId: '5', rep: 3, treatmentCode: 'T1', assessmentName: _kAssessment, value: '30'),
        _row(plotId: '6', rep: 3, treatmentCode: 'T2', assessmentName: _kAssessment, value: '90'),
      ];
      final issues = computeRepConsistency(rows, _kAssessment);
      expect(issues.length, 1);
      expect(issues[0].rep, 3);
      expect(issues[0].repRanking.first, 'T2');
      expect(issues[0].consensusRanking.first, 'T1');
    });

    test('returns empty when all reps agree', () {
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T1', assessmentName: _kAssessment, value: '80'),
        _row(plotId: '2', rep: 1, treatmentCode: 'T2', assessmentName: _kAssessment, value: '40'),
        _row(plotId: '3', rep: 2, treatmentCode: 'T1', assessmentName: _kAssessment, value: '75'),
        _row(plotId: '4', rep: 2, treatmentCode: 'T2', assessmentName: _kAssessment, value: '35'),
      ];
      expect(computeRepConsistency(rows, _kAssessment), isEmpty);
    });

    test('returns empty with fewer than 2 reps', () {
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T1', assessmentName: _kAssessment, value: '80'),
        _row(plotId: '2', rep: 1, treatmentCode: 'T2', assessmentName: _kAssessment, value: '40'),
      ];
      expect(computeRepConsistency(rows, _kAssessment), isEmpty);
    });

    test('returns empty with fewer than 2 treatments', () {
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T1', assessmentName: _kAssessment, value: '80'),
        _row(plotId: '2', rep: 2, treatmentCode: 'T1', assessmentName: _kAssessment, value: '75'),
      ];
      expect(computeRepConsistency(rows, _kAssessment), isEmpty);
    });

    test('ignores non-RECORDED rows', () {
      final rows = [
        _row(plotId: '1', rep: 1, treatmentCode: 'T1', assessmentName: _kAssessment, value: '80'),
        _row(plotId: '2', rep: 1, treatmentCode: 'T2', assessmentName: _kAssessment, value: '40'),
        _row(plotId: '3', rep: 2, treatmentCode: 'T1', assessmentName: _kAssessment, value: '75'),
        _row(plotId: '4', rep: 2, treatmentCode: 'T2', assessmentName: _kAssessment, value: '35'),
        // VOID row in rep 3 should not create a rep entry.
        const RatingResultRow(plotId: '5', rep: 3, treatmentCode: 'T2', assessmentName: _kAssessment, value: '99', resultStatus: 'VOID', unit: '%'),
      ];
      expect(computeRepConsistency(rows, _kAssessment), isEmpty);
    });
  });
}
