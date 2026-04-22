import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/domain/models/arm_round_trip_diagnostics.dart';
import 'package:arm_field_companion/features/export/domain/compute_arm_round_trip_diagnostics_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/core/diagnostics/diagnostic_finding.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/arm_trial_metadata_test_utils.dart';

Future<Trial> _armTrialRow(AppDatabase db, int trialId) async {
  await upsertArmTrialMetadataForTest(
    db,
    trialId: trialId,
    isArmLinked: true,
  );
  return (db.select(db.trials)..where((t) => t.id.equals(trialId)))
      .getSingle();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ComputeArmRoundTripDiagnosticsUseCase makeUc() =>
      ComputeArmRoundTripDiagnosticsUseCase(
        db: db,
        plotRepository: PlotRepository(db),
        trialAssessmentRepository: TrialAssessmentRepository(db),
        sessionRepository: SessionRepository(db),
        ratingRepository: RatingRepository(db),
      );

  group('ComputeArmRoundTripDiagnosticsUseCase', () {
    test('returns empty when trial is not ARM-linked', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'S', workspaceType: 'efficacy');
      final trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final r = await makeUc().execute(trial: trial);
      expect(r.diagnostics, isEmpty);
    });

    test('missingArmPlotNumber only for non-guard data plots', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'P', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final dataPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: 'G',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 2,
        isGuardRow: true,
      );
      final trial = await _armTrialRow(db, trialId);
      final r = await makeUc().execute(trial: trial);
      final m = r.diagnostics
          .where((d) => d.code == ArmRoundTripDiagnosticCode.missingArmPlotNumber)
          .toList();
      expect(m, hasLength(1));
      expect(m.single.detail, contains('$dataPk'));
    });

    test('duplicateArmPlotNumber', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'D', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final p1 = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final p2 = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '2',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 2,
      );
      await (db.update(db.plots)..where((p) => p.id.isIn([p1, p2]))).write(
        const PlotsCompanion(armPlotNumber: Value(7)),
      );
      final trial = await _armTrialRow(db, trialId);
      final r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.duplicateArmPlotNumber,
        ),
        true,
      );
      expect(
        r.diagnostics
            .firstWhere(
              (d) => d.code == ArmRoundTripDiagnosticCode.duplicateArmPlotNumber,
            )
            .plotPk,
        p1 < p2 ? p1 : p2,
      );
    });

    test(
      'duplicateArmPlotNumber not emitted when guard shares armPlotNumber with data plot',
      () async {
        final trialId =
            await TrialRepository(db).createTrial(name: 'DG', workspaceType: 'efficacy');
        final trtId = await TreatmentRepository(db).insertTreatment(
          trialId: trialId,
          code: '1',
          name: 'T',
        );
        final guardPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: 'G1-L',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 1,
          isGuardRow: true,
        );
        final dataPk = await PlotRepository(db).insertPlot(
          trialId: trialId,
          plotId: '101',
          rep: 1,
          treatmentId: trtId,
          plotSortIndex: 2,
        );
        await (db.update(db.plots)..where((p) => p.id.isIn([guardPk, dataPk]))).write(
          const PlotsCompanion(armPlotNumber: Value(101)),
        );
        final trial = await _armTrialRow(db, trialId);
        final r = await makeUc().execute(trial: trial);
        expect(
          r.diagnostics.any(
            (d) => d.code == ArmRoundTripDiagnosticCode.duplicateArmPlotNumber,
          ),
          false,
        );
        final g = r.diagnostics
            .where((d) => d.code == ArmRoundTripDiagnosticCode.guardHasArmPlotNumber)
            .toList();
        expect(g, hasLength(1));
        expect(g.single.detail, contains('$guardPk'));
      },
    );

    test('guardHasArmPlotNumber when guard has armPlotNumber set', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'GH', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final guardPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: 'G1-R',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
        isGuardRow: true,
      );
      await (db.update(db.plots)..where((p) => p.id.equals(guardPk))).write(
        const PlotsCompanion(armPlotNumber: Value(999)),
      );
      final trial = await _armTrialRow(db, trialId);
      final r = await makeUc().execute(trial: trial);
      final g = r.diagnostics
          .where((d) => d.code == ArmRoundTripDiagnosticCode.guardHasArmPlotNumber)
          .toList();
      expect(g, hasLength(1));
      expect(g.single.severity, ArmRoundTripDiagnosticSeverity.warning);
      expect(g.single.detail, contains('$guardPk'));
    });

    test('nonRecordedRatingsInShellSession ignores ratings on guard plots only',
        () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'RG', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final guardPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: 'G1-L',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 2,
        isGuardRow: true,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'X',
              name: 'N',
              category: 'pest',
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'L',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      final sessId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S',
              sessionDateLocal: '2026-01-01',
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: guardPk,
              assessmentId: legacyAsmId,
              sessionId: sessId,
              trialAssessmentId: Value(taId),
              resultStatus: const Value('NOT_OBSERVED'),
              isCurrent: const Value(true),
            ),
          );
      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: sessId,
      );
      final trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) =>
              d.code ==
              ArmRoundTripDiagnosticCode.nonRecordedRatingsInShellSession,
        ),
        false,
      );
    });

    test('missing and duplicate armImportColumnIndex', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'A', workspaceType: 'efficacy');
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'X',
              name: 'N',
              category: 'pest',
            ),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              sortOrder: const Value(0),
              armImportColumnIndex: const Value(4),
            ),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              sortOrder: const Value(1),
              armImportColumnIndex: const Value(4),
            ),
          );
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              sortOrder: const Value(2),
            ),
          );
      final trial = await _armTrialRow(db, trialId);
      final r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.missingArmImportColumnIndex,
        ),
        true,
      );
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.duplicateArmImportColumnIndex,
        ),
        true,
      );
    });

    test('session pins and heuristics', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'Ses', workspaceType: 'efficacy');
      await _armTrialRow(db, trialId);
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Field',
              sessionDateLocal: '2026-01-02',
            ),
          );
      var trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      var r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.armImportSessionIdMissing,
        ),
        true,
      );
      expect(
        r.diagnostics.any(
          (d) => d.code ==
              ArmRoundTripDiagnosticCode.shellSessionResolvedByHeuristic,
        ),
        true,
      );

      const badPin = 999999;
      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: badPin,
      );
      trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.armImportSessionIdInvalid,
        ),
        true,
      );

      final sessId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'Pinned',
              sessionDateLocal: '2026-01-03',
            ),
          );
      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: sessId,
      );
      trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) => d.code == ArmRoundTripDiagnosticCode.armImportSessionIdInvalid,
        ),
        false,
      );
      expect(
        r.diagnostics.any(
          (d) => d.code ==
              ArmRoundTripDiagnosticCode.shellSessionResolvedByHeuristic,
        ),
        false,
      );
    });

    test('nonRecordedRatingsInShellSession', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'R', workspaceType: 'efficacy');
      final trtId = await TreatmentRepository(db).insertTreatment(
        trialId: trialId,
        code: '1',
        name: 'T',
      );
      final plotPk = await PlotRepository(db).insertPlot(
        trialId: trialId,
        plotId: '1',
        rep: 1,
        treatmentId: trtId,
        plotSortIndex: 1,
      );
      final defId = await db.into(db.assessmentDefinitions).insert(
            AssessmentDefinitionsCompanion.insert(
              code: 'X',
              name: 'N',
              category: 'pest',
            ),
          );
      final legacyAsmId = await db.into(db.assessments).insert(
            AssessmentsCompanion.insert(
              trialId: trialId,
              name: 'L',
            ),
          );
      final taId = await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              legacyAssessmentId: Value(legacyAsmId),
              sortOrder: const Value(0),
            ),
          );
      final sessId = await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              trialId: trialId,
              name: 'S',
              sessionDateLocal: '2026-01-01',
            ),
          );
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: plotPk,
              assessmentId: legacyAsmId,
              sessionId: sessId,
              trialAssessmentId: Value(taId),
              resultStatus: const Value('NOT_OBSERVED'),
              isCurrent: const Value(true),
            ),
          );
      await upsertArmTrialMetadataForTest(
        db,
        trialId: trialId,
        isArmLinked: true,
        armImportSessionId: sessId,
      );
      final trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      final r = await makeUc().execute(trial: trial);
      expect(
        r.diagnostics.any(
          (d) =>
              d.code ==
              ArmRoundTripDiagnosticCode.nonRecordedRatingsInShellSession,
        ),
        true,
      );
    });

    test('toDiagnosticFinding uses armConfidence and blocksExport false', () async {
      final trialId =
          await TrialRepository(db).createTrial(name: 'F', workspaceType: 'efficacy');
      final trial = await _armTrialRow(db, trialId);
      final r = await makeUc().execute(trial: trial);
      final findings = r.toDiagnosticFindings();
      expect(findings, isNotEmpty);
      for (final f in findings) {
        expect(f.blocksExport, false);
        expect(f.source, DiagnosticSource.armConfidence);
      }
    });
  });
}
