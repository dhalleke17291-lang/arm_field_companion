import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/utils/check_treatment_helper.dart';
import 'package:arm_field_companion/features/trials/domain/trial_data_computer.dart';
import 'package:arm_field_companion/features/trials/trial_data_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime(2024, 4, 15);

Treatment _treatment({
  required int id,
  required String code,
  String name = 'Treatment',
  String? treatmentType,
}) =>
    Treatment(
      id: id,
      trialId: 1,
      code: code,
      name: name,
      treatmentType: treatmentType,
      isDeleted: false,
    );

Plot _plot({
  required int id,
  required int? treatmentId,
  bool isGuardRow = false,
  bool excludeFromAnalysis = false,
}) =>
    Plot(
      id: id,
      trialId: 1,
      plotId: 'P$id',
      treatmentId: treatmentId,
      isGuardRow: isGuardRow,
      isDeleted: false,
      excludeFromAnalysis: excludeFromAnalysis,
    );

Assignment _assignment({required int plotId, required int treatmentId}) =>
    Assignment(
      id: plotId * 100,
      trialId: 1,
      plotId: plotId,
      treatmentId: treatmentId,
      createdAt: _now,
      updatedAt: _now,
    );

Assessment _assessment(int id) => Assessment(
      id: id,
      trialId: 1,
      name: 'Assessment $id',
      dataType: 'numeric',
      isActive: true,
    );

RatingRecord _rating({
  required int id,
  required int plotPk,
  required int assessmentId,
  required int sessionId,
  required double value,
  bool isCurrent = true,
  bool isDeleted = false,
  bool amended = false,
  String? raterName = 'Alice',
}) =>
    RatingRecord(
      id: id,
      trialId: 1,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      resultStatus: 'RECORDED',
      numericValue: value,
      isCurrent: isCurrent,
      amended: amended,
      isDeleted: isDeleted,
      createdAt: _now,
      raterName: raterName,
    );

Session _session({
  required int id,
  String status = 'closed',
  String? dateLocal,
}) =>
    Session(
      id: id,
      trialId: 1,
      name: 'Session $id',
      startedAt: _now,
      sessionDateLocal: dateLocal ?? '2024-04-${10 + id}',
      status: status,
      isDeleted: false,
    );

WeatherSnapshot _snapshot({required int id, required int parentId}) =>
    WeatherSnapshot(
      id: id,
      uuid: 'uuid-$id',
      trialId: 1,
      parentType: 'rating_session',
      parentId: parentId,
      source: 'manual',
      temperature: 18.5,
      temperatureUnit: 'C',
      windSpeedUnit: 'km/h',
      recordedAt: _now.millisecondsSinceEpoch,
      createdAt: _now.millisecondsSinceEpoch,
      modifiedAt: _now.millisecondsSinceEpoch,
      createdBy: 'test',
      precipitation: 'none',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('isCheckTreatment', () {
    test('identifies CHK by code', () {
      expect(isCheckTreatment(_treatment(id: 1, code: 'CHK')), isTrue);
      expect(isCheckTreatment(_treatment(id: 1, code: 'chk')), isTrue);
      expect(isCheckTreatment(_treatment(id: 1, code: ' CHK ')), isTrue);
    });

    test('identifies UTC by code', () {
      expect(isCheckTreatment(_treatment(id: 1, code: 'UTC')), isTrue);
      expect(isCheckTreatment(_treatment(id: 1, code: 'utc')), isTrue);
    });

    test('identifies CONTROL by code', () {
      expect(isCheckTreatment(_treatment(id: 1, code: 'CONTROL')), isTrue);
    });

    test('identifies check by treatmentType', () {
      expect(
        isCheckTreatment(_treatment(id: 1, code: 'T1', treatmentType: 'CHK')),
        isTrue,
      );
      expect(
        isCheckTreatment(_treatment(id: 1, code: 'T1', treatmentType: 'utc')),
        isTrue,
      );
    });

    test('returns false for regular treatments', () {
      expect(isCheckTreatment(_treatment(id: 1, code: 'T1')), isFalse);
      expect(isCheckTreatment(_treatment(id: 1, code: 'CHKX')), isFalse);
    });
  });

  group('TrialDataComputer.computeTreatmentMeans', () {
    test('computes mean for single treatment across reps', () {
      final treatments = [_treatment(id: 1, code: 'T1')];
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1),
        _plot(id: 3, treatmentId: 1),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 1),
        _assignment(plotId: 3, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 4.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 6.0),
        _rating(id: 3, plotPk: 3, assessmentId: 10, sessionId: 1, value: 8.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: treatments,
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[1], isNotNull);
      expect(result[1]![10], isNotNull);
      expect(result[1]![10]!.mean, closeTo(6.0, 0.001));
      expect(result[1]![10]!.n, 3);
    });

    test('excludes guard rows from mean', () {
      final treatments = [_treatment(id: 1, code: 'T1')];
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1, isGuardRow: true), // excluded
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 4.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 99.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: treatments,
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      // Only plot 1 is analyzable; guard row (plot 2) is excluded
      expect(result[1]?[10]?.mean, closeTo(4.0, 0.001));
      expect(result[1]?[10]?.n, 1);
    });

    test('excludes deleted and non-current ratings', () {
      final treatments = [_treatment(id: 1, code: 'T1')];
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 4.0),
        _rating(
            id: 2,
            plotPk: 2,
            assessmentId: 10,
            sessionId: 1,
            value: 99.0,
            isDeleted: true),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: treatments,
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[1]?[10]?.mean, closeTo(4.0, 0.001));
      expect(result[1]?[10]?.n, 1);
    });
  });

  group('TrialDataComputer — separation from check', () {
    test('computes positive separation (treatment > check)', () {
      final check = _treatment(id: 1, code: 'CHK');
      final trt = _treatment(id: 2, code: 'T1');
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 2),
        _plot(id: 3, treatmentId: 2),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 2),
        _assignment(plotId: 3, treatmentId: 2),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 50.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 70.0),
        _rating(id: 3, plotPk: 3, assessmentId: 10, sessionId: 1, value: 70.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: [check, trt],
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[2]?[10]?.separation, closeTo(20.0, 0.001)); // 70 - 50
      expect(result[1]?[10]?.separation, isNull); // check has no separation
    });

    test('computes negative separation (treatment < check)', () {
      final check = _treatment(id: 1, code: 'CHK');
      final trt = _treatment(id: 2, code: 'T1');
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 2),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 2),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 80.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 60.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: [check, trt],
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[2]?[10]?.separation, closeTo(-20.0, 0.001));
    });

    test('separation is null when no check exists', () {
      final trt = _treatment(id: 2, code: 'T1');
      final plots = [_plot(id: 2, treatmentId: 2)];
      final assignments = [_assignment(plotId: 2, treatmentId: 2)];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 60.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: [trt],
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[2]?[10]?.separation, isNull);
    });
  });

  group('TrialDataComputer — CV', () {
    test('computes CV when n >= kMinRepsForRepVariability', () {
      final treatments = [_treatment(id: 1, code: 'T1')];
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1),
        _plot(id: 3, treatmentId: 1),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 1),
        _assignment(plotId: 3, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 8.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 10.0),
        _rating(id: 3, plotPk: 3, assessmentId: 10, sessionId: 1, value: 12.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: treatments,
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      final cell = result[1]![10]!;
      expect(cell.mean, closeTo(10.0, 0.001));
      expect(cell.cv, isNotNull);
      // SD = 2, mean = 10, CV = 20%
      expect(cell.cv!, closeTo(20.0, 0.01));
    });

    test('CV is null when n < kMinRepsForRepVariability', () {
      final treatments = [_treatment(id: 1, code: 'T1')];
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 8.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 12.0),
      ];

      final result = TrialDataComputer.computeTreatmentMeans(
        treatments: treatments,
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(result[1]?[10]?.cv, isNull);
    });
  });

  group('TrialDataComputer.computeOutlierCandidates', () {
    test('flags values >2 SD from treatment mean', () {
      // With n-1 identical values and 1 outlier, the outlier is detectable
      // only when n ≥ 7 (because the single outlier inflates the sample SD).
      // Here: 6 reps at 10.0, 1 extreme outlier at 200.0 (n=7).
      // mean = 37.14, SD = 71.8, 2·SD = 143.6
      // diff(200) = 162.9 > 143.6 → outlier detected.
      final plots = [
        for (int i = 1; i <= 7; i++) _plot(id: i, treatmentId: 1),
      ];
      final assignments = [
        for (int i = 1; i <= 7; i++) _assignment(plotId: i, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        for (int i = 1; i <= 6; i++)
          _rating(id: i, plotPk: i, assessmentId: 10, sessionId: 1, value: 10.0),
        _rating(id: 7, plotPk: 7, assessmentId: 10, sessionId: 1, value: 200.0),
      ];

      final outliers = TrialDataComputer.computeOutlierCandidates(
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(outliers, contains((7, 10)));
      for (int i = 1; i <= 6; i++) {
        expect(outliers, isNot(contains((i, 10))));
      }
    });

    test('does not flag outliers when group has < kMinRepsForRepVariability', () {
      final plots = [
        _plot(id: 1, treatmentId: 1),
        _plot(id: 2, treatmentId: 1),
      ];
      final assignments = [
        _assignment(plotId: 1, treatmentId: 1),
        _assignment(plotId: 2, treatmentId: 1),
      ];
      final assessments = [_assessment(10)];
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 5.0),
        _rating(id: 2, plotPk: 2, assessmentId: 10, sessionId: 1, value: 95.0),
      ];

      final outliers = TrialDataComputer.computeOutlierCandidates(
        plots: plots,
        assignments: assignments,
        assessments: assessments,
        ratings: ratings,
      );

      expect(outliers, isEmpty);
    });
  });

  group('TrialDataComputer.findAmendedRatings', () {
    test('returns only amended ratings', () {
      final ratings = [
        _rating(id: 1, plotPk: 1, assessmentId: 10, sessionId: 1, value: 5.0),
        _rating(
            id: 2,
            plotPk: 2,
            assessmentId: 10,
            sessionId: 1,
            value: 7.0,
            amended: true),
        _rating(
            id: 3,
            plotPk: 3,
            assessmentId: 10,
            sessionId: 1,
            value: 3.0,
            amended: true),
      ];

      final amended = TrialDataComputer.findAmendedRatings(ratings);
      expect(amended.map((r) => r.id), containsAll([2, 3]));
      expect(amended.map((r) => r.id), isNot(contains(1)));
    });

    test('excludes deleted amended ratings', () {
      final ratings = [
        _rating(
            id: 1,
            plotPk: 1,
            assessmentId: 10,
            sessionId: 1,
            value: 5.0,
            amended: true,
            isDeleted: true),
      ];

      expect(TrialDataComputer.findAmendedRatings(ratings), isEmpty);
    });
  });

  group('TrialDataComputer.findUnattributedRatings', () {
    test('returns ratings with null raterName', () {
      final ratings = [
        _rating(
            id: 1,
            plotPk: 1,
            assessmentId: 10,
            sessionId: 1,
            value: 5.0,
            raterName: null),
        _rating(
            id: 2,
            plotPk: 2,
            assessmentId: 10,
            sessionId: 1,
            value: 7.0,
            raterName: 'Bob'),
      ];

      final unattr = TrialDataComputer.findUnattributedRatings(ratings);
      expect(unattr.map((r) => r.id), contains(1));
      expect(unattr.map((r) => r.id), isNot(contains(2)));
    });
  });

  group('TrialDataComputer.findWeatherGaps', () {
    test('identifies closed sessions with no snapshot', () {
      final sessions = [
        _session(id: 1),
        _session(id: 2),
        _session(id: 3),
      ];
      final snapshots = [
        _snapshot(id: 1, parentId: 1),
        // session 2 and 3 have no snapshot
      ];

      final gaps = TrialDataComputer.findWeatherGaps(
        closedSessions: sessions,
        snapshots: snapshots,
      );

      expect(gaps.map((s) => s.id), containsAll([2, 3]));
      expect(gaps.map((s) => s.id), isNot(contains(1)));
    });

    test('returns empty when all sessions have snapshots', () {
      final sessions = [_session(id: 1), _session(id: 2)];
      final snapshots = [
        _snapshot(id: 1, parentId: 1),
        _snapshot(id: 2, parentId: 2),
      ];

      final gaps = TrialDataComputer.findWeatherGaps(
        closedSessions: sessions,
        snapshots: snapshots,
      );

      expect(gaps, isEmpty);
    });
  });

  group('TrialDataComputer.findApplicationWeather', () {
    test('finds session within ±3 days of application date', () {
      final applicationDate = DateTime(2024, 4, 15);
      final sessions = [
        _session(id: 1, dateLocal: '2024-04-14'), // 1 day before — within window
        _session(id: 2, dateLocal: '2024-04-20'), // 5 days after — outside window
      ];
      final snapshots = [
        _snapshot(id: 1, parentId: 1),
        _snapshot(id: 2, parentId: 2),
      ];

      final result = TrialDataComputer.findApplicationWeather(
        applicationDate: applicationDate,
        sessions: sessions,
        snapshots: snapshots,
      );

      expect(result, isNotNull);
      expect(result!.parentId, 1);
    });

    test('returns null when no session within ±3 days', () {
      final applicationDate = DateTime(2024, 4, 15);
      final sessions = [
        _session(id: 1, dateLocal: '2024-04-20'), // 5 days after
        _session(id: 2, dateLocal: '2024-04-10'), // 5 days before
      ];
      final snapshots = [
        _snapshot(id: 1, parentId: 1),
        _snapshot(id: 2, parentId: 2),
      ];

      final result = TrialDataComputer.findApplicationWeather(
        applicationDate: applicationDate,
        sessions: sessions,
        snapshots: snapshots,
      );

      expect(result, isNull);
    });

    test('picks closest session when multiple are in window', () {
      final applicationDate = DateTime(2024, 4, 15);
      final sessions = [
        _session(id: 1, dateLocal: '2024-04-13'), // 2 days before
        _session(id: 2, dateLocal: '2024-04-16'), // 1 day after — closer
      ];
      final snapshots = [
        _snapshot(id: 1, parentId: 1),
        _snapshot(id: 2, parentId: 2),
      ];

      final result = TrialDataComputer.findApplicationWeather(
        applicationDate: applicationDate,
        sessions: sessions,
        snapshots: snapshots,
      );

      expect(result!.parentId, 2); // session 2 is closer (1 day vs 2 days)
    });

    test('returns null when session exists but has no snapshot', () {
      final applicationDate = DateTime(2024, 4, 15);
      final sessions = [
        _session(id: 1, dateLocal: '2024-04-15'),
      ];

      final result = TrialDataComputer.findApplicationWeather(
        applicationDate: applicationDate,
        sessions: sessions,
        snapshots: [],
      );

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Summary header — execution row
  // ---------------------------------------------------------------------------

  group('computeExecutionRowSuffix', () {
    test('all completed with no deviations → complete', () {
      final states = [
        (status: 'completed', hasDeviation: false),
        (status: 'completed', hasDeviation: false),
      ];
      expect(computeExecutionRowSuffix(states), 'complete');
    });

    test('one non-completed status → 1 item to review', () {
      final states = [
        (status: 'pending', hasDeviation: false),
      ];
      expect(computeExecutionRowSuffix(states), '1 item to review');
    });

    test('completed with deviation → counted as to review', () {
      final states = [
        (status: 'completed', hasDeviation: true),
        (status: 'completed', hasDeviation: false),
      ];
      expect(computeExecutionRowSuffix(states), '1 item to review');
    });

    test('empty list → no applications recorded', () {
      expect(computeExecutionRowSuffix([]), 'no applications recorded');
    });
  });

  // ---------------------------------------------------------------------------
  // Summary header — data quality row
  // ---------------------------------------------------------------------------

  group('computeDataQualityRowSuffix', () {
    test('no closed sessions → no closed sessions yet', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 0, openCount: 0, amendedCount: 0, outlierCount: 0),
        'no closed sessions yet',
      );
    });

    test('all closed, zero issues → clean', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 3, openCount: 0, amendedCount: 0, outlierCount: 0),
        'clean',
      );
    });

    test('open sessions appear as named part', () {
      final result = computeDataQualityRowSuffix(
          closedCount: 1, openCount: 3, amendedCount: 0, outlierCount: 0);
      expect(result, '3 open sessions');
    });

    test('single amended rating only → named', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 0, amendedCount: 1, outlierCount: 0),
        '1 amended rating',
      );
    });

    test('single outlier only → named', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 0, amendedCount: 0, outlierCount: 1),
        '1 outlier candidate',
      );
    });

    test('open + amended, no outlier → two parts joined', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 1, amendedCount: 1, outlierCount: 0),
        '1 open session · 1 amended rating',
      );
    });

    test('open + outlier, no amended → two parts joined', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 1, amendedCount: 0, outlierCount: 1),
        '1 open session · 1 outlier candidate',
      );
    });

    test('amended + outlier, no open → two parts joined', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 0, amendedCount: 1, outlierCount: 1),
        '1 amended rating · 1 outlier candidate',
      );
    });

    test('all three → three parts joined', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 1, amendedCount: 1, outlierCount: 1),
        '1 open session · 1 amended rating · 1 outlier candidate',
      );
    });

    test('mixed counts (2+2+1) → named with correct plurals', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 2, openCount: 0, amendedCount: 2, outlierCount: 1),
        '2 amended ratings · 1 outlier candidate',
      );
    });

    test('plural open sessions', () {
      expect(
        computeDataQualityRowSuffix(
            closedCount: 1, openCount: 2, amendedCount: 0, outlierCount: 0),
        '2 open sessions',
      );
    });

    test('open sessions shown when no other issues', () {
      final result = computeDataQualityRowSuffix(
          closedCount: 1, openCount: 3, amendedCount: 0, outlierCount: 0);
      expect(result, '3 open sessions');
    });

    test('outlier only → named', () {
      final result = computeDataQualityRowSuffix(
          closedCount: 1, openCount: 0, amendedCount: 0, outlierCount: 2);
      expect(result, '2 outlier candidates');
    });

    test('open + amended, no outlier → named parts joined', () {
      final result = computeDataQualityRowSuffix(
          closedCount: 1, openCount: 2, amendedCount: 3, outlierCount: 0);
      expect(result, '2 open sessions · 3 amended ratings');
    });
  });

  // ---------------------------------------------------------------------------
  // Weather display — precipitation text label
  // ---------------------------------------------------------------------------

  group('formatWeatherMainLine', () {
    test('precipitation text label shown as-is, not as numeric mm', () {
      final snapshot = WeatherSnapshot(
        id: 10,
        uuid: 'u10',
        trialId: 1,
        parentType: 'rating_session',
        parentId: 10,
        source: 'api',
        temperatureUnit: 'C',
        windSpeedUnit: 'km/h',
        temperature: 22.0,
        precipitation: 'Light rain',
        recordedAt: _now.millisecondsSinceEpoch,
        createdAt: _now.millisecondsSinceEpoch,
        modifiedAt: _now.millisecondsSinceEpoch,
        createdBy: 'test',
      );
      final line = formatWeatherMainLine(snapshot);
      expect(line, contains('Light rain'));
      expect(line, isNot(contains('mm')));
    });

    test('null temperature with non-null precipitation: shows precipitation, no placeholder', () {
      final snapshot = WeatherSnapshot(
        id: 11,
        uuid: 'u11',
        trialId: 1,
        parentType: 'rating_session',
        parentId: 11,
        source: 'api',
        temperatureUnit: 'C',
        windSpeedUnit: 'km/h',
        precipitation: 'Light rain',
        recordedAt: _now.millisecondsSinceEpoch,
        createdAt: _now.millisecondsSinceEpoch,
        modifiedAt: _now.millisecondsSinceEpoch,
        createdBy: 'test',
      );
      final line = formatWeatherMainLine(snapshot);
      expect(line, contains('Light rain'));
      expect(line, isNot(contains('—')));
      expect(line, isNot(contains('null')));
      expect(line, isNot(contains('°')));
    });

    test('manual source appends manual entry label', () {
      final snapshot = WeatherSnapshot(
        id: 12,
        uuid: 'u12',
        trialId: 1,
        parentType: 'rating_session',
        parentId: 12,
        source: 'manual',
        temperatureUnit: 'C',
        windSpeedUnit: 'km/h',
        temperature: 18.0,
        precipitation: 'Trace',
        recordedAt: _now.millisecondsSinceEpoch,
        createdAt: _now.millisecondsSinceEpoch,
        modifiedAt: _now.millisecondsSinceEpoch,
        createdBy: 'test',
      );
      final line = formatWeatherMainLine(snapshot);
      expect(line, contains('manual entry'));
    });
  });

  // ---------------------------------------------------------------------------
  // computeDataQualityIssueLines
  // ---------------------------------------------------------------------------

  RatingRecord closedRating({
    required int id,
    required int plotPk,
    required int assessmentId,
    required int sessionId,
    double value = 5.0,
  }) =>
      RatingRecord(
        id: id,
        trialId: 1,
        plotPk: plotPk,
        assessmentId: assessmentId,
        sessionId: sessionId,
        resultStatus: 'RECORDED',
        numericValue: value,
        isCurrent: true,
        amended: false,
        isDeleted: false,
        createdAt: _now,
        raterName: 'Alice',
      );

  group('computeDataQualityIssueLines', () {
    test('shows session name and assessment when one plot is missing', () {
      final sessions = [_session(id: 1)];
      final plots = [
        _plot(id: 10, treatmentId: 1),
        _plot(id: 11, treatmentId: 1),
      ];
      // Only plot 10 has a rating; plot 11 is missing assessment 20.
      final ratings = [
        closedRating(id: 1, plotPk: 10, assessmentId: 20, sessionId: 1),
      ];
      final lines = computeDataQualityIssueLines(
        closedSessions: sessions,
        closedRatings: ratings,
        analyzablePlots: plots,
        assessmentDisplayNames: {20: 'AGTARSI'},
        amendedRatings: [],
        outlierCandidates: {},
      );

      expect(lines.length, 1);
      expect(lines.first, contains('Session 1'));
      expect(lines.first, contains('P11'));
      expect(lines.first, contains('AGTARSI'));
    });

    test('shows N plots with gaps when more than 5 plots are missing', () {
      final sessions = [_session(id: 1)];
      // 7 plots; only plot 10 has a rating → 6 missing.
      final plots = [
        for (int i = 10; i <= 16; i++) _plot(id: i, treatmentId: 1),
      ];
      final ratings = [
        closedRating(id: 1, plotPk: 10, assessmentId: 20, sessionId: 1),
      ];
      final lines = computeDataQualityIssueLines(
        closedSessions: sessions,
        closedRatings: ratings,
        analyzablePlots: plots,
        assessmentDisplayNames: {20: 'AGTARSI'},
        amendedRatings: [],
        outlierCandidates: {},
      );

      expect(lines.length, 1);
      expect(lines.first, contains('6 plots with gaps'));
      expect(lines.first, isNot(contains('P11')));
    });

    test('caps at 4 lines and appends overflow summary', () {
      // 4 sessions each missing 1 plot, plus amendments → 5 raw lines.
      final sessions = [
        _session(id: 1),
        _session(id: 2),
        _session(id: 3),
        _session(id: 4),
      ];
      final plots = [
        _plot(id: 10, treatmentId: 1),
        _plot(id: 11, treatmentId: 1),
      ];
      // Each session: plot 10 rated, plot 11 missing.
      final ratings = [
        for (int s = 1; s <= 4; s++)
          closedRating(id: s, plotPk: 10, assessmentId: 20, sessionId: s),
      ];
      final amended = [
        _rating(id: 99, plotPk: 11, assessmentId: 20, sessionId: 1, value: 1.0, amended: true),
      ];
      final lines = computeDataQualityIssueLines(
        closedSessions: sessions,
        closedRatings: ratings,
        analyzablePlots: plots,
        assessmentDisplayNames: {20: 'ASSESS'},
        amendedRatings: amended,
        outlierCandidates: {},
      );

      expect(lines.length, 4);
      expect(lines.last, contains('more'));
      expect(lines.last, contains('Assessment quality'));
    });

    test('returns empty list when data quality is clean', () {
      final sessions = [_session(id: 1)];
      final plots = [_plot(id: 10, treatmentId: 1)];
      final ratings = [
        closedRating(id: 1, plotPk: 10, assessmentId: 20, sessionId: 1),
      ];
      final lines = computeDataQualityIssueLines(
        closedSessions: sessions,
        closedRatings: ratings,
        analyzablePlots: plots,
        assessmentDisplayNames: {20: 'AGTARSI'},
        amendedRatings: [],
        outlierCandidates: {},
      );

      expect(lines, isEmpty);
    });

    test('amendment count shown as N ratings amended, not individual listings', () {
      final sessions = [_session(id: 1)];
      final plots = [_plot(id: 10, treatmentId: 1)];
      // All plots rated (no gaps).
      final ratings = [
        closedRating(id: 1, plotPk: 10, assessmentId: 20, sessionId: 1),
      ];
      final amended = [
        _rating(id: 2, plotPk: 10, assessmentId: 20, sessionId: 1, value: 3.0, amended: true),
        _rating(id: 3, plotPk: 10, assessmentId: 20, sessionId: 1, value: 4.0, amended: true),
        _rating(id: 4, plotPk: 10, assessmentId: 20, sessionId: 1, value: 5.0, amended: true),
      ];
      final lines = computeDataQualityIssueLines(
        closedSessions: sessions,
        closedRatings: ratings,
        analyzablePlots: plots,
        assessmentDisplayNames: {20: 'ASSESS'},
        amendedRatings: amended,
        outlierCandidates: {},
      );

      expect(lines.length, 1);
      expect(lines.first, '· 3 ratings amended');
    });
  });
}
