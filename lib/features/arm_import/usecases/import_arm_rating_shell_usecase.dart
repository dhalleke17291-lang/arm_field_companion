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

      final trialName = shell.title.isNotEmpty ? shell.title : 'Imported Trial';

      // 1–4: DB transaction only — trial stays draft, isArmLinked false until
      // structure + internal shell copy succeed.
      final trialId = await _db.transaction<int>(() async {
        final id = await _trialRepository.createTrial(
          name: trialName,
          workspaceType: 'efficacy',
          crop: shell.crop,
          location: shell.cooperator,
        );

        // --- Treatments (one protocol check) ---
        final trtNumbers =
            shell.plotRows.map((p) => p.trtNumber).toSet().toList()..sort();
        final trtIdByNumber =
            await _treatmentRepository.insertTreatmentsBulkForNumbers(
                trialId: id, sortedTrtNumbers: trtNumbers);

        // --- Plots (one protocol check) + assignments (one protocol check) ---
        final plotCompanions = shell.plotRows
            .map(
              (pr) => PlotsCompanion.insert(
                trialId: id,
                plotId: '${pr.plotNumber}',
                plotSortIndex: Value(pr.plotNumber),
                rep: Value(pr.blockNumber),
                treatmentId: Value(trtIdByNumber[pr.trtNumber]),
                armPlotNumber: Value(pr.plotNumber),
                armImportDataRowIndex: Value(pr.rowIndex),
              ),
            )
            .toList();
        await _plotRepository.insertPlotsBulk(plotCompanions);

        final plotsForTrial = await _plotRepository.getPlotsForTrial(id);
        final plotPkByPlotId = <String, int>{
          for (final p in plotsForTrial) p.plotId: p.id,
        };
        final assignmentMap = <int, int?>{};
        for (final pr in shell.plotRows) {
          final pk = plotPkByPlotId['${pr.plotNumber}'];
          if (pk == null) continue;
          assignmentMap[pk] = trtIdByNumber[pr.trtNumber];
        }
        await _assignmentRepository.upsertBulk(
          trialId: id,
          plotPkToTreatmentId: assignmentMap,
          assignmentSource: 'imported',
        );

        // --- Assessment definitions + TrialAssessments (one protocol check) ---
        final assessmentRows = <TrialAssessmentsCompanion>[];
        for (var i = 0; i < shell.assessmentColumns.length; i++) {
          final col = shell.assessmentColumns[i];

          final pestCode = _firstNonEmpty([col.pestCode, col.seName]);
          final codeKey = _firstNonEmpty([pestCode, col.ratingType]) ?? 'COL_$i';
          final code =
              'SHELL_$codeKey'.replaceAll(' ', '_').toUpperCase();
          final name = _firstNonEmpty([
                col.seDescription,
                col.ratingType,
                col.seName,
                pestCode,
              ]) ??
              'Assessment ${i + 1}';
          final unit = col.ratingUnit;

          var defId = await _findDefinitionByCode(code);
          defId ??= await _db.into(_db.assessmentDefinitions).insert(
                AssessmentDefinitionsCompanion.insert(
                  code: code,
                  name: name,
                  category: 'custom',
                  unit: Value(unit),
                  timingCode: Value(col.ratingDate),
                  eppoCode: Value(pestCode),
                  cropPart: Value(col.partRated),
                  appTimingCode: Value(col.appTimingCode),
                  trtEvalInterval: Value(col.trtEvalInterval),
                  collectBasis: Value(col.collectBasis),
                ),
              );

          final shellIdx = col.columnIndex;

          assessmentRows.add(
            TrialAssessmentsCompanion.insert(
              trialId: id,
              assessmentDefinitionId: defId,
              displayNameOverride: Value(name),
              selectedFromProtocol: const Value(true),
              selectedManually: const Value(false),
              defaultInSessions: const Value(true),
              sortOrder: Value(i),
              pestCode: Value(pestCode),
              armImportColumnIndex: Value(shellIdx),
              armColumnIdInteger: Value(col.armColumnIdInteger),
              // Shell metadata drives AssessmentDisplayHelper.compactName /
              // fullName so the rating screen can render rich labels
              // (description + SE code) instead of "Assessment {id}".
              seDescription: Value(_firstNonEmpty([col.seDescription])),
              seName: Value(_firstNonEmpty([col.seName, col.pestCode])),
              armRatingType: Value(_firstNonEmpty([col.ratingType])),
              armShellColumnId: Value(_firstNonEmpty([col.armColumnId])),
              armShellRatingDate: Value(_firstNonEmpty([col.ratingDate])),
            ),
          );
        }
        await _trialAssessmentRepository
            .insertTrialAssessmentsBulk(assessmentRows);

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
        treatmentCount: shell.plotRows.map((p) => p.trtNumber).toSet().length,
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

/// Returns the first trimmed value in [values] that is non-null and non-empty.
///
/// `??` alone is unsafe for shell metadata because the XLSX parser can return
/// an empty string (`<v></v>`) for a present-but-blank cell, which would
/// short-circuit a `col.seDescription ?? col.ratingType ?? col.seName` chain
/// at the blank before ever considering the next candidate.
String? _firstNonEmpty(Iterable<String?> values) {
  for (final v in values) {
    final t = v?.trim();
    if (t != null && t.isNotEmpty) return t;
  }
  return null;
}
