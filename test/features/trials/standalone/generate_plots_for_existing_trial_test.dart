import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/assignment_repository.dart';
import 'package:arm_field_companion/data/repositories/treatment_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/standalone/generate_standalone_plot_layout_usecase.dart';
import 'package:arm_field_companion/features/trials/standalone/plot_generation_engine.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('3 treatments, 0 plots → 4 reps RCBD → 12 plots + assignments', () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'gen_${DateTime.now().microsecondsSinceEpoch}',
      workspaceType: 'standalone',
      experimentalDesign: PlotGenerationEngine.designRcbd,
    );
    for (var i = 0; i < 3; i++) {
      await TreatmentRepository(db, AssignmentRepository(db)).insertTreatment(
        trialId: trialId,
        code: 'T${i + 1}',
        name: 'T${i + 1}',
      );
    }

    final uc = GenerateStandalonePlotLayoutUseCase(
      db,
      TrialRepository(db),
      TreatmentRepository(db, AssignmentRepository(db)),
      PlotRepository(db),
      AssignmentRepository(db),
    );

    final result = await uc.execute(
      GenerateStandalonePlotLayoutInput(
        trialId: trialId,
        repCount: 4,
        plotsPerRep: 3,
        experimentalDesign: PlotGenerationEngine.designRcbd,
      ),
    );
    expect(result.success, true);

    final plots = await PlotRepository(db).getPlotsForTrial(trialId);
    expect(plots.length, 12);
    final assigns = await AssignmentRepository(db).getForTrial(trialId);
    expect(assigns.length, 12);
    expect(assigns.every((a) => a.treatmentId != null), true);
  });
}
