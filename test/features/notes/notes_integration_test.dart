import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository-level integration: notes persist and respect soft delete.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('trial with plot: note linked to plot then soft-deleted', () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 'Int', workspaceType: 'efficacy');
    final plotPk =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: '501');
    final repo = NotesRepository(db);
    final id = await repo.createNote(
      trialId: trialId,
      plotPk: plotPk,
      content: 'Plot-linked',
      createdBy: 'Tech',
    );
    final forPlot = await repo.getNotesForPlot(trialId, plotPk);
    expect(forPlot, hasLength(1));
    await repo.deleteNote(id, 'Tech');
    expect(await repo.getNotesForPlot(trialId, plotPk), isEmpty);
    expect(await repo.getNotesForTrial(trialId), isEmpty);
  });
}
