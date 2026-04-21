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

  /// After [trialId] is committed, if shell copy or final setup fails, remove the
  /// trial so no half-imported draft remains.
  Future<void> _rollbackFailedShellImport(int trialId) async {
    try {
      final treatments =
          await _treatmentRepository.getTreatmentsForTrial(trialId);
      for (final t in treatments) {
        await _treatmentRepository.softDeleteTreatment(
          t.id,
          deletedBy: 'shell_import_rollback',
        );
      }
      await _trialRepository.softDeleteTrial(
        trialId,
        deletedBy: 'shell_import_rollback',
      );
    } catch (_) {
      // Best-effort after a primary failure.
    }
  }

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

      // 1–4: DB transaction only — trial stays draft, isArmLinked false until
      // structure + internal shell copy succeed.
      final trialId = await _db.transaction<int>(() async {
        final id = await _trialRepository.createTrial(
          name: trialName,
          workspaceType: 'efficacy',
          crop: shell.crop,
          location: shell.cooperator,
        );

        // --- Treatments ---
        final trtNumbers = <int>{};
        for (final pr in shell.plotRows) {
          trtNumbers.add(pr.trtNumber);
        }
        final trtIdByNumber = <int, int>{};
        for (final trt in trtNumbers.toList()..sort()) {
          final tid = await _treatmentRepository.insertTreatment(
            trialId: id,
            code: '$trt',
            name: 'Treatment $trt',
          );
          trtIdByNumber[trt] = tid;
        }

        // --- Plots + Assignments ---
        for (final pr in shell.plotRows) {
          final plotPk = await _plotRepository.insertPlot(
            trialId: id,
            plotId: '${pr.plotNumber}',
            rep: pr.blockNumber,
            treatmentId: trtIdByNumber[pr.trtNumber],
            plotSortIndex: pr.plotNumber,
          );
          await (_db.update(_db.plots)..where((p) => p.id.equals(plotPk)))
              .write(PlotsCompanion(
            armPlotNumber: Value(pr.plotNumber),
            armImportDataRowIndex: Value(pr.rowIndex),
          ));
          if (trtIdByNumber.containsKey(pr.trtNumber)) {
            await _assignmentRepository.upsert(
              trialId: id,
              plotId: plotPk,
              treatmentId: trtIdByNumber[pr.trtNumber]!,
              assignmentSource: 'imported',
            );
          }
        }

        // --- Assessment definitions + TrialAssessments ---
        for (var i = 0; i < shell.assessmentColumns.length; i++) {
          final col = shell.assessmentColumns[i];

          final code =
              'SHELL_${col.pestCode ?? col.ratingType ?? 'COL_$i'}'
                  .replaceAll(' ', '_')
                  .toUpperCase();
          final name =
              col.seDescription ?? col.ratingType ?? col.seName ?? 'Assessment ${i + 1}';
          final unit = col.ratingUnit;

          var defId = await _findDefinitionByCode(code);
          defId ??= await _db.into(_db.assessmentDefinitions).insert(
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

          final shellIdx = col.columnIndex;

          await _trialAssessmentRepository.addToTrial(
            trialId: id,
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

        return id;
      });

      // 5–6: File I/O + mark ARM-linked only when fully successful.
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
            isArmLinked: const Value(true),
            armImportedAt: Value(DateTime.now().toUtc()),
            armSourceFile: Value(shell.shellFilePath),
          ),
        );
      } catch (e) {
        await _rollbackFailedShellImport(trialId);
        return ShellImportResult.failure(
          'Shell import failed: could not store shell or finalize trial ($e)',
        );
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
