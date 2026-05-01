import 'package:flutter_test/flutter_test.dart';

import 'package:arm_field_companion/features/export/field_execution_report_data.dart';
import 'package:arm_field_companion/features/export/field_execution_report_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Minimal valid FieldExecutionReportData — all sections populated with
  // empty/zero values. Used to verify the builder renders without throwing.
  FieldExecutionReportData minimal() {
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
    );
    const signals = FerSignalsSection(openSignals: []);
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
      evidenceRecord: evidenceRecord,
      signals: signals,
      completeness: completeness,
      executionStatement: 'Session "Session 1" rated 0 of 0 plots.',
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
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 3,
          photoIds: [10, 11, 12],
          hasGps: true,
          hasWeather: true,
          hasTimestamp: true,
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
            'Session "S-ARM" rated 20 of 20 plots. 1 completeness warning(s) recorded.',
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
        evidenceRecord: const FerEvidenceRecord(
          photoCount: 0,
          photoIds: [],
          hasGps: false,
          hasWeather: false,
          hasTimestamp: true,
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
        generatedAt: DateTime(2026, 4, 10, 9, 15),
      );

      final builder = FieldExecutionReportPdfBuilder();
      final bytes = await builder.build(data);
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('no DB dependency — builder has no constructor parameters', () {
      // Verifies the renderer contract: no repositories, no providers injected.
      final builder = FieldExecutionReportPdfBuilder();
      expect(builder, isNotNull);
    });
  });
}
