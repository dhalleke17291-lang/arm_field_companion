import 'package:arm_field_companion/features/export/evidence_report_data.dart';
import 'package:arm_field_companion/features/export/evidence_report_pdf_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceReportPdfBuilder rater quality', () {
    test('detected rater drift renders severity and truncated note', () async {
      const longConsequence =
          'Variability noted during session close review for this rater and should be reviewed alongside field notes before relying on the session.';
      const rater = EvidenceRater(
        name: 'Alice',
        ratingCount: 12,
        sessionNames: ['S1'],
        raterDriftDetected: true,
        driftSeverity: 'review',
        driftConsequence: longConsequence,
      );

      expect(
        EvidenceReportPdfBuilder.raterDriftLabelForTesting(rater),
        'review',
      );
      final note = EvidenceReportPdfBuilder.raterDriftNoteForTesting(rater);
      expect(note.length, 80);
      expect(note.endsWith('...'), isTrue);

      final bytes =
          await EvidenceReportPdfBuilder().build(_report(raters: [rater]));
      expect(bytes, isNotEmpty);
    });

    test('no rater drift renders none detected and dash note', () async {
      const rater = EvidenceRater(
        name: 'Bob',
        ratingCount: 8,
        sessionNames: ['S1'],
        raterDriftDetected: false,
      );

      expect(
        EvidenceReportPdfBuilder.raterDriftLabelForTesting(rater),
        'None detected',
      );
      expect(EvidenceReportPdfBuilder.raterDriftNoteForTesting(rater), '—');

      final bytes =
          await EvidenceReportPdfBuilder().build(_report(raters: [rater]));
      expect(bytes, isNotEmpty);
    });
  });

  group('EvidenceReportPdfBuilder raw data appendix', () {
    test('populated rawDataRows produce eight columns and one row', () async {
      const rows = [
        EvidenceRawDataRow(
          sessionName: 'S1',
          plotCode: '101',
          rep: 1,
          treatmentCode: 'T1',
          assessmentName: 'Weed control',
          ratingValue: 87.5,
          dat: 4,
          raterName: 'Alice',
        ),
      ];

      expect(EvidenceReportPdfBuilder.rawDataHeadersForTesting(), hasLength(8));
      expect(EvidenceReportPdfBuilder.rawDataRowsForTesting(rows), [
        ['S1', '101', '1', 'T1', 'Weed control', '87.50', 'DAT+4', 'Alice'],
      ]);
      final bytes = await EvidenceReportPdfBuilder().build(_report(rawRows: rows));
      expect(bytes, isNotEmpty);
    });

    test('empty rawDataRows render empty appendix without throwing', () async {
      expect(EvidenceReportPdfBuilder.rawDataRowsForTesting(const []), isEmpty);
      final bytes = await EvidenceReportPdfBuilder().build(_report());
      expect(bytes, isNotEmpty);
    });

    test('truncation warning renders total count', () async {
      final data = _report(rawDataTruncated: true, rawDataTotalCount: 2001);
      expect(
        EvidenceReportPdfBuilder.rawDataTruncationWarningForTesting(data),
        'This trial contains 2001 rating records. This appendix shows the first 2,000 rows. Export Raw CSV Data for the complete record.',
      );
      final bytes = await EvidenceReportPdfBuilder().build(data);
      expect(bytes, isNotEmpty);
    });

    test('null rating value and DAT render dash values', () async {
      const rows = [
        EvidenceRawDataRow(
          sessionName: 'S1',
          plotCode: '101',
          rep: 1,
          treatmentCode: 'T1',
          assessmentName: 'Crop vigor',
          ratingValue: null,
          dat: null,
          raterName: null,
        ),
      ];

      expect(EvidenceReportPdfBuilder.rawDataRowsForTesting(rows).single, [
        'S1',
        '101',
        '1',
        'T1',
        'Crop vigor',
        '—',
        '—',
        '—',
      ]);
      final bytes = await EvidenceReportPdfBuilder().build(_report(rawRows: rows));
      expect(bytes, isNotEmpty);
    });

    test('outlier section receives resolved assessment name', () async {
      final data = _report(
        outliers: const [
          EvidenceOutlier(
            plotLabel: '101',
            treatmentCode: 'T1',
            rep: 1,
            assessmentName: 'Weed control',
            value: 99,
            treatmentMean: 75,
            sdFromMean: 2.2,
            confidence: 'certain',
            wasAmended: false,
          ),
        ],
      );

      expect(data.outliers.single.assessmentName, 'Weed control');
      expect(data.outliers.single.assessmentName, isNot('Assessment 1'));
      final bytes = await EvidenceReportPdfBuilder().build(data);
      expect(bytes, isNotEmpty);
    });
  });
}

EvidenceReportData _report({
  List<EvidenceRater> raters = const [],
  List<EvidenceRawDataRow> rawRows = const [],
  bool rawDataTruncated = false,
  int? rawDataTotalCount,
  List<EvidenceOutlier> outliers = const [],
}) {
  return EvidenceReportData(
    identity: const EvidenceTrialIdentity(
      name: 'Wheat 2026',
      status: 'active',
      workspaceType: 'standalone',
    ),
    timeline: const [],
    treatments: const [],
    applications: const [],
    sessions: const [],
    integrity: EvidenceDataIntegrity(
      totalRatings: 0,
      ratingsWithGps: 0,
      ratingsWithConfidence: 0,
      ratingsWithTimestamp: 0,
      amendments: const [],
      corrections: const [],
      statusCounts: const {},
      deviceSummaries: const [],
      raterSummaries: raters,
      sessionTimestampDistributions: const [],
    ),
    outliers: outliers,
    photos: const [],
    weatherRecords: const [],
    rawDataRows: rawRows,
    rawDataTruncated: rawDataTruncated,
    rawDataTotalCount: rawDataTotalCount ?? rawRows.length,
    completenessScore: const EvidenceCompletenessScore(
      totalScore: 0,
      maxScore: 0,
      components: [],
    ),
    generatedAt: DateTime(2026, 5, 10),
    appVersion: '1.0.0',
  );
}
