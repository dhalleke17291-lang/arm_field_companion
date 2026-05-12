import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/export/trial_report_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 1, 1);

Trial _trial({String workspaceType = 'standalone'}) => Trial(
      id: 1,
      name: 'Test Trial',
      status: 'active',
      workspaceType: workspaceType,
      createdAt: _now,
      updatedAt: _now,
      region: 'eppo_eu',
      isDeleted: false,
    );

Treatment _treatment({
  required int id,
  required String code,
  String? treatmentType,
}) =>
    Treatment(
      id: id,
      trialId: 1,
      code: code,
      name: 'Treatment $code',
      treatmentType: treatmentType,
      isDeleted: false,
    );

Plot _plot({required int id, required int rep}) => Plot(
      id: id,
      trialId: 1,
      plotId: 'P$id',
      rep: rep,
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: false,
    );

Assignment _assignment({required int plotId, required int treatmentId}) =>
    Assignment(
      id: plotId,
      trialId: 1,
      plotId: plotId,
      treatmentId: treatmentId,
      createdAt: _now,
      updatedAt: _now,
    );

Session _session() => Session(
      id: 1,
      trialId: 1,
      name: 'S1',
      startedAt: _now,
      sessionDateLocal: '2026-05-01',
      status: 'closed',
      isDeleted: false,
    );

Assessment _assessment({int id = 1}) => Assessment(
      id: id,
      trialId: 1,
      name: 'Efficacy',
      dataType: 'numeric',
      isActive: true,
    );

RatingRecord _rating({
  required int id,
  required int plotPk,
  required int assessmentId,
  required int sessionId,
  required double value,
}) =>
    RatingRecord(
      id: id,
      trialId: 1,
      plotPk: plotPk,
      assessmentId: assessmentId,
      sessionId: sessionId,
      numericValue: value,
      resultStatus: 'RECORDED',
      isCurrent: true,
      amended: false,
      isDeleted: false,
      createdAt: _now,
    );

// ---------------------------------------------------------------------------
// pctOfCheckCell unit tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrialReportPdfBuilder.pctOfCheckCell', () {
    test('check treatment row always returns —', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: true,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: 50.0,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('check treatment row returns — even when ARM-linked', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: true,
          checkCase: 'single',
          isArmLinked: true,
          checkMean: 50.0,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('no check treatment: non-check row returns —', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'none',
          isArmLinked: false,
          checkMean: null,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('multiple check treatments: non-check row returns —', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'multiple',
          isArmLinked: false,
          checkMean: 50.0,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('single check, ARM-linked: non-check row returns empty string', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: true,
          checkMean: 50.0,
          treatmentMean: 80.0,
        ),
        equals(''),
      );
    });

    test(
        'single check, standalone: returns value with one decimal and % suffix',
        () {
      // 80 / 50 * 100 = 160.0%
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: 50.0,
          treatmentMean: 80.0,
        ),
        equals('160.0%'),
      );
    });

    test('single check, standalone: rounds to one decimal place', () {
      // 73 / 60 * 100 = 121.666... → 121.7%
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: 60.0,
          treatmentMean: 73.0,
        ),
        equals('121.7%'),
      );
    });

    test('checkMean zero: returns — (no divide-by-zero crash)', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: 0.0,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('checkMean null (no data for check treatment): returns —', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: null,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });

    test('very small checkMean (below threshold): returns —', () {
      expect(
        TrialReportPdfBuilder.pctOfCheckCell(
          isCheckTrt: false,
          checkCase: 'single',
          isArmLinked: false,
          checkMean: 0.00005,
          treatmentMean: 80.0,
        ),
        equals('—'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // build() smoke tests — verify no crash for each check case
  // ---------------------------------------------------------------------------

  group('TrialReportPdfBuilder.build — % of Check integration', () {
    final builder = TrialReportPdfBuilder();

    final twoTreatments = [
      _treatment(id: 1, code: 'CHK'),
      _treatment(id: 2, code: 'T1'),
    ];

    final twoPlots = [
      _plot(id: 1, rep: 1),
      _plot(id: 2, rep: 1),
    ];

    final twoAssignments = [
      _assignment(plotId: 1, treatmentId: 1),
      _assignment(plotId: 2, treatmentId: 2),
    ];

    final twoRatings = [
      _rating(id: 1, plotPk: 1, assessmentId: 1, sessionId: 1, value: 50),
      _rating(id: 2, plotPk: 2, assessmentId: 1, sessionId: 1, value: 80),
    ];

    test('single check, standalone — builds without throwing', () async {
      final bytes = await builder.build(
        trial: _trial(workspaceType: 'standalone'),
        plots: twoPlots,
        treatments: twoTreatments,
        componentsByTreatment: const {},
        sessions: [_session()],
        ratings: twoRatings,
        assessments: [_assessment()],
        applications: const [],
        assignments: twoAssignments,
      );
      expect(bytes, isNotEmpty);
    });

    test('single check, ARM-linked (efficacy) — builds without throwing',
        () async {
      final bytes = await builder.build(
        trial: _trial(workspaceType: 'efficacy'),
        plots: twoPlots,
        treatments: twoTreatments,
        componentsByTreatment: const {},
        sessions: [_session()],
        ratings: twoRatings,
        assessments: [_assessment()],
        applications: const [],
        assignments: twoAssignments,
      );
      expect(bytes, isNotEmpty);
    });

    test('no check treatment — builds without throwing', () async {
      final bytes = await builder.build(
        trial: _trial(workspaceType: 'standalone'),
        plots: twoPlots,
        treatments: [
          _treatment(id: 1, code: 'T1'),
          _treatment(id: 2, code: 'T2'),
        ],
        componentsByTreatment: const {},
        sessions: [_session()],
        ratings: [
          _rating(id: 1, plotPk: 1, assessmentId: 1, sessionId: 1, value: 60),
          _rating(id: 2, plotPk: 2, assessmentId: 1, sessionId: 1, value: 75),
        ],
        assessments: [_assessment()],
        applications: const [],
        assignments: twoAssignments,
      );
      expect(bytes, isNotEmpty);
    });

    test('multiple check treatments — builds without throwing', () async {
      final bytes = await builder.build(
        trial: _trial(workspaceType: 'standalone'),
        plots: [
          _plot(id: 1, rep: 1),
          _plot(id: 2, rep: 1),
          _plot(id: 3, rep: 1),
        ],
        treatments: [
          _treatment(id: 1, code: 'CHK'),
          _treatment(id: 2, code: 'UTC'),
          _treatment(id: 3, code: 'T1'),
        ],
        componentsByTreatment: const {},
        sessions: [_session()],
        ratings: [
          _rating(id: 1, plotPk: 1, assessmentId: 1, sessionId: 1, value: 50),
          _rating(id: 2, plotPk: 2, assessmentId: 1, sessionId: 1, value: 48),
          _rating(id: 3, plotPk: 3, assessmentId: 1, sessionId: 1, value: 80),
        ],
        assessments: [_assessment()],
        applications: const [],
        assignments: [
          _assignment(plotId: 1, treatmentId: 1),
          _assignment(plotId: 2, treatmentId: 2),
          _assignment(plotId: 3, treatmentId: 3),
        ],
      );
      expect(bytes, isNotEmpty);
    });

    test('check mean zero — builds without throwing (no divide-by-zero)',
        () async {
      final bytes = await builder.build(
        trial: _trial(workspaceType: 'standalone'),
        plots: twoPlots,
        treatments: twoTreatments,
        componentsByTreatment: const {},
        sessions: [_session()],
        ratings: [
          _rating(id: 1, plotPk: 1, assessmentId: 1, sessionId: 1, value: 0),
          _rating(id: 2, plotPk: 2, assessmentId: 1, sessionId: 1, value: 80),
        ],
        assessments: [_assessment()],
        applications: const [],
        assignments: twoAssignments,
      );
      expect(bytes, isNotEmpty);
    });
  });
}
