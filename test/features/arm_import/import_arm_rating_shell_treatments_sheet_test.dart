// Phase 2b — xlsx importer writes Treatments-sheet data.
//
// Verifies that [ImportArmRatingShellUseCase] consumes the Treatments
// sheet parsed by Phase 2a and lands it in:
//   - core `Treatments.name` / `Treatments.treatmentType` (dual-write,
//     so standalone-shaped screens and control-treatment detection
//     keep working);
//   - `TreatmentComponents` (one component per non-blank product name,
//     carrying rate + rate unit);
//   - `arm_treatment_metadata` (the ARM-only formulation coding —
//     armTypeCode verbatim, formConc/formConcUnit/formType, and
//     armRowSortOrder to preserve sheet order for round-trip).
//
// Uses the real `AgQuest_RatingShell.xlsx` fixture (trt 1 = CHK blank
// row, trts 2–4 = full product rows). Expected values mirror
// `test/data/arm_shell_parser_treatments_sheet_test.dart`.

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _fixturePath = 'test/fixtures/arm_shells/AgQuest_RatingShell.xlsx';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late PathProviderPlatform savedProvider;
  late ImportArmRatingShellUseCase useCase;

  setUp(() async {
    savedProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('import_shell_trt_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());

    final assignmentRepo = AssignmentRepository(db);
    useCase = ImportArmRatingShellUseCase(
      db: db,
      trialRepository: TrialRepository(db),
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db, assignmentRepo),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      assignmentRepository: assignmentRepo,
      armColumnMappingRepository: ArmColumnMappingRepository(db),
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ImportArmRatingShellUseCase — Treatments sheet write-through', () {
    test('imports AgQuest fixture successfully', () async {
      final result = await useCase.execute(_fixturePath);
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.trialId, isNotNull);
    });

    test('populates Treatments.name and treatmentType from the sheet',
        () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      final treatments = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(trialId))
            ..orderBy([(t) => OrderingTerm.asc(t.code)]))
          .get();
      expect(treatments, hasLength(4));

      // trt 1 = CHK (blank name → falls back to default "Treatment 1",
      // but treatmentType gets the verbatim 'CHK' code for control
      // detection and display).
      final trt1 = treatments.firstWhere((t) => t.code == '1');
      expect(trt1.treatmentType, 'CHK',
          reason:
              'Dual-write: ARM Type code must land on core treatmentType');
      expect(trt1.name, 'Treatment 1',
          reason: 'Blank Treatments-sheet name keeps the import default');

      // trt 2 = FUNG / APRON.
      final trt2 = treatments.firstWhere((t) => t.code == '2');
      expect(trt2.name, 'APRON',
          reason:
              'Non-blank Treatment Name on the sheet overrides the default');
      expect(trt2.treatmentType, 'FUNG');
    });

    test('creates TreatmentComponents for non-blank product rows only',
        () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      final components = await (db.select(db.treatmentComponents)
            ..where((c) => c.trialId.equals(trialId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

      // CHK (trt 1) has no product name → no component. Expect exactly
      // three components for trts 2, 3, 4.
      expect(components, hasLength(3),
          reason:
              'CHK row has blank product name → no TreatmentComponents row');

      final fung = components.firstWhere((c) => c.productName == 'APRON');
      expect(fung.rate, 5);
      expect(fung.rateUnit, '% w/v');
    });

    test(
        'creates arm_treatment_metadata for every parsed row including CHK',
        () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      // Fetch via join so we can key by treatment code.
      final treatments = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(trialId)))
          .get();
      final byId = {for (final t in treatments) t.id: t};

      final aam = await db.select(db.armTreatmentMetadata).get();
      final aamForTrial = aam.where((a) => byId.containsKey(a.treatmentId));
      expect(aamForTrial, hasLength(4),
          reason:
              'AAM row per parsed treatment (CHK included) preserves sheet '
              'order for round-trip export');

      final chkMeta = aamForTrial.firstWhere(
          (a) => byId[a.treatmentId]!.code == '1');
      expect(chkMeta.armTypeCode, 'CHK',
          reason: 'ARM-verbatim Type preserved even for untreated checks');
      expect(chkMeta.armRowSortOrder, 0,
          reason: 'CHK is row 0 in the Treatments sheet');
      expect(chkMeta.formConc, isNull);
      expect(chkMeta.formConcUnit, isNull);
      expect(chkMeta.formType, isNull);

      final fungMeta = aamForTrial.firstWhere(
          (a) => byId[a.treatmentId]!.code == '2');
      expect(fungMeta.armTypeCode, 'FUNG');
      expect(fungMeta.armRowSortOrder, 1);
      expect(fungMeta.formConc, 25);
      expect(fungMeta.formConcUnit, '%W/W',
          reason: 'ARM %W/W syntax preserved verbatim for round-trip');
      expect(fungMeta.formType, 'W');
    });

    test('armRowSortOrder matches the sheet ordering (0, 1, 2, 3)',
        () async {
      final result = await useCase.execute(_fixturePath);
      final trialId = result.trialId!;

      final treatments = await (db.select(db.treatments)
            ..where((t) => t.trialId.equals(trialId)))
          .get();
      final treatmentIds = treatments.map((t) => t.id).toSet();

      final aam = await (db.select(db.armTreatmentMetadata)
            ..orderBy([(a) => OrderingTerm.asc(a.armRowSortOrder)]))
          .get();
      final aamForTrial =
          aam.where((a) => treatmentIds.contains(a.treatmentId)).toList();

      expect(
        aamForTrial.map((a) => a.armRowSortOrder).toList(),
        equals(<int>[0, 1, 2, 3]),
      );
    });
  });
}
