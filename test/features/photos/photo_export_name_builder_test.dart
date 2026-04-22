import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/features/photos/photo_export_name_builder.dart';
import 'package:flutter_test/flutter_test.dart';

Trial _trial({required int id, required String name}) => Trial(
      id: id,
      name: name,
      status: 'active',
      workspaceType: 'efficacy',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isDeleted: false,
    );

Plot _plot({
  required int id,
  int? armPlotNumber,
  String plotId = '101',
}) =>
    Plot(
      id: id,
      trialId: 1,
      plotId: plotId,
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: false,
      armPlotNumber: armPlotNumber,
    );

Treatment _treatment({required int id, String code = '1', String name = 'T'}) =>
    Treatment(
      id: id,
      trialId: 1,
      code: code,
      name: name,
      isDeleted: false,
    );

Assignment _assignment({
  required int id,
  required int plotId,
  int? treatmentId,
}) =>
    Assignment(
      id: id,
      trialId: 1,
      plotId: plotId,
      treatmentId: treatmentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Photo _photo({required DateTime createdAt, int plotPk = 1}) => Photo(
      id: 1,
      trialId: 1,
      plotPk: plotPk,
      sessionId: 1,
      filePath: '/tmp/x.jpg',
      status: 'final',
      createdAt: createdAt,
      isDeleted: false,
    );

void main() {
  group('sanitizeTrialNameForPhotoExport', () {
    test('replaces invalid characters and spaces', () {
      expect(
        sanitizeTrialNameForPhotoExport('Ag Quest/Demo:Trial'),
        'Ag_Quest_Demo_Trial',
      );
    });

    test('empty after sanitizing becomes Trial', () {
      expect(sanitizeTrialNameForPhotoExport('///'), 'Trial');
      expect(sanitizeTrialNameForPhotoExport('   '), 'Trial');
    });
  });

  group('formatTreatmentSegmentForPhotoExport', () {
    test('no assignment yields T0000', () {
      expect(
        formatTreatmentSegmentForPhotoExport(null, _treatment(id: 1)),
        'T0000',
      );
    });

    test('pads first digit run from code to 4 digits', () {
      final a = _assignment(id: 1, plotId: 1, treatmentId: 1);
      expect(
        formatTreatmentSegmentForPhotoExport(a, _treatment(id: 1, code: '1')),
        'T0001',
      );
      expect(
        formatTreatmentSegmentForPhotoExport(a, _treatment(id: 1, code: 'T12')),
        'T0012',
      );
    });

    test('non-numeric code yields T0000', () {
      final a = _assignment(id: 1, plotId: 1, treatmentId: 1);
      expect(
        formatTreatmentSegmentForPhotoExport(
            a, _treatment(id: 1, code: 'ABC')),
        'T0000',
      );
    });
  });

  group('formatPlotSegmentForPhotoExport', () {
    test('null plot is P000', () {
      expect(formatPlotSegmentForPhotoExport(null), 'P000');
    });

    test('prefers armPlotNumber over plotId label', () {
      expect(
        formatPlotSegmentForPhotoExport(
            _plot(id: 1, armPlotNumber: 101, plotId: 'X9')),
        'P101',
      );
    });

    test('uses sanitized plotId when armPlotNumber null', () {
      expect(
        formatPlotSegmentForPhotoExport(
            _plot(id: 1, plotId: '101a/b')),
        'P101a_b',
      );
    });
  });

  group('buildPhotoExportFileName', () {
    test('matches standard example shape', () {
      final trial = _trial(id: 1, name: 'AgQuestDemoTrial');
      final plot = _plot(id: 10, armPlotNumber: 101);
      final trt = _treatment(id: 5, code: '1');
      final asg = _assignment(id: 1, plotId: 10, treatmentId: 5);
      final photo = _photo(createdAt: DateTime(2026, 4, 6, 15, 30));

      expect(
        buildPhotoExportFileName(
          photo: photo,
          trial: trial,
          plot: plot,
          assignment: asg,
          treatment: trt,
          sequenceNumber: 0,
        ),
        'AgQuestDemoTrial_T0001_Apr-6-2026_P101.jpg',
      );
    });

    test('appends sequence suffix when sequenceNumber > 0', () {
      final trial = _trial(id: 1, name: 'AgQuestDemoTrial');
      final plot = _plot(id: 10, armPlotNumber: 101);
      final trt = _treatment(id: 5, code: '1');
      final asg = _assignment(id: 1, plotId: 10, treatmentId: 5);
      final photo = _photo(createdAt: DateTime(2026, 4, 6));

      expect(
        buildPhotoExportFileName(
          photo: photo,
          trial: trial,
          plot: plot,
          assignment: asg,
          treatment: trt,
          sequenceNumber: 1,
        ),
        'AgQuestDemoTrial_T0001_Apr-6-2026_P101_01.jpg',
      );
      expect(
        buildPhotoExportFileName(
          photo: photo,
          trial: trial,
          plot: plot,
          assignment: asg,
          treatment: trt,
          sequenceNumber: 2,
        ),
        'AgQuestDemoTrial_T0001_Apr-6-2026_P101_02.jpg',
      );
    });

    test('no assignment uses T0000', () {
      final trial = _trial(id: 1, name: 'Demo');
      final plot = _plot(id: 10, armPlotNumber: 7);
      final photo = _photo(createdAt: DateTime(2026, 1, 1));

      expect(
        buildPhotoExportFileName(
          photo: photo,
          trial: trial,
          plot: plot,
          assignment: null,
          treatment: _treatment(id: 1, code: '99'),
          sequenceNumber: 0,
        ),
        'Demo_T0000_Jan-1-2026_P7.jpg',
      );
    });

    test('null plot uses P000', () {
      final trial = _trial(id: 1, name: 'Demo');
      final photo = _photo(createdAt: DateTime(2026, 6, 15));

      expect(
        buildPhotoExportFileName(
          photo: photo,
          trial: trial,
          plot: null,
          assignment: null,
          treatment: null,
          sequenceNumber: 0,
        ),
        'Demo_T0000_Jun-15-2026_P000.jpg',
      );
    });
  });
}
