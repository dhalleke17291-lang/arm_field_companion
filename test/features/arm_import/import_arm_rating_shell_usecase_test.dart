import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
import 'package:arm_field_companion/data/arm/arm_column_mapping_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/trial_assessment_repository.dart';
import 'package:arm_field_companion/features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../export/export_arm_rating_shell_usecase_test.dart'
    show writeArmShellFixture;

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

  setUp(() async {
    savedProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('import_shell_uc_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('missing shell file fails before any trial is created', () async {
    final assignmentRepo = AssignmentRepository(db);
    final useCase = ImportArmRatingShellUseCase(
      db: db,
      trialRepository: TrialRepository(db),
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db, assignmentRepo),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      assignmentRepository: assignmentRepo,
      armColumnMappingRepository: ArmColumnMappingRepository(db),
      armApplicationsRepository: ArmApplicationsRepository(db),
    );

    final result = await useCase.execute('/nonexistent/path/no_shell.xlsx');
    expect(result.success, isFalse);

    final trials = await db.select(db.trials).get();
    expect(trials, isEmpty);
  });

  test('successful import leaves trial isArmLinked true after shell copy', () async {
    final path = await writeArmShellFixture(
      tempDir.path,
      plotNumbers: const [101, 102],
      armColumnIds: const ['001EID001'],
      seNames: const ['AVEFA'],
      seDescriptions: const ['Percent control'],
      ratingDates: const ['1-Jul-26'],
    );

    final assignmentRepo = AssignmentRepository(db);
    final trialRepo = TrialRepository(db);
    final useCase = ImportArmRatingShellUseCase(
      db: db,
      trialRepository: trialRepo,
      plotRepository: PlotRepository(db),
      treatmentRepository: TreatmentRepository(db, assignmentRepo),
      trialAssessmentRepository: TrialAssessmentRepository(db),
      assignmentRepository: assignmentRepo,
      armColumnMappingRepository: ArmColumnMappingRepository(db),
      armApplicationsRepository: ArmApplicationsRepository(db),
    );

    final result = await useCase.execute(path);
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.trialId, isNotNull);

    final trial = await trialRepo.getTrialById(result.trialId!);
    expect(trial, isNotNull);
    final arm = await (db.select(db.armTrialMetadata)
          ..where((m) => m.trialId.equals(result.trialId!)))
        .getSingleOrNull();
    expect(arm, isNotNull);
    expect(arm!.isArmLinked, isTrue);
    expect(arm.armImportedAt, isNotNull);
    expect(arm.armSourceFile, path);
    expect(arm.shellInternalPath, isNotNull);
  });
}
