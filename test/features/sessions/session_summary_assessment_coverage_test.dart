import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/domain/ratings/result_status.dart';
import 'package:arm_field_companion/features/sessions/session_summary_assessment_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

Plot _plot({required int id, bool guard = false}) => Plot(
      id: id,
      trialId: 1,
      plotId: 'P$id',
      isGuardRow: guard,
      isDeleted: false,
      excludeFromAnalysis: false,
    );

Assessment _assessment(int id, String name) => Assessment(
      id: id,
      trialId: 1,
      name: name,
      dataType: 'numeric',
      isActive: true,
    );

RatingRecord _rating({
  required int id,
  required int plotPk,
  required int assessmentId,
  String status = ResultStatusDb.recorded,
}) {
  final now = DateTime.now().toUtc();
  return RatingRecord(
    id: id,
    trialId: 1,
    plotPk: plotPk,
    assessmentId: assessmentId,
    sessionId: 1,
    resultStatus: status,
    isCurrent: true,
    createdAt: now,
    amended: false,
    isDeleted: false,
  );
}

void main() {
  group('computeSessionSummaryAssessmentCoverage', () {
    test('excludes guard rows from target count', () {
      final rows = computeSessionSummaryAssessmentCoverage(
        plotsForTrial: [
          _plot(id: 1),
          _plot(id: 2, guard: true),
        ],
        sessionAssessments: [_assessment(10, 'A')],
        currentSessionRatings: [
          _rating(id: 1, plotPk: 1, assessmentId: 10),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single.targetPlotCount, 1);
      expect(rows.single.recordedCount, 1);
      expect(rows.single.isIncomplete, false);
    });

    test('only RECORDED counts toward assessment coverage', () {
      final rows = computeSessionSummaryAssessmentCoverage(
        plotsForTrial: [_plot(id: 1), _plot(id: 2)],
        sessionAssessments: [_assessment(10, 'Height')],
        currentSessionRatings: [
          _rating(id: 1, plotPk: 1, assessmentId: 10),
          _rating(
            id: 2,
            plotPk: 2,
            assessmentId: 10,
            status: ResultStatusDb.notApplicable,
          ),
        ],
      );
      expect(rows.single.targetPlotCount, 2);
      expect(rows.single.recordedCount, 1);
      expect(rows.single.isIncomplete, true);
    });

    test('per-assessment counts are independent', () {
      final rows = computeSessionSummaryAssessmentCoverage(
        plotsForTrial: [_plot(id: 1), _plot(id: 2)],
        sessionAssessments: [
          _assessment(10, 'A'),
          _assessment(11, 'B'),
        ],
        currentSessionRatings: [
          _rating(id: 1, plotPk: 1, assessmentId: 10),
          _rating(id: 2, plotPk: 1, assessmentId: 11),
          _rating(id: 3, plotPk: 2, assessmentId: 10),
        ],
      );
      expect(rows[0].assessmentName, 'A');
      expect(rows[0].recordedCount, 2);
      expect(rows[0].isIncomplete, false);
      expect(rows[1].assessmentName, 'B');
      expect(rows[1].recordedCount, 1);
      expect(rows[1].isIncomplete, true);
    });
  });
}
