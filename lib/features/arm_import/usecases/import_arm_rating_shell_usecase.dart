import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/services/arm_shell_parser.dart';
import '../../../data/services/shell_storage_service.dart';
import '../../plots/plot_repository.dart';
import '../../trials/trial_repository.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../../data/repositories/treatment_repository.dart';

/// Result of a shell import.
class ShellImportResult {
  final bool success;
  final int? trialId;
  final String? errorMessage;
  final int plotCount;
  final int treatmentCount;
  final int assessmentCount;

  const ShellImportResult._({
    required this.success,
    this.trialId,
    this.errorMessage,
    this.plotCount = 0,
    this.treatmentCount = 0,
    this.assessmentCount = 0,
  });

  factory ShellImportResult.ok({
    required int trialId,
    required int plotCount,
    required int treatmentCount,
    required int assessmentCount,
  }) =>
      ShellImportResult._(
        success: true,
        trialId: trialId,
        plotCount: plotCount,
        treatmentCount: treatmentCount,
        assessmentCount: assessmentCount,
      );

  factory ShellImportResult.failure(String message) =>
      ShellImportResult._(success: false, errorMessage: message);
}

/// Imports a trial directly from an ARM Rating Shell (.xlsx file).
///
/// Reads plot structure, treatments, and full assessment metadata from the
/// Plot Data sheet. Stores the shell internally for later export.
class ImportArmRatingShellUseCase {
  ImportArmRatingShellUseCase({
    required AppDatabase db,
    required TrialRepository trialRepository,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required AssignmentRepository assignmentRepository,
  })  : _db = db,
        _trialRepository = trialRepository,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _trialAssessmentRepository = trialAssessmentRepository,
        _assignmentRepository = assignmentRepository;

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final AssignmentRepository _assignmentRepository;

  Future<ShellImportResult> execute(String shellPath) async {
    try {
      final parser = ArmShellParser(shellPath);
      final shell = await parser.parse();

      if (shell.plotRows.isEmpty) {
        return ShellImportResult.failure('No plot data found in the shell.');
      }
      if (shell.assessmentColumns.isEmpty) {
        return ShellImportResult.failure(
            'No assessment columns found in the shell.');
      }

      final trialName =
          shell.title.isNotEmpty ? shell.title : 'Imported Trial';

      late int trialId;

      await _db.transaction(() async {
        trialId = await _trialRepository.createTrial(
          name: trialName,
          workspaceType: 'efficacy',
          crop: shell.crop,
          location: shell.cooperator,
        );

        // Mark as ARM-linked.
        await (_db.update(_db.trials)
              ..where((t) => t.id.equals(trialId)))
            .write(TrialsCompanion(
          isArmLinked: const Value(true),
          armImportedAt: Value(DateTime.now().toUtc()),
          armSourceFile: Value(shell.shellFilePath),
        ));

        // --- Treatments ---
        // Derive unique treatments from plot rows.
        final trtNumbers = <int>{};
        for (final pr in shell.plotRows) {
          trtNumbers.add(pr.trtNumber);
        }
        final trtIdByNumber = <int, int>{};
        for (final trt in trtNumbers.toList()..sort()) {
          final id = await _treatmentRepository.insertTreatment(
            trialId: trialId,
            code: '$trt',
            name: 'Treatment $trt',
          );
          trtIdByNumber[trt] = id;
        }

        // --- Plots + Assignments ---
        for (final pr in shell.plotRows) {
          final plotPk = await _plotRepository.insertPlot(
            trialId: trialId,
            plotId: '${pr.plotNumber}',
            rep: pr.blockNumber,
            treatmentId: trtIdByNumber[pr.trtNumber],
            plotSortIndex: pr.plotNumber,
          );
          // Set armPlotNumber and armImportDataRowIndex.
          await (_db.update(_db.plots)
                ..where((p) => p.id.equals(plotPk)))
              .write(PlotsCompanion(
            armPlotNumber: Value(pr.plotNumber),
            armImportDataRowIndex: Value(pr.rowIndex),
          ));
          // Assignment record.
          if (trtIdByNumber.containsKey(pr.trtNumber)) {
            await _assignmentRepository.upsert(
              trialId: trialId,
              plotId: plotPk,
              treatmentId: trtIdByNumber[pr.trtNumber]!,
              assignmentSource: 'imported',
            );
          }
        }

        // --- Assessment definitions + TrialAssessments ---
        for (var i = 0; i < shell.assessmentColumns.length; i++) {
          final col = shell.assessmentColumns[i];

          // Create or find an assessment definition.
          final code =
              'SHELL_${col.pestCode ?? col.ratingType ?? 'COL_$i'}'
                  .replaceAll(' ', '_')
                  .toUpperCase();
          final name =
              col.seDescription ?? col.ratingType ?? col.seName ?? 'Assessment ${i + 1}';
          final unit = col.ratingUnit;

          // Check if definition already exists by code.
          var defId = await _findDefinitionByCode(code);
          if (defId == null) {
            defId = await _db.into(_db.assessmentDefinitions).insert(
                  AssessmentDefinitionsCompanion.insert(
                    code: code,
                    name: name,
                    category: 'custom',
                    unit: Value(unit),
                    timingCode: Value(col.ratingDate),
                    eppoCode: Value(col.pestCode),
                    cropPart: Value(col.partRated),
                    appTimingCode: Value(col.appTimingCode),
                    trtEvalInterval: Value(col.trtEvalInterval),
                    collectBasis: Value(col.collectBasis),
                  ),
                );
          }

          final shellIdx = col.columnIndex;

          await _trialAssessmentRepository.addToTrial(
            trialId: trialId,
            assessmentDefinitionId: defId,
            displayNameOverride: name,
            selectedFromProtocol: true,
            selectedManually: false,
            defaultInSessions: true,
            sortOrder: i,
            pestCode: col.pestCode ?? col.seName,
            armImportColumnIndex: shellIdx,
            armColumnIdInteger: col.armColumnIdInteger,
          );
        }
      });

      // Store shell internally (outside transaction — file I/O).
      try {
        final internalPath = await ShellStorageService.storeShell(
          sourcePath: shellPath,
          trialId: trialId,
        );
        await _trialRepository.updateTrialSetup(
          trialId,
          TrialsCompanion(
            shellInternalPath: Value(internalPath),
            armLinkedShellPath: Value(shellPath),
          ),
        );
      } catch (_) {
        // Storage unavailable — continue without internal copy.
      }

      return ShellImportResult.ok(
        trialId: trialId,
        plotCount: shell.plotRows.length,
        treatmentCount:
            shell.plotRows.map((p) => p.trtNumber).toSet().length,
        assessmentCount: shell.assessmentColumns.length,
      );
    } catch (e) {
      return ShellImportResult.failure('Shell import failed: $e');
    }
  }

  Future<int?> _findDefinitionByCode(String code) async {
    final row = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.code.equals(code))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }
}
