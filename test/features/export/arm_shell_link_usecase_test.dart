import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/trial_state.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/export/domain/arm_shell_link_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'export_arm_rating_shell_usecase_test.dart' show writeArmShellFixture;

/// Stubs path_provider so [ShellStorageService.storeShell] can copy the
/// fixture shell into `{tempPath}/shells/{trialId}.xlsx` during apply.
/// Mirrors the _FakePathProvider used in export_arm_rating_shell_usecase_test.dart.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

/// Throws from [getApplicationDocumentsPath] to simulate the platform
/// plugin failing mid-flight. Used to verify that ArmShellLinkUseCase.apply
/// surfaces the failure as LinkShellResult.failure rather than silently
/// writing a half-linked trial.
class _ThrowingPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    throw Exception('simulated path_provider failure');
  }
}

void main() {
  late AppDatabase db;
  late String tempPath;
  late ArmShellLinkUseCase uc;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('shell_link_test');
    tempPath = dir.path;
    PathProviderPlatform.instance = _FakePathProvider(tempPath);
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    uc = ArmShellLinkUseCase(
      db,
      TrialRepository(db),
      TrialAssessmentRepository(db),
      PlotRepository(db),
      ArmColumnMappingRepository(db),
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
          ),
        );
    await db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: taId,
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
    final arm = await (db.select(db.armTrialMetadata)
          ..where((m) => m.trialId.equals(trialId)))
        .getSingleOrNull();
    expect(arm, isNotNull);
    expect(arm!.armLinkedShellPath, shellPath);
    expect(arm.armLinkedShellAt != null, isTrue);

    final aam = await (db.select(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(taId)))
        .getSingle();
    // v61 (Unit 5d): pestCode / seName / seDescription / ratingType live
    // only on arm_assessment_metadata.
    expect(aam.pestCode, 'AVEFA');
    expect(aam.armImportColumnIndex, 2);
    expect(aam.armShellColumnId, '001EID001');
    expect(aam.seDescription, 'Percent weed control');
    expect(aam.seName, 'AVEFA');
    expect(aam.ratingType, 'CONTRO');
    expect(aam.armShellRatingDate, '1-Jul-26');

    final audits = await (db.select(db.auditEvents)
          ..where((e) => e.eventType.equals('arm_shell_linked')))
        .get();
    expect(audits, hasLength(1));
    expect(audits.single.metadata, contains('shellFileName'));
  });

  test(
    'apply surfaces failure and rolls back when storeShell throws',
    () async {
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
      await db.into(db.trialAssessments).insert(
            TrialAssessmentsCompanion.insert(
              trialId: trialId,
              assessmentDefinitionId: defId,
              sortOrder: const Value(0),
            ),
          );

      // Shell fixture is written against the real fake provider (directory
      // access for the fixture file itself). Apply then runs against a
      // throwing provider so storeShell fails.
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

      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _ThrowingPathProvider();
      addTearDown(() {
        PathProviderPlatform.instance = original;
      });

      final result = await uc.apply(trialId, shellPath);
      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        contains('Unable to link rating sheet'),
      );
      expect(
        result.errorMessage,
        contains('simulated path_provider failure'),
      );

      // Transaction should have rolled back: trial name unchanged, no
      // armTrialMetadata row written, no audit event.
      final trial =
          await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
              .getSingle();
      expect(trial.name, 'Old Trial Name');
      final arm = await (db.select(db.armTrialMetadata)
            ..where((m) => m.trialId.equals(trialId)))
          .getSingleOrNull();
      expect(arm, isNull);
      final audits = await (db.select(db.auditEvents)
            ..where((e) => e.eventType.equals('arm_shell_linked')))
          .get();
      expect(audits, isEmpty);
    },
  );

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

    final idempTaId = await db.into(db.trialAssessments).insert(
          TrialAssessmentsCompanion.insert(
            trialId: trialId,
            assessmentDefinitionId: defId,
            sortOrder: const Value(0),
          ),
        );
    await db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: idempTaId,
            armImportColumnIndex: const Value(2),
            pestCode: const Value('AVEFA'),
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
          ),
        );
    await db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: taId,
            armImportColumnIndex: const Value(99),
            pestCode: const Value('AVEFA'),
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
    final aam = await (db.select(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(taId)))
        .getSingle();
    expect(aam.armImportColumnIndex, 99);
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
          ),
        );
    await db.into(db.armAssessmentMetadata).insert(
          ArmAssessmentMetadataCompanion.insert(
            trialAssessmentId: taId,
            armImportColumnIndex: const Value(2),
            pestCode: const Value('AVEFA'),
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
    final aam = await (db.select(db.armAssessmentMetadata)
          ..where((m) => m.trialAssessmentId.equals(taId)))
        .getSingle();
    expect(aam.seDescription, 'Keep me');
  });
}
