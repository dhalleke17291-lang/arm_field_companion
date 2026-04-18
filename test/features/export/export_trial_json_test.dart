import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/application_product_repository.dart';
import 'package:arm_field_companion/data/repositories/application_repository.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/data/repositories/weather_snapshot_repository.dart';
import 'package:arm_field_companion/domain/intelligence/trial_intelligence_service.dart';
import 'package:arm_field_companion/features/export/export_trial_json_usecase.dart';
import 'package:arm_field_companion/features/photos/photo_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../stress/stress_import_helpers.dart';

void main() {
  late AppDatabase db;
  late ExportTrialJsonUseCase useCase;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
    final assignmentRepo = AssignmentRepository(db);
    final treatmentRepo = TreatmentRepository(db, assignmentRepo);
    useCase = ExportTrialJsonUseCase(
      plotRepository: PlotRepository(db),
      treatmentRepository: treatmentRepo,
      applicationRepository: ApplicationRepository(db),
      applicationProductRepository: ApplicationProductRepository(db),
      sessionRepository: SessionRepository(db),
      assignmentRepository: assignmentRepo,
      ratingRepository: RatingRepository(db),
      notesRepository: NotesRepository(db),
      photoRepository: PhotoRepository(db),
      weatherSnapshotRepository: WeatherSnapshotRepository(db),
      intelligenceService: TrialIntelligenceService(
        sessionRepository: SessionRepository(db),
        ratingRepository: RatingRepository(db),
        plotRepository: PlotRepository(db),
        assignmentRepository: assignmentRepo,
        treatmentRepository: treatmentRepo,
        weatherSnapshotRepository: WeatherSnapshotRepository(db),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('produces valid JSON with all sections', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n'
        '101,1,1,40\n102,2,1,70\n103,1,2,45\n104,2,2,75\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'json_test.csv');
    expect(r.success, isTrue);

    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(r.trialId!)))
            .getSingle();

    final jsonStr = await useCase.buildJson(trial: trial);

    // Must be valid JSON
    final parsed = json.decode(jsonStr) as Map<String, dynamic>;
    expect(parsed, isNotNull);

    // Top-level fields
    expect(parsed['exportVersion'], '1.0');
    expect(parsed['schemaVersion'], 54);
    expect(parsed['exportedAt'], isNotEmpty);

    // Trial section
    final trialData = parsed['trial'] as Map<String, dynamic>;
    expect(trialData['name'], trial.name);
    expect(trialData['site'], isA<Map>());
    expect(trialData['design'], isA<Map>());

    // Arrays present (may be empty but not missing)
    expect(trialData['treatments'], isA<List>());
    expect(trialData['applications'], isA<List>());
    expect(trialData['sessions'], isA<List>());
    expect(trialData['fieldNotes'], isA<List>());
    expect(trialData['photosManifest'], isA<List>());
    expect(trialData['completeness'], isA<Map>());
    expect(trialData['insights'], isA<List>());
  });

  test('treatments include components', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'json_trt.csv');
    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(r.trialId!)))
            .getSingle();

    final jsonStr = await useCase.buildJson(trial: trial);
    final parsed = json.decode(jsonStr) as Map<String, dynamic>;
    final treatments =
        (parsed['trial'] as Map)['treatments'] as List;
    expect(treatments.length, 2);
    for (final t in treatments) {
      expect(t['code'], isNotNull);
      expect(t['components'], isA<List>());
    }
  });

  test('sessions contain ratings grouped by plot', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'json_ratings.csv');
    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(r.trialId!)))
            .getSingle();

    final jsonStr = await useCase.buildJson(trial: trial);
    final parsed = json.decode(jsonStr) as Map<String, dynamic>;
    final sessions =
        (parsed['trial'] as Map)['sessions'] as List;
    expect(sessions, isNotEmpty);
    final firstSession = sessions.first as Map<String, dynamic>;
    expect(firstSession['ratings'], isA<List>());
    final ratings = firstSession['ratings'] as List;
    expect(ratings, isNotEmpty);
    final firstRating = ratings.first as Map<String, dynamic>;
    expect(firstRating['plotId'], isNotNull);
    expect(firstRating['assessments'], isA<Map>());
  });

  test('completeness section has required fields', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,50\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'json_comp.csv');
    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(r.trialId!)))
            .getSingle();

    final jsonStr = await useCase.buildJson(trial: trial);
    final parsed = json.decode(jsonStr) as Map<String, dynamic>;
    final completeness =
        (parsed['trial'] as Map)['completeness'] as Map<String, dynamic>;
    expect(completeness['sessions'], isA<Map>());
    expect(completeness['bbchCoverage'], isA<Map>());
    expect(completeness['cropInjuryCoverage'], isA<Map>());
    expect(completeness['photoCount'], isA<int>());
  });
}
