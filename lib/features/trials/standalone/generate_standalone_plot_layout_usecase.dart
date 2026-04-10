import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../plots/plot_repository.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../trial_repository.dart';
import 'plot_generation_engine.dart';

class GenerateStandalonePlotLayoutInput {
  const GenerateStandalonePlotLayoutInput({
    required this.trialId,
    required this.repCount,
    required this.experimentalDesign,
    this.random,
  });

  final int trialId;
  final int repCount;
  final String experimentalDesign;
  final Random? random;
}

class GenerateStandalonePlotLayoutResult {
  const GenerateStandalonePlotLayoutResult._({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;

  factory GenerateStandalonePlotLayoutResult.ok() =>
      const GenerateStandalonePlotLayoutResult._(success: true);

  factory GenerateStandalonePlotLayoutResult.failure(String message) =>
      GenerateStandalonePlotLayoutResult._(
        success: false,
        errorMessage: message,
      );
}

/// Inserts plots + assignments for an existing standalone trial that already has treatments.
class GenerateStandalonePlotLayoutUseCase {
  GenerateStandalonePlotLayoutUseCase(
    this._db,
    this._trialRepository,
    this._treatmentRepository,
    this._plotRepository,
    this._assignmentRepository,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final TreatmentRepository _treatmentRepository;
  final PlotRepository _plotRepository;
  final AssignmentRepository _assignmentRepository;

  Future<GenerateStandalonePlotLayoutResult> execute(
    GenerateStandalonePlotLayoutInput input,
  ) async {
    if (input.repCount < 1 || input.repCount > 8) {
      return GenerateStandalonePlotLayoutResult.failure('Reps must be between 1 and 8');
    }

    final trial = await _trialRepository.getTrialById(input.trialId);
    if (trial == null) {
      return GenerateStandalonePlotLayoutResult.failure('Trial not found');
    }
    if (trial.isArmLinked == true) {
      return GenerateStandalonePlotLayoutResult.failure('Only custom trials support this action');
    }

    final treatments = await _treatmentRepository.getTreatmentsForTrial(input.trialId);
    treatments.sort((a, b) => a.id.compareTo(b.id));
    if (treatments.length < 2) {
      return GenerateStandalonePlotLayoutResult.failure('Add at least two treatments first');
    }

    final existingPlots = await _plotRepository.getPlotsForTrial(input.trialId);
    if (existingPlots.isNotEmpty) {
      return GenerateStandalonePlotLayoutResult.failure('This trial already has plots');
    }

    try {
      await _db.transaction(() async {
        final existingDesign = trial.experimentalDesign?.trim();
        final resolvedDesign = (existingDesign != null && existingDesign.isNotEmpty)
            ? existingDesign
            : input.experimentalDesign;
        if (existingDesign == null || existingDesign.isEmpty) {
          await _trialRepository.updateTrialSetup(
            input.trialId,
            TrialsCompanion(
              experimentalDesign: Value(resolvedDesign),
            ),
          );
        }

        final gen = PlotGenerationEngine.generate(
          treatmentCount: treatments.length,
          repCount: input.repCount,
          experimentalDesign: resolvedDesign,
          random: input.random,
        );

        final companions = gen.plots
            .map(
              (p) => PlotsCompanion.insert(
                trialId: input.trialId,
                plotId: p.plotId,
                plotSortIndex: Value(p.plotSortIndex),
                rep: Value(p.rep),
              ),
            )
            .toList();
        await _plotRepository.insertPlotsBulk(companions);

        final plotRows = await _plotRepository.getPlotsForTrial(input.trialId);
        if (plotRows.length != gen.plots.length) {
          throw StateError('Plot count mismatch after insert');
        }

        final idByIndex = <int, int>{};
        for (var i = 0; i < treatments.length; i++) {
          idByIndex[i] = treatments[i].id;
        }

        final at = DateTime.now().toUtc();
        for (var i = 0; i < plotRows.length; i++) {
          final tIdx = gen.treatmentIndexPerPlot[i];
          final tid = idByIndex[tIdx];
          if (tid == null) {
            throw StateError('Invalid treatment index $tIdx');
          }
          await _assignmentRepository.upsert(
            trialId: input.trialId,
            plotId: plotRows[i].id,
            treatmentId: tid,
            replication: plotRows[i].rep,
            assignmentSource: 'manual',
            assignedAt: at,
          );
        }
      });
      return GenerateStandalonePlotLayoutResult.ok();
    } catch (e) {
      return GenerateStandalonePlotLayoutResult.failure('Could not generate plots: $e');
    }
  }
}
