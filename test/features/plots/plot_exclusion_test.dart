import 'dart:convert';

import 'package:arm_field_companion/core/database/app_database.dart';
import 'package:arm_field_companion/core/plot_analysis_eligibility.dart';
import 'package:arm_field_companion/features/plots/plot_repository.dart';
import 'package:arm_field_companion/features/ratings/rating_repository.dart';
import 'package:arm_field_companion/features/trials/trial_repository.dart';
import 'package:drift/drift.dart';
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

  test('isAnalyzablePlot: guard rows are never analyzable', () {
    const p = Plot(
      id: 1,
      trialId: 1,
      plotId: 'G1',
      isGuardRow: true,
      isDeleted: false,
      excludeFromAnalysis: false,
    );
    expect(isAnalyzablePlot(p), isFalse);
  });

  test('isAnalyzablePlot: researcher exclusion', () {
    const p = Plot(
      id: 2,
      trialId: 1,
      plotId: '101',
      isGuardRow: false,
      isDeleted: false,
      excludeFromAnalysis: true,
      exclusionReason: 'hail',
      damageType: 'weather',
    );
    expect(isAnalyzablePlot(p), isFalse);
  });

  test('setPlotExcludedFromAnalysis writes audit PLOT_EXCLUDED_FROM_ANALYSIS',
      () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 't', workspaceType: 'efficacy');
    final plotPk =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P1');

    await PlotRepository(db).setPlotExcludedFromAnalysis(
      plotPk,
      exclusionReason: 'Flood damage',
      damageType: 'weather',
      performedBy: 'Tester',
    );

    final plot = await PlotRepository(db).getPlotByPk(plotPk);
    expect(plot?.excludeFromAnalysis, isTrue);
    expect(plot?.exclusionReason, 'Flood damage');
    expect(plot?.damageType, 'weather');

    final audits = await (db.select(db.auditEvents)
          ..where((e) => e.plotPk.equals(plotPk)))
        .get();
    expect(
      audits.map((e) => e.eventType),
      contains('PLOT_EXCLUDED_FROM_ANALYSIS'),
    );
    final meta =
        jsonDecode(audits.firstWhere((e) => e.eventType == 'PLOT_EXCLUDED_FROM_ANALYSIS').metadata ?? '{}')
            as Map<String, dynamic>;
    expect(meta['damage_type'], 'weather');
  });

  test('clearPlotExcludedFromAnalysis writes PLOT_INCLUDED_IN_ANALYSIS',
      () async {
    final trialId =
        await TrialRepository(db).createTrial(name: 't2', workspaceType: 'efficacy');
    final plotPk =
        await PlotRepository(db).insertPlot(trialId: trialId, plotId: 'P2');
    await PlotRepository(db).setPlotExcludedFromAnalysis(
      plotPk,
      exclusionReason: 'x',
      damageType: 'other',
    );
    await PlotRepository(db).clearPlotExcludedFromAnalysis(plotPk);

    final plot = await PlotRepository(db).getPlotByPk(plotPk);
    expect(plot?.excludeFromAnalysis, isFalse);
    expect(plot?.exclusionReason, null);
    expect(plot?.damageType, null);

    final types = await (db.select(db.auditEvents)
          ..where((e) => e.plotPk.equals(plotPk)))
        .get()
        .then((rows) => rows.map((e) => e.eventType).toList());
    expect(types, contains('PLOT_INCLUDED_IN_ANALYSIS'));
  });

  test('getRatedPlotCountForTrial ignores analysis-excluded data plots',
      () async {
    final trialId = await TrialRepository(db).createTrial(
      name: 'r',
      workspaceType: 'efficacy',
    );
    final repo = PlotRepository(db);
    final p1 = await repo.insertPlot(trialId: trialId, plotId: 'A');
    final p2 = await repo.insertPlot(trialId: trialId, plotId: 'B');
    await repo.setPlotExcludedFromAnalysis(
      p2,
      exclusionReason: 'reason',
      damageType: 'mechanical',
    );

    final aId = await db.into(db.assessments).insert(
          AssessmentsCompanion.insert(trialId: trialId, name: 'X'),
        );
    final sessionId = await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            trialId: trialId,
            name: 'S',
            sessionDateLocal: '2026-04-01',
          ),
        );
    final ratingRepo = RatingRepository(db);
    for (final pk in [p1, p2]) {
      await db.into(db.ratingRecords).insert(
            RatingRecordsCompanion.insert(
              trialId: trialId,
              plotPk: pk,
              assessmentId: aId,
              sessionId: sessionId,
              resultStatus: const Value('RECORDED'),
              isCurrent: const Value(true),
            ),
          );
    }

    final n = await ratingRepo.getRatedPlotCountForTrial(trialId);
    expect(n, 1);
  });
}
