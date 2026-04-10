import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/assessment_definition_repository.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../plots/plot_repository.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../trial_repository.dart';
import 'plot_generation_engine.dart';

class StandaloneWizardTreatmentInput {
  const StandaloneWizardTreatmentInput({
    required this.code,
    this.name,
    this.treatmentType,
  });

  final String code;
  final String? name;
  final String? treatmentType;
}

class StandaloneWizardAssessmentInput {
  const StandaloneWizardAssessmentInput({
    required this.name,
    this.unit,
    this.scaleMin,
    this.scaleMax,
    this.dataType = 'numeric',
  });

  final String name;
  final String? unit;
  final double? scaleMin;
  final double? scaleMax;
  final String dataType;
}

class CreateStandaloneTrialWizardInput {
  const CreateStandaloneTrialWizardInput({
    required this.trialName,
    this.crop,
    this.location,
    this.season,
    required this.experimentalDesign,
    required this.treatments,
    required this.repCount,
    required this.assessments,
    this.performedByUserId,
    this.random,
  });

  final String trialName;
  final String? crop;
  final String? location;
  final String? season;
  final String experimentalDesign;
  final List<StandaloneWizardTreatmentInput> treatments;
  final int repCount;
  final List<StandaloneWizardAssessmentInput> assessments;
  final int? performedByUserId;
  final Random? random;
}

class CreateStandaloneTrialWizardResult {
  const CreateStandaloneTrialWizardResult._({
    required this.success,
    this.trialId,
    this.errorMessage,
  });

  final bool success;
  final int? trialId;
  final String? errorMessage;

  factory CreateStandaloneTrialWizardResult.ok(int trialId) =>
      CreateStandaloneTrialWizardResult._(success: true, trialId: trialId);

  factory CreateStandaloneTrialWizardResult.failure(String message) =>
      CreateStandaloneTrialWizardResult._(
        success: false,
        errorMessage: message,
      );
}

/// Creates a standalone trial with treatments, plots, assignments, and optional assessments
/// in one atomic transaction.
class CreateStandaloneTrialWizardUseCase {
  CreateStandaloneTrialWizardUseCase(
    this._db,
    this._trialRepository,
    this._treatmentRepository,
    this._plotRepository,
    this._assignmentRepository,
    this._definitionRepository,
    this._trialAssessmentRepository,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final TreatmentRepository _treatmentRepository;
  final PlotRepository _plotRepository;
  final AssignmentRepository _assignmentRepository;
  final AssessmentDefinitionRepository _definitionRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;

  Future<CreateStandaloneTrialWizardResult> execute(
    CreateStandaloneTrialWizardInput input,
  ) async {
    final name = input.trialName.trim();
    if (name.isEmpty) {
      return CreateStandaloneTrialWizardResult.failure('Trial name must not be empty');
    }
    if (input.treatments.length < 2) {
      return CreateStandaloneTrialWizardResult.failure('At least two treatments are required');
    }
    for (final t in input.treatments) {
      if (t.code.trim().isEmpty) {
        return CreateStandaloneTrialWizardResult.failure('Each treatment needs a code');
      }
    }
    if (input.repCount < 1 || input.repCount > 8) {
      return CreateStandaloneTrialWizardResult.failure('Reps must be between 1 and 8');
    }

    try {
      late int trialId;
      await _db.transaction(() async {
        trialId = await _trialRepository.createTrial(
          name: name,
          crop: _optTrim(input.crop),
          location: _optTrim(input.location),
          season: _optTrim(input.season),
          workspaceType: 'standalone',
          experimentalDesign: input.experimentalDesign,
        );

        final treatmentIds = <int>[];
        for (final t in input.treatments) {
          final id = await _treatmentRepository.insertTreatment(
            trialId: trialId,
            code: t.code.trim(),
            name: (t.name == null || t.name!.trim().isEmpty)
                ? t.code.trim()
                : t.name!.trim(),
            description: null,
            treatmentType: t.treatmentType,
            timingCode: null,
            eppoCode: null,
            performedByUserId: input.performedByUserId,
          );
          treatmentIds.add(id);
        }

        final gen = PlotGenerationEngine.generate(
          treatmentCount: treatmentIds.length,
          repCount: input.repCount,
          experimentalDesign: input.experimentalDesign,
          random: input.random,
        );

        final companions = gen.plots
            .map(
              (p) => PlotsCompanion.insert(
                trialId: trialId,
                plotId: p.plotId,
                plotSortIndex: Value(p.plotSortIndex),
                rep: Value(p.rep),
              ),
            )
            .toList();
        await _plotRepository.insertPlotsBulk(companions);

        final plotRows = await _plotRepository.getPlotsForTrial(trialId);
        if (plotRows.length != gen.plots.length) {
          throw StateError('Plot count mismatch after insert');
        }

        final at = DateTime.now().toUtc();
        for (var i = 0; i < plotRows.length; i++) {
          final tIdx = gen.treatmentIndexPerPlot[i];
          final tid = treatmentIds[tIdx];
          await _assignmentRepository.upsert(
            trialId: trialId,
            plotId: plotRows[i].id,
            treatmentId: tid,
            replication: plotRows[i].rep,
            assignmentSource: 'manual',
            assignedAt: at,
          );
        }

        for (var i = 0; i < input.assessments.length; i++) {
          final a = input.assessments[i];
          final n = a.name.trim();
          if (n.isEmpty) continue;
          final code = 'CUSTOM_${trialId}_${i}_${DateTime.now().microsecondsSinceEpoch}';
          final defId = await _definitionRepository.insertCustom(
            code: code,
            name: n,
            category: 'custom',
            dataType: a.dataType,
            unit: a.unit?.trim().isEmpty ?? true ? null : a.unit!.trim(),
            scaleMin: a.scaleMin,
            scaleMax: a.scaleMax,
            assessmentMethod: null,
            cropPart: null,
            timingCode: null,
            daysAfterTreatment: null,
            timingDescription: null,
            validMin: null,
            validMax: null,
            eppoCode: null,
          );
          await _trialAssessmentRepository.addToTrial(
            trialId: trialId,
            assessmentDefinitionId: defId,
            displayNameOverride: n,
            selectedManually: true,
          );
        }
      });

      return CreateStandaloneTrialWizardResult.ok(trialId);
    } on DuplicateTrialException catch (e) {
      return CreateStandaloneTrialWizardResult.failure(e.toString());
    } catch (e) {
      return CreateStandaloneTrialWizardResult.failure('Could not create trial: $e');
    }
  }
}

String? _optTrim(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}
