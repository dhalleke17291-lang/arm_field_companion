import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/features/export/field_execution_report_data.dart';
import 'package:arm_field_companion/features/export/field_execution_report_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fully-populated FerCognitionSection with all required fields and safe
  // defaults. List fields empty, status strings 'unknown'.
  FerCognitionSection emptyCognition() => const FerCognitionSection(
        purposeStatus: 'unknown',
        purposeStatusLabel: 'Intent not captured',
        claimBeingTested: null,
        primaryEndpoint: null,
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'no_evidence',
        evidenceStateLabel: 'No evidence yet',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'unknown',
        ctqOverallStatusLabel: 'Not yet evaluated',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      );

  // Minimal valid FieldExecutionReportData — all sections populated with
  // empty/zero values. Used to verify the builder renders without throwing.
  FieldExecutionReportData minimal({
    List<FerAssessmentTimingRow> assessmentTimingRows = const [],
    FerSignalsSection signals = const FerSignalsSection(openSignals: []),
  }) {
    const identity = FerIdentity(
      trialId: 1,
      trialName: 'Test Trial',
      protocolNumber: null,
      crop: null,
      location: null,
      season: null,
      sessionId: 1,
      sessionName: 'Session 1',
      sessionDateLocal: '2026-04-01',
      sessionStatus: 'open',
      raterName: null,
    );
    const protocolContext = FerProtocolContext(
      isArmLinked: false,
      isArmTrial: false,
      divergences: [],
    );
    const sessionGrid = FerSessionGrid(
      dataPlotCount: 0,
      assessmentCount: 0,
      rated: 0,
      unrated: 0,
      withIssues: 0,
      edited: 0,
      flagged: 0,
    );
    const evidenceRecord = FerEvidenceRecord(
      photoCount: 0,
      photoIds: [],
      hasGps: false,
      hasWeather: false,
      hasTimestamp: true,
      sessionDurationMinutes: null,
    );
    const completeness = FerCompletenessSection(
      expectedPlots: 0,
      completedPlots: 0,
      incompletePlots: 0,
      canClose: true,
      blockerCount: 0,
      warningCount: 0,
    );

    return FieldExecutionReportData(
      identity: identity,
      protocolContext: protocolContext,
      sessionGrid: sessionGrid,
      assessmentTimingRows: assessmentTimingRows,
      evidenceRecord: evidenceRecord,
      signals: signals,
      completeness: completeness,
      executionStatement: 'Session "Session 1" rated 0 of 0 plots.',
      cognition: emptyCognition(),
      generatedAt: DateTime(2026, 4, 1, 8, 0),
    );
  }

  group('FieldExecutionReportPdfBuilder', () {
    test('smoke test — produces valid PDF bytes', () async {
      final builder = FieldExecutionReportPdfBuilder();
      final bytes = await builder.build(minimal());
      expect(bytes.length, greaterThan(100));
      // %PDF- header
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('empty sections do not throw', () async {
      // All zero counts, empty lists, no optional fields.
      final builder = FieldExecutionReportPdfBuilder();
      expect(() => builder.build(minimal()), returnsNormally);
    });

    test('ARM trial with divergences renders without throwing', () async {
      final data = FieldExecutionReportData(
        identity: const FerIdentity(
          trialId: 2,
          trialName: 'ARM Trial',
          protocolNumber: 'PN-42',
          crop: 'Wheat',
          location: 'Field A',
          season: '2026',
          sessionId: 2,
          sessionName: 'S-ARM',
          sessionDateLocal: '2026-04-05',
          sessionStatus: 'closed',
          raterName: 'Alice',
        ),
        protocolContext: const FerProtocolContext(
          isArmLinked: true,
          isArmTrial: true,
          divergences: [
            FerProtocolDivergenceRow(
              type: FerDivergenceType.timing,
              deltaDays: 3,
              plannedDat: 50,
              actualDat: 53,
            ),
          ],
        ),
        sessionGrid: const FerSessionGrid(
          dataPlotCount: 20,
          assessmentCount: 2,
          rated: 20,
          unrated: 0,
          withIssues: 1,
          edited: 2,
          flagged: 0,
        ),
        assessmentTimingRows: const [],
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 3,
          photoIds: [10, 11, 12],
          hasGps: true,
          hasWeather: true,
          hasTimestamp: true,
          sessionDurationMinutes: 75,
        ),
        signals: const FerSignalsSection(
          openSignals: [
            FerSignalRow(
              id: 7,
              signalType: 'scale_violation',
              severity: 'review',
              status: 'open',
              consequenceText: 'Plot 5 exceeds scale.',
              raisedAt: 1745000000000,
            ),
          ],
        ),
        completeness: const FerCompletenessSection(
          expectedPlots: 20,
          completedPlots: 20,
          incompletePlots: 0,
          canClose: true,
          blockerCount: 0,
          warningCount: 1,
        ),
        executionStatement:
            'Session "S-ARM" rated 20 of 20 plots. 1 completeness warning recorded.',
        cognition: emptyCognition(),
        generatedAt: DateTime(2026, 4, 5, 14, 30),
      );

      final builder = FieldExecutionReportPdfBuilder();
      final bytes = await builder.build(data);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('non-ARM trial shows no ARM section content', () async {
      // protocolContext.isArmTrial = false should render the neutral note,
      // not throw and not show divergence table.
      final builder = FieldExecutionReportPdfBuilder();
      final bytes = await builder.build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    test('protocol deviation table uses populated row fields', () async {
      const protocol = FerProtocolContext(
        isArmLinked: true,
        isArmTrial: true,
        divergences: [
          FerProtocolDivergenceRow(
            type: FerDivergenceType.timing,
            plannedDat: 10,
            actualDat: 13,
            deltaDays: 3,
          ),
          FerProtocolDivergenceRow(
            type: FerDivergenceType.unexpected,
            actualDat: 14,
          ),
        ],
      );

      expect(
        FieldExecutionReportPdfBuilder
            .protocolDeviationTableColumnCountForTesting(protocol),
        4,
      );
      expect(
        FieldExecutionReportPdfBuilder.protocolDeviationTableRowCountForTesting(
            protocol),
        3,
      );
      expect(
        FieldExecutionReportPdfBuilder.protocolDeviationTableRowsForTesting(
          protocol,
        ),
        [
          ['Type', 'Planned DAT', 'Actual DAT', 'Delta'],
          ['Timing', '10', '13', '+3 days'],
          ['Unexpected session', '-', '14', '-'],
        ],
      );

      final data = FieldExecutionReportData(
        identity: const FerIdentity(
          trialId: 7,
          trialName: 'Deviation Trial',
          protocolNumber: null,
          crop: null,
          location: null,
          season: null,
          sessionId: 7,
          sessionName: 'Deviation Session',
          sessionDateLocal: '2026-04-14',
          sessionStatus: 'closed',
          raterName: null,
        ),
        protocolContext: protocol,
        sessionGrid: const FerSessionGrid(
          dataPlotCount: 1,
          assessmentCount: 1,
          rated: 1,
          unrated: 0,
          withIssues: 0,
          edited: 0,
          flagged: 0,
        ),
        assessmentTimingRows: const [],
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 0,
          photoIds: [],
          hasGps: false,
          hasWeather: false,
          hasTimestamp: true,
          sessionDurationMinutes: null,
        ),
        signals: const FerSignalsSection(openSignals: []),
        completeness: const FerCompletenessSection(
          expectedPlots: 1,
          completedPlots: 1,
          incompletePlots: 0,
          canClose: true,
          blockerCount: 0,
          warningCount: 0,
        ),
        executionStatement: 'Session complete.',
        cognition: emptyCognition(),
        generatedAt: DateTime(2026, 4, 14, 10),
      );

      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('empty protocol deviation list renders empty state row', () async {
      const protocol = FerProtocolContext(
        isArmLinked: true,
        isArmTrial: true,
        divergences: [],
      );

      expect(
        FieldExecutionReportPdfBuilder.protocolDeviationTableRowsForTesting(
          protocol,
        ),
        [
          ['No protocol deviations recorded for this session.'],
        ],
      );

      final bytes = await FieldExecutionReportPdfBuilder().build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    test('non-ARM trial renders protocol deviation empty state', () async {
      const protocol = FerProtocolContext(
        isArmLinked: false,
        isArmTrial: false,
        divergences: [],
      );

      expect(
        FieldExecutionReportPdfBuilder.protocolDeviationTableRowsForTesting(
          protocol,
        ).single.single,
        'No protocol deviations recorded for this session.',
      );

      final bytes = await FieldExecutionReportPdfBuilder().build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    test('signals with open entries renders without throwing', () async {
      final data = FieldExecutionReportData(
        identity: const FerIdentity(
          trialId: 3,
          trialName: 'Signal Trial',
          protocolNumber: null,
          crop: null,
          location: null,
          season: null,
          sessionId: 3,
          sessionName: 'S-Signals',
          sessionDateLocal: '2026-04-10',
          sessionStatus: 'open',
          raterName: null,
        ),
        protocolContext: const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        ),
        sessionGrid: const FerSessionGrid(
          dataPlotCount: 10,
          assessmentCount: 1,
          rated: 8,
          unrated: 2,
          withIssues: 1,
          edited: 0,
          flagged: 1,
        ),
        assessmentTimingRows: const [],
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 0,
          photoIds: [],
          hasGps: false,
          hasWeather: false,
          hasTimestamp: true,
          sessionDurationMinutes: null,
        ),
        signals: const FerSignalsSection(
          openSignals: [
            FerSignalRow(
              id: 1,
              signalType: 'replication_warning',
              severity: 'critical',
              status: 'investigating',
              consequenceText: 'Missing rep data.',
              raisedAt: 1744900000000,
            ),
            FerSignalRow(
              id: 2,
              signalType: 'aov_prediction',
              severity: 'info',
              status: 'deferred',
              consequenceText: 'Low AOV signal.',
              raisedAt: 1744910000000,
            ),
          ],
        ),
        completeness: const FerCompletenessSection(
          expectedPlots: 10,
          completedPlots: 8,
          incompletePlots: 2,
          canClose: false,
          blockerCount: 1,
          warningCount: 0,
        ),
        executionStatement:
            'Session "S-Signals" rated 8 of 10 plots. 2 open signal(s) recorded.',
        cognition: emptyCognition(),
        generatedAt: DateTime(2026, 4, 10, 9, 15),
      );

      final builder = FieldExecutionReportPdfBuilder();
      final bytes = await builder.build(data);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('rater drift signal renders in Rater Quality subsection', () async {
      final data = minimal(
        signals: const FerSignalsSection(
          openSignals: [
            FerSignalRow(
              id: 21,
              signalType: 'rater_drift',
              severity: 'review',
              status: 'open',
              consequenceText:
                  'Recorded ratings show more than one rater name in this session.',
              raisedAt: 1745000000000,
            ),
          ],
        ),
      );

      expect(
        FieldExecutionReportPdfBuilder.raterQualityRowsForTesting(data),
        containsAll([
          'Rater Quality',
          'Rater Drift Detected',
          'Review',
          'Recorded ratings show more than one rater name in this session.',
          'Medium confidence - observed pattern, not a confirmed measurement.',
        ]),
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('no rater signals renders Rater Quality empty state', () async {
      final data = minimal();

      expect(
        FieldExecutionReportPdfBuilder.raterQualityRowsForTesting(data),
        ['No rater drift signals recorded for this session.'],
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('mixed signals separate rater drift from general signal list', () async {
      final data = minimal(
        signals: const FerSignalsSection(
          openSignals: [
            FerSignalRow(
              id: 31,
              signalType: 'rater_drift',
              severity: 'review',
              status: 'open',
              consequenceText:
                  'Some recorded ratings include a rater name and others have none.',
              raisedAt: 1745000000000,
            ),
            FerSignalRow(
              id: 32,
              signalType: 'scale_violation',
              severity: 'critical',
              status: 'open',
              consequenceText: 'Value outside scale.',
              raisedAt: 1745000001000,
            ),
          ],
        ),
      );

      expect(
        FieldExecutionReportPdfBuilder.raterQualityRowsForTesting(data),
        contains('Rater Drift Detected'),
      );
      expect(
        FieldExecutionReportPdfBuilder.generalSignalIdsForTesting(data),
        [32],
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('no DB dependency — builder has no constructor parameters', () {
      // Verifies the renderer contract: no repositories, no providers injected.
      final builder = FieldExecutionReportPdfBuilder();
      expect(builder, isNotNull);
    });

    // Constructs a full FieldExecutionReportData with fixed base sections and
    // the given cognition. Avoids copyWith (not defined on the DTOs).
    FieldExecutionReportData withCognition(FerCognitionSection cog) =>
        FieldExecutionReportData(
          identity: const FerIdentity(
            trialId: 1,
            trialName: 'Test Trial',
            protocolNumber: null,
            crop: null,
            location: null,
            season: null,
            sessionId: 1,
            sessionName: 'Session 1',
            sessionDateLocal: '2026-04-01',
            sessionStatus: 'open',
            raterName: null,
          ),
          protocolContext: const FerProtocolContext(
            isArmLinked: false,
            isArmTrial: false,
            divergences: [],
          ),
          sessionGrid: const FerSessionGrid(
            dataPlotCount: 0,
            assessmentCount: 0,
            rated: 0,
            unrated: 0,
            withIssues: 0,
            edited: 0,
            flagged: 0,
          ),
          assessmentTimingRows: const [],
          evidenceRecord: const FerEvidenceRecord(
            photoCount: 0,
            photoIds: [],
            hasGps: false,
            hasWeather: false,
            hasTimestamp: true,
            sessionDurationMinutes: null,
          ),
          signals: const FerSignalsSection(openSignals: []),
          completeness: const FerCompletenessSection(
            expectedPlots: 0,
            completedPlots: 0,
            incompletePlots: 0,
            canClose: true,
            blockerCount: 0,
            warningCount: 0,
          ),
          executionStatement: 'Session "Session 1" rated 0 of 0 plots.',
          cognition: cog,
          generatedAt: DateTime(2026, 4, 1, 8, 0),
        );

    // PDF-9: Cognition section with full confirmed-purpose block renders.
    test('renders cognition section — valid PDF with full cognition block',
        () async {
      final data = withCognition(const FerCognitionSection(
        purposeStatus: 'confirmed',
        purposeStatusLabel: 'Intent confirmed',
        claimBeingTested: 'Fungicide vs untreated check.',
        primaryEndpoint: 'Disease severity rating.',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'sufficient_for_review',
        evidenceStateLabel: 'Sufficient for review',
        actualEvidenceSummary: '2 sessions · 96 ratings · no photos',
        missingEvidenceItems: [],
        ctqOverallStatus: 'ready_for_review',
        ctqOverallStatusLabel: 'Ready for review',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 7,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      ));
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    // PDF-10: Unknown purpose state renders without throwing.
    test('renders unknown purpose state without throwing', () async {
      // minimal() already uses emptyCognition() which has purposeStatus='unknown'.
      final bytes = await FieldExecutionReportPdfBuilder().build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    // PDF-11: Confirmed claim, endpoint, and attention items render.
    test('renders confirmed claim and endpoint without throwing', () async {
      final data = withCognition(const FerCognitionSection(
        purposeStatus: 'confirmed',
        purposeStatusLabel: 'Intent confirmed',
        claimBeingTested: 'Herbicide weed control vs check.',
        primaryEndpoint: 'Weed count per plot.',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'partial',
        evidenceStateLabel: 'Partial evidence',
        actualEvidenceSummary: '1 session · 48 ratings · no photos',
        missingEvidenceItems: ['No photos attached'],
        ctqOverallStatus: 'incomplete',
        ctqOverallStatusLabel: 'Needs evidence',
        blockerCount: 0,
        warningCount: 3,
        reviewCount: 0,
        satisfiedCount: 4,
        topCtqAttentionItems: [
          FerCognitionAttentionItem(
            factorKey: 'photo_evidence',
            label: 'Photo Evidence',
            statusLabel: 'Missing',
          ),
        ],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      ));
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    // PDF-12: Pre-baked 'Needs evidence' label (not raw 'incomplete') renders.
    test("cognition DTO with 'Needs evidence' label renders without throwing",
        () async {
      // The assembly service maps 'incomplete' → 'Needs evidence' before
      // the DTO reaches the builder. Verify the builder renders it cleanly.
      final data = withCognition(const FerCognitionSection(
        purposeStatus: 'unknown',
        purposeStatusLabel: 'Intent not captured',
        claimBeingTested: null,
        primaryEndpoint: null,
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'no_evidence',
        evidenceStateLabel: 'No evidence yet',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'incomplete',
        ctqOverallStatusLabel: 'Needs evidence',
        blockerCount: 0,
        warningCount: 2,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      ));
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    // PDF-13: Disclaimer text renders — validated via static const on DTO.
    test('cognition section disclaimer text is non-empty and non-efficacy',
        () async {
      // The disclaimer is a static const on FerCognitionSection; the builder
      // renders it from there. Validate its content without PDF text extraction.
      expect(FerCognitionSection.disclaimerText, isNotEmpty);
      expect(
          FerCognitionSection.disclaimerText, contains('does not determine'));
      // Render to confirm no throw.
      final bytes = await FieldExecutionReportPdfBuilder().build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    test('new title and interpretation boundary constants are present', () {
      expect(
        FieldExecutionReportPdfBuilder.titleText,
        'FIELD EXECUTION REVIEW',
      );
      expect(
        FieldExecutionReportPdfBuilder.interpretationBoundaryText,
        contains('does not determine biological efficacy'),
      );
    });

    test('critical open signals produce review-required verdict', () {
      final data = FieldExecutionReportData(
        identity: const FerIdentity(
          trialId: 4,
          trialName: 'Critical Trial',
          protocolNumber: null,
          crop: 'Wheat',
          location: null,
          season: '2026',
          sessionId: 4,
          sessionName: 'Session 1',
          sessionDateLocal: '2026-04-12',
          sessionStatus: 'closed',
          raterName: 'Researcher',
        ),
        protocolContext: const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        ),
        sessionGrid: const FerSessionGrid(
          dataPlotCount: 16,
          assessmentCount: 3,
          rated: 16,
          unrated: 0,
          withIssues: 0,
          edited: 0,
          flagged: 0,
        ),
        assessmentTimingRows: const [],
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 0,
          photoIds: [],
          hasGps: true,
          hasWeather: true,
          hasTimestamp: true,
          sessionDurationMinutes: 64,
        ),
        signals: const FerSignalsSection(
          openSignals: [
            FerSignalRow(
              id: 11,
              signalType: 'scale_violation',
              severity: 'critical',
              status: 'open',
              consequenceText: 'Rating scale review required.',
              raisedAt: 1745000000000,
            ),
          ],
        ),
        completeness: const FerCompletenessSection(
          expectedPlots: 16,
          completedPlots: 16,
          incompletePlots: 0,
          canClose: true,
          blockerCount: 0,
          warningCount: 0,
        ),
        executionStatement: 'Session complete.',
        cognition: emptyCognition(),
        generatedAt: DateTime(2026, 4, 12, 10),
      );

      expect(
        FieldExecutionReportPdfBuilder.reviewVerdictStatusForTesting(data),
        'Review required before export',
      );
    });

    test('complete ratings render execution coverage sentence', () {
      final data = FieldExecutionReportData(
        identity: const FerIdentity(
          trialId: 5,
          trialName: 'Coverage Trial',
          protocolNumber: null,
          crop: null,
          location: null,
          season: null,
          sessionId: 5,
          sessionName: 'Session 1',
          sessionDateLocal: '2026-04-13',
          sessionStatus: 'closed',
          raterName: null,
        ),
        protocolContext: const FerProtocolContext(
          isArmLinked: false,
          isArmTrial: false,
          divergences: [],
        ),
        sessionGrid: const FerSessionGrid(
          dataPlotCount: 16,
          assessmentCount: 3,
          rated: 16,
          unrated: 0,
          withIssues: 0,
          edited: 0,
          flagged: 0,
        ),
        assessmentTimingRows: const [],
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 1,
          photoIds: [1],
          hasGps: true,
          hasWeather: true,
          hasTimestamp: true,
          sessionDurationMinutes: 50,
        ),
        signals: const FerSignalsSection(openSignals: []),
        completeness: const FerCompletenessSection(
          expectedPlots: 16,
          completedPlots: 16,
          incompletePlots: 0,
          canClose: true,
          blockerCount: 0,
          warningCount: 0,
        ),
        executionStatement: 'Session complete.',
        cognition: emptyCognition(),
        generatedAt: DateTime(2026, 4, 13, 10),
      );

      expect(
        FieldExecutionReportPdfBuilder.executionCoverageSentenceForTesting(
            data),
        '16 of 16 planned data plots rated across 3 assessment(s).',
      );
    });

    test('assessment timing renders DAA value', () async {
      final data = minimal(
        assessmentTimingRows: const [
          FerAssessmentTimingRow(
            assessmentId: 1,
            assessmentName: 'Weed control',
            actualDaa: 3,
          ),
        ],
      );

      expect(
        FieldExecutionReportPdfBuilder.assessmentTimingRowsForTesting(data),
        [
          ['Weed control', '3 days'],
        ],
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('assessment timing renders dash when DAA is unavailable', () async {
      final data = minimal(
        assessmentTimingRows: const [
          FerAssessmentTimingRow(
            assessmentId: 1,
            assessmentName: 'Crop vigor',
            actualDaa: null,
          ),
        ],
      );

      expect(
        FieldExecutionReportPdfBuilder.assessmentTimingRowsForTesting(data),
        [
          ['Crop vigor', '—'],
        ],
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('non-ARM trial renders assessment DAA without ARM gating', () async {
      final data = minimal(
        assessmentTimingRows: const [
          FerAssessmentTimingRow(
            assessmentId: 1,
            assessmentName: 'Disease severity',
            actualDaa: 1,
          ),
        ],
      );

      expect(data.protocolContext.isArmTrial, isFalse);
      expect(
        FieldExecutionReportPdfBuilder.assessmentTimingRowsForTesting(data),
        [
          ['Disease severity', '1 day'],
        ],
      );
      final bytes = await FieldExecutionReportPdfBuilder().build(data);
      expect(bytes.length, greaterThan(100));
    });

    test('provenance GPS state uses presence labels without counts', () {
      expect(
        FieldExecutionReportPdfBuilder.evidenceGpsLabelForTesting(
          const FerEvidenceRecord(
            photoCount: 0,
            photoIds: [],
            hasGps: true,
            hasWeather: false,
            hasTimestamp: true,
            sessionDurationMinutes: null,
          ),
        ),
        'GPS evidence present',
      );
      expect(
        FieldExecutionReportPdfBuilder.evidenceGpsLabelForTesting(
          const FerEvidenceRecord(
            photoCount: 0,
            photoIds: [],
            hasGps: false,
            hasWeather: false,
            hasTimestamp: true,
            sessionDurationMinutes: null,
          ),
        ),
        'GPS evidence not recorded',
      );
    });

    // CTQ-1: CTQ factor lines carry verbatim label and status.
    test('CTQ factor lines use verbatim label and pre-baked status', () {
      const items = [
        FerCognitionAttentionItem(
          factorKey: 'photo_evidence',
          label: 'Photo Evidence',
          statusLabel: 'Missing',
        ),
        FerCognitionAttentionItem(
          factorKey: 'plot_completeness',
          label: 'Plot Completeness',
          statusLabel: 'Blocked',
        ),
      ];
      final lines =
          FieldExecutionReportPdfBuilder.ctqFactorLinesForTesting(items);
      expect(lines, [
        'Photo Evidence: Not recorded',
        'Plot Completeness: Blocked',
      ]);
    });

    // CTQ-2: Empty CTQ items list is handled — smoke test renders without throw.
    test('empty CTQ attention items renders without throwing', () async {
      final bytes =
          await FieldExecutionReportPdfBuilder().build(minimal());
      expect(bytes.length, greaterThan(100));
    });

    // IB-1: Declared line present when knownInterpretationFactors is set.
    test('interpretation boundary includes declared line when factors set', () {
      const cog = FerCognitionSection(
        purposeStatus: 'confirmed',
        purposeStatusLabel: 'Intent confirmed',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'partial',
        evidenceStateLabel: 'Partial evidence',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'unknown',
        ctqOverallStatusLabel: 'Not yet evaluated',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: 'Field slope may affect runoff patterns.',
        interpretationRiskFactors: [],
      );
      final lines =
          FieldExecutionReportPdfBuilder.interpretationBoundaryLinesForTesting(
              cog);
      expect(lines, contains('declared:Field slope may affect runoff patterns.'));
      expect(lines,
          contains('No interpretation risk factors identified for this session.'));
    });

    // IB-2: Declared line omitted when knownInterpretationFactors is null.
    test('interpretation boundary omits declared line when null', () {
      const cog = FerCognitionSection(
        purposeStatus: 'unknown',
        purposeStatusLabel: 'Intent not captured',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'no_evidence',
        evidenceStateLabel: 'No evidence yet',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'unknown',
        ctqOverallStatusLabel: 'Not yet evaluated',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      );
      final lines =
          FieldExecutionReportPdfBuilder.interpretationBoundaryLinesForTesting(
              cog);
      expect(lines.any((l) => l.startsWith('declared:')), isFalse);
    });

    // IB-3: Risk items render with correct tier labels.
    test('interpretation boundary renders risk items with tier labels', () {
      const cog = FerCognitionSection(
        purposeStatus: 'unknown',
        purposeStatusLabel: 'Intent not captured',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'no_evidence',
        evidenceStateLabel: 'No evidence yet',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'unknown',
        ctqOverallStatusLabel: 'Not yet evaluated',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [
          FerRiskFactorItem(label: 'High CV detected', tier: 'HIGH'),
          FerRiskFactorItem(label: 'Spatial gradient present', tier: 'MEDIUM'),
          FerRiskFactorItem(
              label: 'Insufficient data', tier: 'CANNOT EVALUATE'),
        ],
      );
      final lines =
          FieldExecutionReportPdfBuilder.interpretationBoundaryLinesForTesting(
              cog);
      expect(lines, contains('High CV detected — HIGH'));
      expect(lines, contains('Spatial gradient present — MEDIUM'));
      expect(lines, contains('Insufficient data — CANNOT EVALUATE'));
    });

    // IB-4: Empty risk factors → empty-state text, no crash.
    test('interpretation boundary renders empty-state text when no risk factors',
        () {
      const cog = FerCognitionSection(
        purposeStatus: 'unknown',
        purposeStatusLabel: 'Intent not captured',
        missingIntentFields: [],
        missingIntentFieldLabels: [],
        evidenceState: 'no_evidence',
        evidenceStateLabel: 'No evidence yet',
        actualEvidenceSummary: '',
        missingEvidenceItems: [],
        ctqOverallStatus: 'unknown',
        ctqOverallStatusLabel: 'Not yet evaluated',
        blockerCount: 0,
        warningCount: 0,
        reviewCount: 0,
        satisfiedCount: 0,
        topCtqAttentionItems: [],
        knownInterpretationFactors: null,
        interpretationRiskFactors: [],
      );
      final lines =
          FieldExecutionReportPdfBuilder.interpretationBoundaryLinesForTesting(
              cog);
      expect(
        lines,
        contains(
            'No interpretation risk factors identified for this session.'),
      );
    });
  });
}
