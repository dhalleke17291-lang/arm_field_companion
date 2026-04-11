import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/data/repositories/notes_repository.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late int trialId;
  late int plotPk;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(db);
    final trials = TrialRepository(db);
    trialId = await trials.createTrial(name: 'T1', workspaceType: 'efficacy');
    plotPk =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: '101');
  });

  tearDown(() async {
    await db.close();
  });

  test('createNote inserts row and NOTE_CREATED audit', () async {
    final id = await repo.createNote(
      trialId: trialId,
      plotPk: plotPk,
      sessionId: null,
      content: '  Edge pooling  ',
      createdBy: 'Rater A',
    );
    expect(id, greaterThan(0));
    final rows = await repo.getNotesForTrial(trialId);
    expect(rows, hasLength(1));
    expect(rows.single.content, 'Edge pooling');
    expect(rows.single.plotPk, plotPk);
    expect(rows.single.sessionId, isNull);

    final audits = await (db.select(db.auditEvents)
          ..where((e) => e.trialId.equals(trialId))
          ..orderBy([(e) => OrderingTerm.desc(e.id)]))
        .get();
    expect(audits.first.eventType, 'NOTE_CREATED');
    final meta =
        jsonDecode(audits.first.metadata!) as Map<String, dynamic>;
    expect(meta['note_id'], id);
  });

  test('updateNote writes audit with old_content', () async {
    final id = await repo.createNote(
      trialId: trialId,
      content: 'Original',
      createdBy: 'A',
    );
    await repo.updateNote(id, 'Revised text', 'B');
    final n = (await repo.getNotesForTrial(trialId)).single;
    expect(n.content, 'Revised text');
    expect(n.updatedBy, 'B');
    expect(n.updatedAt, isNotNull);

    final audits = await (db.select(db.auditEvents)
          ..where((e) => e.eventType.equals('NOTE_UPDATED'))
          ..orderBy([(e) => OrderingTerm.desc(e.id)]))
        .get();
    expect(audits, isNotEmpty);
    final meta =
        jsonDecode(audits.first.metadata!) as Map<String, dynamic>;
    expect(meta['old_content'], 'Original');
  });

  test('deleteNote soft-deletes and excludes from getNotesForTrial', () async {
    final id = await repo.createNote(
      trialId: trialId,
      content: 'To remove',
      createdBy: 'A',
    );
    await repo.deleteNote(id, 'B');
    expect(await repo.getNotesForTrial(trialId), isEmpty);
    final raw = await (db.select(db.notes)..where((n) => n.id.equals(id)))
        .getSingle();
    expect(raw.isDeleted, isTrue);
    expect(raw.deletedBy, 'B');
    expect(raw.deletedAt, isNotNull);
  });
}
