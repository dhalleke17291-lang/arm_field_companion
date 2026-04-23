// Phase 3c — xlsx importer writes Applications-sheet data.
//
// Verifies [ImportArmRatingShellUseCase] consumes [ArmShellImport.applicationSheetColumns]
// and lands:
//   - `trial_application_events` (dual-write of universal fields from known rows);
//   - `arm_applications` (verbatim `row01`…`row79` + `arm_sheet_column_index`).

import 'dart:io';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/arm/arm_applications_repository.dart';
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

List<String?> _app79({
  required String date,
  String? time,
  String? method,
  String? operator,
  String? timing,
  String? equip1,
  String? equip2,
}) {
  final r = List<String?>.filled(79, null);
  r[0] = date;
  r[1] = time;
  r[5] = method;
  r[8] = operator;
  r[6] = timing;
  r[35] = equip1;
  r[36] = equip2;
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late PathProviderPlatform savedProvider;
  late ImportArmRatingShellUseCase useCase;

  setUp(() async {
    savedProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('import_shell_app_test');
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
      armApplicationsRepository: ArmApplicationsRepository(db),
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = savedProvider;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ImportArmRatingShellUseCase — Applications sheet write-through', () {
    test('creates events + arm_applications from two sheet columns', () async {
      final path = await writeArmShellFixture(
        tempDir.path,
        plotNumbers: const [101],
        armColumnIds: const ['3'],
        seNames: const ['W003'],
        ratingDates: const ['1-Jul-26'],
        ratingTypes: const ['CONTRO'],
        applicationSheetColumns: [
          _app79(
            date: '15-Jun-26',
            time: '08:30',
            method: 'BROADCAST',
            operator: 'J.D.',
            timing: 'A1',
            equip1: 'Tractor',
            equip2: 'Boom',
          ),
          _app79(
            date: '20-Jun-26',
            timing: 'AA',
          ),
        ],
      );

      final result = await useCase.execute(path);
      expect(result.success, isTrue, reason: result.errorMessage);
      final trialId = result.trialId!;

      final events = await (db.select(db.trialApplicationEvents)
            ..where((e) => e.trialId.equals(trialId))
            ..orderBy([(e) => OrderingTerm.asc(e.applicationDate)]))
          .get();
      expect(events, hasLength(2));

      expect(events[0].applicationMethod, 'BROADCAST');
      expect(events[0].operatorName, 'J.D.');
      expect(events[0].applicationTime, '08:30');
      expect(events[0].equipmentUsed, 'Tractor / Boom');
      expect(events[0].status, 'applied');

      final armRows = await (db.select(db.armApplications)
            ..orderBy([(a) => OrderingTerm.asc(a.armSheetColumnIndex)]))
          .get();
      expect(armRows, hasLength(2));
      expect(armRows[0].armSheetColumnIndex, 2);
      expect(armRows[0].row01, '15-Jun-26');
      expect(armRows[0].row07, 'A1');
      expect(armRows[1].armSheetColumnIndex, 3);
      expect(armRows[1].row01, '20-Jun-26');
      expect(armRows[1].row07, 'AA');
    });

    test('skips columns with no parseable application date', () async {
      final badDate = List<String?>.filled(79, null);
      badDate[0] = 'not-a-real-date';
      final path = await writeArmShellFixture(
        tempDir.path,
        plotNumbers: const [101],
        armColumnIds: const ['3'],
        seNames: const ['W003'],
        ratingDates: const ['1-Jul-26'],
        ratingTypes: const ['CONTRO'],
        applicationSheetColumns: [badDate],
      );

      final result = await useCase.execute(path);
      expect(result.success, isTrue, reason: result.errorMessage);
      final trialId = result.trialId!;

      final events = await (db.select(db.trialApplicationEvents)
            ..where((e) => e.trialId.equals(trialId)))
          .get();
      expect(events, isEmpty);
      expect(await db.select(db.armApplications).get(), isEmpty);
    });
  });
}
