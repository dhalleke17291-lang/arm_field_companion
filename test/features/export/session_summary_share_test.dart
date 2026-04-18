import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/domain/ratings/rating_integrity_guard.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/ratings/usecases/save_rating_usecase.dart';
import 'package:arm_field_companion/features/sessions/session_repository.dart';
import 'package:arm_field_companion/features/sessions/session_summary_share.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/session_date_test_utils.dart';
import '../../stress/stress_import_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureAssessmentDefinitionsSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  test('composes summary with all fields', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,40\n102,2,1,70\n103,1,2,45\n104,2,2,75\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'share_test.csv');
    expect(r.success, isTrue);
    final trialId = r.trialId!;
    final sessionId = r.importSessionId!;

    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
            .getSingle();
    final session =
        await (db.select(db.sessions)..where((s) => s.id.equals(sessionId)))
            .getSingle();
    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    final assessments =
        await SessionRepository(db).getSessionAssessments(sessionId);
    final ratings =
        await RatingRepository(db).getCurrentRatingsForSession(sessionId);
    final treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);
    final assignments = await AssignmentRepository(db).getForTrial(trialId);

    final text = composeSessionSummary(
      trial: trial,
      session: session,
      plots: plots,
      assessments: assessments,
      ratings: ratings,
      treatments: treatments,
      assignments: assignments,
    );

    expect(text, contains(trial.name));
    expect(text, contains('complete'));
    expect(text, contains('plots rated'));
    expect(text, contains('Treatment means'));
    // Should contain treatment codes and values
    expect(text, contains('%'));
  });

  test('includes crop injury and weather when present', () async {
    final csv =
        'Plot No.,trt,reps,WEED1 1-Jul-26 CONTRO %\n101,1,1,50\n';
    final r = await stressArmImportUseCase(db)
        .execute(csv, sourceFileName: 'share_weather.csv');
    final trialId = r.trialId!;
    final sessionId = r.importSessionId!;

    // Set crop injury
    await SessionRepository(db).updateSessionCropInjury(
      sessionId,
      status: 'none_observed',
    );

    final trial =
        await (db.select(db.trials)..where((t) => t.id.equals(trialId)))
            .getSingle();
    final session =
        await (db.select(db.sessions)..where((s) => s.id.equals(sessionId)))
            .getSingle();
    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    final assessments =
        await SessionRepository(db).getSessionAssessments(sessionId);
    final ratings =
        await RatingRepository(db).getCurrentRatingsForSession(sessionId);
    final treatments =
        await TreatmentRepository(db, AssignmentRepository(db))
            .getTreatmentsForTrial(trialId);
    final assignments = await AssignmentRepository(db).getForTrial(trialId);

    final text = composeSessionSummary(
      trial: trial,
      session: session,
      plots: plots,
      assessments: assessments,
      ratings: ratings,
      treatments: treatments,
      assignments: assignments,
    );

    expect(text, contains('Crop injury: none observed'));
  });
}
