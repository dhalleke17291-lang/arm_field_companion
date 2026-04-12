import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/export/domain/arm_shell_link_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_arm_rating_shell_usecase_test.dart' show writeArmShellFixture;

void main() {
  late AppDatabase db;
  late String tempPath;
  late ArmShellLinkUseCase uc;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('shell_link_test');
    tempPath = dir.path;
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    uc = ArmShellLinkUseCase(
      db,
      TrialRepository(db),
      TrialAssessmentRepository(db),
      PlotRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('preview blocks when no plot overlap', () async {
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(
            name: 'T1',
            status: const Value(kTrialStatusDraft),
          ),
        );

    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID'],
      seNames: const ['AVEFA'],
    );

    final p = await uc.preview(trialId, shellPath);
    expect(p.canApply, isFalse);
    expect(p.blockers.any((b) => b.code == 'no_matching_plots'), isTrue);
  });

  test('preview allows apply; apply updates trial, TA, link path, audit', () async {
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(
            name: 'Old Trial Name',
            status: const Value(kTrialStatusDraft),
          ),
        );

    final trtId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: '1',
            name: 'T',
          ),
        );

    await db.into(db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: '101',
            rep: const Value(1),
            treatmentId: Value(trtId),
            plotSortIndex: const Value(1),
            armPlotNumber: const Value(101),
          ),
        );

    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CONTRO',
            name: 'Control',
            category: 'pest',
          ),
        );

    final taId = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
            sortOrder: const Value(0),
            pestCode: const Value.absent(),
            armImportColumnIndex: const Value(2),
          ),
        );

    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      seDescriptions: const ['Percent weed control'],
      ratingDates: const ['1-Jul-26'],
      ratingTypes: const ['CONTRO'],
      ratingTimings: const ['1-Jul-26'],
      ratingUnits: const ['%'],
    );

    final preview = await uc.preview(trialId, shellPath);
    expect(preview.canApply, isTrue, reason: preview.blockerSummary);
    expect(preview.trialFieldChanges, isNotEmpty);
    expect(
      preview.trialFieldChanges.any((c) => c.fieldName == 'name'),
      isTrue,
    );
    expect(
      preview.assessmentFieldChanges.any(
        (c) => c.trialAssessmentId == taId && c.fieldName == 'pestCode',
      ),
      isTrue,
    );
    expect(
      preview.assessmentFieldChanges.any(
        (c) => c.trialAssessmentId == taId && c.fieldName == 'se_description',
      ),
      isTrue,
    );

    final result = await uc.apply(trialId, shellPath);
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.totalAssessmentsMatched, 1);
    expect(result.totalAssessmentsUnmatched, 0);
    expect(result.fieldsUpdated, greaterThan(0));

    final trial = await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
        .getSingle();
    expect(trial.name, 'T');
    expect(trial.armLinkedShellPath, shellPath);
    expect(trial.armLinkedShellAt != null, isTrue);

    final ta = await (db.select(db.trialAssessments)
          ..where((t) => t.id.equals(taId)))
        .getSingle();
    expect(ta.pestCode, 'AVEFA');
    expect(ta.armImportColumnIndex, 2);
    expect(ta.armShellColumnId, '001EID001');
    expect(ta.seDescription, 'Percent weed control');
    expect(ta.seName, 'AVEFA');
    expect(ta.armRatingType, 'CONTRO');
    expect(ta.armShellRatingDate, '1-Jul-26');

    final audits = await (db.select(db.auditEvents)
          ..where((e) => e.eventType.equals('arm_shell_linked')))
        .get();
    expect(audits, hasLength(1));
    expect(audits.single.metadata, contains('shellFileName'));
  });

  test('second apply is idempotent for assessment alignment', () async {
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(
            name: 'T',
            status: const Value(kTrialStatusDraft),
          ),
        );

    final trtId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: '1',
            name: 'T',
          ),
        );

    await db.into(db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: '101',
            rep: const Value(1),
            treatmentId: Value(trtId),
            plotSortIndex: const Value(1),
            armPlotNumber: const Value(101),
          ),
        );

    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CONTRO',
            name: 'Control',
            category: 'pest',
          ),
        );

    await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
            sortOrder: const Value(0),
            pestCode: const Value('AVEFA'),
            armImportColumnIndex: const Value(2),
          ),
        );

    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      ratingTypes: const ['CONTRO'],
    );

    await uc.apply(trialId, shellPath);
    final preview2 = await uc.preview(trialId, shellPath);
    expect(
      preview2.assessmentFieldChanges.where((c) => c.fieldName == 'pestCode'),
      isEmpty,
    );
    final r2 = await uc.apply(trialId, shellPath);
    expect(r2.success, isTrue);
  });

  test('apply leaves armImportColumnIndex unchanged', () async {
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(
            name: 'T',
            status: const Value(kTrialStatusDraft),
          ),
        );

    final trtId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: '1',
            name: 'T',
          ),
        );

    await db.into(db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: '101',
            rep: const Value(1),
            treatmentId: Value(trtId),
            plotSortIndex: const Value(1),
            armPlotNumber: const Value(101),
          ),
        );

    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CONTRO',
            name: 'Control',
            category: 'pest',
          ),
        );

    final taId = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
            sortOrder: const Value(0),
            pestCode: const Value('AVEFA'),
            armImportColumnIndex: const Value(99),
          ),
        );

    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      ratingTypes: const ['CONTRO'],
    );

    final preview = await uc.preview(trialId, shellPath);
    expect(
      preview.assessmentFieldChanges
          .where((c) => c.fieldName == 'armImportColumnIndex'),
      isEmpty,
    );

    await uc.apply(trialId, shellPath);
    final ta = await (db.select(db.trialAssessments)
          ..where((t) => t.id.equals(taId)))
        .getSingle();
    expect(ta.armImportColumnIndex, 99);
  });

  test('empty shell SE description does not overwrite existing seDescription',
      () async {
    final trialId = await db.into(db.trials).insert(
          TrialsCompanion.insert(
            name: 'T',
            status: const Value(kTrialStatusDraft),
          ),
        );

    final trtId = await db.into(db.treatments).insert(
          TreatmentsCompanion.insert(
            trialId: trialId,
            code: '1',
            name: 'T',
          ),
        );

    await db.into(db.plots).insert(
          PlotsCompanion.insert(
            trialId: trialId,
            plotId: '101',
            rep: const Value(1),
            treatmentId: Value(trtId),
            plotSortIndex: const Value(1),
            armPlotNumber: const Value(101),
          ),
        );

    final defId = await db.into(db.assessmentDefinitions).insert(
          AssessmentDefinitionsCompanion.insert(
            code: 'CONTRO',
            name: 'Control',
            category: 'pest',
          ),
        );

    final taId = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
            sortOrder: const Value(0),
            pestCode: const Value('AVEFA'),
            armImportColumnIndex: const Value(2),
            seDescription: const Value('Keep me'),
          ),
        );

    final shellPath = await writeArmShellFixture(
      tempPath,
      plotNumbers: const [101],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      ratingTypes: const ['CONTRO'],
    );

    final preview = await uc.preview(trialId, shellPath);
    expect(
      preview.assessmentFieldChanges
          .where((c) => c.fieldName == 'se_description'),
      isEmpty,
    );

    await uc.apply(trialId, shellPath);
    final ta = await (db.select(db.trialAssessments)
          ..where((t) => t.id.equals(taId)))
        .getSingle();
    expect(ta.seDescription, 'Keep me');
  });
}
