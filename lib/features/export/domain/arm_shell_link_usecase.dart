import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/services/shell_storage_service.dart';
import '../../trials/trial_repository.dart';
import '../../../data/services/arm_shell_parser.dart';
import '../../../domain/models/arm_assessment_identity.dart';
import '../../../domain/models/arm_assessment_matcher.dart';
import '../../../domain/models/arm_column_map.dart';
import '../../../domain/models/arm_shell_import.dart';
import '../../plots/plot_repository.dart';
import 'arm_shell_data_plots.dart';
import 'shell_link_preview.dart';

void _proposeShellTaField(
  List<ShellAssessmentFieldChange> out, {
  required int trialAssessmentId,
  required String fieldName,
  required String? currentDb,
  required String? shellRaw,
  bool caseInsensitiveEqual = false,
}) {
  final shellVal = shellRaw?.trim() ?? '';
  if (shellVal.isEmpty) return;
  final cur = currentDb?.trim();
  if (cur != null && cur.isNotEmpty) {
    final same = caseInsensitiveEqual
        ? cur.toUpperCase() == shellVal.toUpperCase()
        : cur == shellVal;
    if (same) return;
    out.add(
      ShellAssessmentFieldChange(
        trialAssessmentId: trialAssessmentId,
        fieldName: fieldName,
        oldValue: cur,
        newValue: shellVal,
        isFillEmpty: false,
      ),
    );
  } else {
    out.add(
      ShellAssessmentFieldChange(
        trialAssessmentId: trialAssessmentId,
        fieldName: fieldName,
        oldValue: currentDb,
        newValue: shellVal,
        isFillEmpty: true,
      ),
    );
  }
}

/// Preview then apply ARM Rating Shell metadata onto a trial (no rating values).
class ArmShellLinkUseCase {
  ArmShellLinkUseCase(
    this._db,
    this._trialRepository,
    this._trialAssessmentRepository,
    this._plotRepository,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final PlotRepository _plotRepository;

  static const ArmAssessmentMatcher _matcher = ArmAssessmentMatcher();

  /// Parses [shellPath], compares to trial [trialId], returns a preview only.
  Future<ShellLinkPreview> preview(int trialId, String shellPath) async {
    return _buildPreview(trialId, shellPath);
  }

  /// Applies changes when [ShellLinkPreview.canApply]; idempotent for same inputs.
  Future<LinkShellResult> apply(int trialId, String shellPath) async {
    final preview = await _buildPreview(trialId, shellPath);
    if (!preview.canApply) {
      return LinkShellResult.failure(
        preview.blockerSummary.isEmpty
            ? 'Rating sheet link blocked.'
            : preview.blockerSummary,
      );
    }

    var trialFieldWriteCount = 0;
    var assessmentWriteCount = 0;

    await _db.transaction(() async {
      for (final ch in preview.trialFieldChanges) {
        switch (ch.fieldName) {
          case 'name':
            await _trialRepository.updateTrialSetup(
              trialId,
              TrialsCompanion(
                name: Value(ch.newValue),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
            trialFieldWriteCount++;
            break;
          case 'protocolNumber':
            await _trialRepository.updateTrialSetup(
              trialId,
              TrialsCompanion(
                protocolNumber: Value(ch.newValue),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
            trialFieldWriteCount++;
            break;
          case 'cooperatorName':
            await _trialRepository.updateTrialSetup(
              trialId,
              TrialsCompanion(
                cooperatorName: Value(ch.newValue),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
            trialFieldWriteCount++;
            break;
          case 'crop':
            await _trialRepository.updateTrialSetup(
              trialId,
              TrialsCompanion(
                crop: Value(ch.newValue),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
            trialFieldWriteCount++;
            break;
        }
      }

      final byTa = <int, Map<String, String>>{};
      for (final ch in preview.assessmentFieldChanges) {
        byTa.putIfAbsent(ch.trialAssessmentId, () => {});
        byTa[ch.trialAssessmentId]![ch.fieldName] = ch.newValue;
      }
      for (final e in byTa.entries) {
        final m = e.value;
        final wrote = await _trialAssessmentRepository.applyArmShellLinkFields(
          id: e.key,
          pestCode: m['pestCode'],
          armShellColumnId: m['arm_shell_column_id'],
          armShellRatingDate: m['arm_shell_rating_date'],
          seName: m['se_name'],
          seDescription: m['se_description'],
          armRatingType: m['arm_rating_type'],
        );
        if (wrote) assessmentWriteCount++;
      }

      // Store shell internally so export doesn't need a file picker.
      String? internalPath;
      try {
        internalPath = await ShellStorageService.storeShell(
          sourcePath: shellPath,
          trialId: trialId,
        );
      } catch (_) {
        // Storage unavailable (e.g. test environment) — continue without.
      }

      await _trialRepository.updateTrialSetup(
        trialId,
        TrialsCompanion(
          armLinkedShellPath: Value(shellPath),
          armLinkedShellAt: Value(DateTime.now().toUtc()),
          shellInternalPath: internalPath != null
              ? Value(internalPath)
              : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

      final warnCodes = preview.issues
          .where((i) => i.severity == ShellLinkIssueSeverity.warn)
          .map((i) => i.code)
          .toList();
      final fieldsUpdatedScalar =
          trialFieldWriteCount + preview.assessmentFieldChanges.length;
      final metadata = jsonEncode({
        'shellFileName': preview.shellFileName,
        'shellPath': shellPath,
        'fieldsUpdatedCount': fieldsUpdatedScalar,
        'assessmentsMatchedCount': preview.matchedAssessmentColumnCount,
        'trialFieldWrites': trialFieldWriteCount,
        'assessmentRowsUpdated': assessmentWriteCount,
        'warnings': warnCodes,
      });

      await _db.into(_db.auditEvents).insert(
            AuditEventsCompanion.insert(
              trialId: Value(trialId),
              eventType: 'arm_shell_linked',
              description: 'Rating sheet linked: ${preview.shellFileName}',
              metadata: Value(metadata),
            ),
          );
    });

    final warnMsgs = preview.issues
        .where((i) => i.severity == ShellLinkIssueSeverity.warn)
        .map((i) => i.message)
        .toList();
    final fieldsUpdatedScalar =
        trialFieldWriteCount + preview.assessmentFieldChanges.length;
    return LinkShellResult.success(
      preview: preview,
      fieldsUpdatedCount: fieldsUpdatedScalar,
      assessmentsMatchedCount: preview.matchedAssessmentColumnCount,
      totalAssessmentsMatched: preview.matchedAssessmentColumnCount,
      totalAssessmentsUnmatched: preview.unmatchedTrialAssessments.length,
      fieldsUpdated: fieldsUpdatedScalar,
      warningMessages: warnMsgs,
    );
  }

  Future<ShellLinkPreview> _buildPreview(int trialId, String shellPath) async {
    final issues = <ShellLinkIssue>[];
    final shellFileName = p.basename(shellPath);

    final trial = await _trialRepository.getTrialById(trialId);
    if (trial == null) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.block,
          code: 'trial_not_found',
          message: 'Trial was not found.',
        ),
      );
      return _emptyPreview(
        issues: issues,
        shellPath: shellPath,
        shellFileName: shellFileName,
      );
    }

    late final ArmShellImport shell;
    try {
      shell = await ArmShellParser(shellPath).parse();
    } on ArgumentError catch (e) {
      issues.add(
        ShellLinkIssue(
          severity: ShellLinkIssueSeverity.block,
          code: 'no_plot_data_sheet',
          message: e.message != null ? '${e.message}' : 'Plot Data sheet missing or invalid.',
        ),
      );
      return _emptyPreview(
        issues: issues,
        shellPath: shellPath,
        shellFileName: shellFileName,
      );
    }

    if (shell.assessmentColumns.isEmpty) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.block,
          code: 'no_assessment_columns',
          message: 'No assessments found on this rating sheet.',
        ),
      );
    }

    final plots = await _plotRepository.getPlotsForTrial(trialId);
    final dataPlots = armShellDataPlots(plots);
    final trialPlotNums = _trialPlotNumbers(dataPlots);
    final shellPlotNums = shell.plotRows.map((r) => r.plotNumber).toSet();
    final matchedPlotNums = trialPlotNums.intersection(shellPlotNums);

    if (shell.plotRows.isNotEmpty && matchedPlotNums.isEmpty) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.block,
          code: 'no_matching_plots',
          message: 'No plot numbers overlap between rating sheet and trial.',
        ),
      );
    }

    if (trial.armLinkedShellPath != null &&
        trial.armLinkedShellPath!.trim().isNotEmpty) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.warn,
          code: 'replace_linked_shell',
          message: 'A rating sheet is already linked to this trial; it will be replaced.',
        ),
      );
    }

    final shellTitle = shell.title.trim();
    if (shellTitle.isNotEmpty && shellTitle != trial.name.trim()) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.warn,
          code: 'title_differs_from_trial_name',
          message: 'Rating sheet title differs from trial name.',
        ),
      );
    }

    if (shell.plotRows.isNotEmpty &&
        matchedPlotNums.isNotEmpty &&
        (matchedPlotNums.length < shellPlotNums.length ||
            matchedPlotNums.length < trialPlotNums.length)) {
      issues.add(
        const ShellLinkIssue(
          severity: ShellLinkIssueSeverity.warn,
          code: 'partial_plot_overlap',
          message: 'Some plot numbers exist only on the rating sheet or only in the trial.',
        ),
      );
    }

    final trialFieldChanges = <ShellTrialFieldChange>[];
    void proposeTrialField(
      String fieldName,
      String? current,
      String? shellRaw,
    ) {
      final shellVal = shellRaw?.trim() ?? '';
      if (shellVal.isEmpty) return;
      final cur = current?.trim();
      if (cur != null && cur.isNotEmpty && cur == shellVal) return;
      if (cur == null || cur.isEmpty) {
        trialFieldChanges.add(
          ShellTrialFieldChange(
            fieldName: fieldName,
            oldValue: current,
            newValue: shellVal,
            isFillEmpty: true,
          ),
        );
      } else {
        trialFieldChanges.add(
          ShellTrialFieldChange(
            fieldName: fieldName,
            oldValue: cur,
            newValue: shellVal,
            isFillEmpty: false,
          ),
        );
      }
    }

    proposeTrialField('name', trial.name, shell.title);
    proposeTrialField('protocolNumber', trial.protocolNumber, shell.trialId);
    proposeTrialField('cooperatorName', trial.cooperatorName, shell.cooperator);
    proposeTrialField('crop', trial.crop, shell.crop);

    final assessments = await _trialAssessmentRepository.getForTrial(trialId);
    final defById = await _loadDefinitions(assessments);

    final sortedAssessments = List<TrialAssessment>.from(assessments);
    final withColIdx =
        assessments.where((a) => a.armImportColumnIndex != null).length;
    if (withColIdx == assessments.length && assessments.isNotEmpty) {
      sortedAssessments.sort(
        (a, b) => a.armImportColumnIndex!.compareTo(b.armImportColumnIndex!),
      );
    } else {
      sortedAssessments.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final effectiveColumns = List<ArmColumnMap>.from(shell.assessmentColumns)
      ..sort((a, b) => a.columnIndex.compareTo(b.columnIndex));

    final matchedShellColumnIndices = <int>{};
    final assessmentFieldChanges = <ShellAssessmentFieldChange>[];
    final unmatchedTrialAssessments = <ShellUnmatchedTrialAssessment>[];

    for (var i = 0; i < sortedAssessments.length; i++) {
      final ta = sortedAssessments[i];
      final def = defById[ta.assessmentDefinitionId];
      final identity = ArmAssessmentIdentity.fromTrialAssessment(ta, def);
      final match = _matcher.findMatchingColumn(
        assessment: identity,
        columns: effectiveColumns,
        armImportColumnIndex: ta.armImportColumnIndex,
        positionalIndex: i,
      );
      final col = match.column;
      if (col == null) {
        unmatchedTrialAssessments.add(
          ShellUnmatchedTrialAssessment(
            trialAssessmentId: ta.id,
            pestCode: ta.pestCode,
            armImportColumnIndex: ta.armImportColumnIndex,
          ),
        );
        continue;
      }
      matchedShellColumnIndices.add(col.columnIndex);

      final shellPest = _shellPestCode(col);
      if (shellPest.isNotEmpty) {
        final cur = ta.pestCode?.trim();
        if (cur == null || cur.isEmpty) {
          assessmentFieldChanges.add(
            ShellAssessmentFieldChange(
              trialAssessmentId: ta.id,
              fieldName: 'pestCode',
              oldValue: cur,
              newValue: shellPest,
              isFillEmpty: true,
            ),
          );
        } else if (cur.toUpperCase() != shellPest.toUpperCase()) {
          assessmentFieldChanges.add(
            ShellAssessmentFieldChange(
              trialAssessmentId: ta.id,
              fieldName: 'pestCode',
              oldValue: cur,
              newValue: shellPest,
              isFillEmpty: false,
            ),
          );
        }
      }

      _proposeShellTaField(
        assessmentFieldChanges,
        trialAssessmentId: ta.id,
        fieldName: 'arm_shell_column_id',
        currentDb: ta.armShellColumnId,
        shellRaw: col.armColumnId,
      );
      _proposeShellTaField(
        assessmentFieldChanges,
        trialAssessmentId: ta.id,
        fieldName: 'arm_shell_rating_date',
        currentDb: ta.armShellRatingDate,
        shellRaw: col.ratingDate,
      );
      _proposeShellTaField(
        assessmentFieldChanges,
        trialAssessmentId: ta.id,
        fieldName: 'se_name',
        currentDb: ta.seName,
        shellRaw: col.seName,
      );
      _proposeShellTaField(
        assessmentFieldChanges,
        trialAssessmentId: ta.id,
        fieldName: 'se_description',
        currentDb: ta.seDescription,
        shellRaw: col.seDescription,
      );
      _proposeShellTaField(
        assessmentFieldChanges,
        trialAssessmentId: ta.id,
        fieldName: 'arm_rating_type',
        currentDb: ta.armRatingType,
        shellRaw: col.ratingType,
      );
    }

    final unmatchedShellColumns = <ShellUnmatchedShellColumn>[];
    for (final c in shell.assessmentColumns) {
      if (!matchedShellColumnIndices.contains(c.columnIndex)) {
        unmatchedShellColumns.add(
          ShellUnmatchedShellColumn(
            armColumnId: c.armColumnId,
            columnLetter: c.columnLetter,
            columnIndex: c.columnIndex,
          ),
        );
      }
    }

    if (unmatchedShellColumns.isNotEmpty) {
      issues.add(
        ShellLinkIssue(
          severity: ShellLinkIssueSeverity.warn,
          code: 'unmatched_shell_columns',
          message:
              '${unmatchedShellColumns.length} assessment(s) from the rating sheet have no match in your trial.',
        ),
      );
    }
    if (unmatchedTrialAssessments.isNotEmpty) {
      issues.add(
        ShellLinkIssue(
          severity: ShellLinkIssueSeverity.warn,
          code: 'unmatched_trial_assessments',
          message:
              '${unmatchedTrialAssessments.length} assessment(s) in your trial are not on the rating sheet.',
        ),
      );
    }

    final matchedAssessmentColumnCount = matchedShellColumnIndices.length;

    issues.add(
      ShellLinkIssue(
        severity: ShellLinkIssueSeverity.info,
        code: 'preview_counts',
        message: 'Planned updates: ${trialFieldChanges.length} trial field(s), '
            '${assessmentFieldChanges.length} assessment field change(s); '
            '$matchedAssessmentColumnCount assessment(s) matched on the rating sheet.',
      ),
    );

    return ShellLinkPreview(
      issues: issues,
      trialFieldChanges: trialFieldChanges,
      assessmentFieldChanges: assessmentFieldChanges,
      unmatchedShellColumns: unmatchedShellColumns,
      unmatchedTrialAssessments: unmatchedTrialAssessments,
      matchedAssessmentColumnCount: matchedAssessmentColumnCount,
      shellFilePath: shellPath,
      shellFileName: shellFileName,
      shellTitle: shell.title.trim(),
      shellPlotCount: shell.plotRows.length,
      trialMatchedPlotCount: matchedPlotNums.length,
      trialPlotCount: trialPlotNums.length,
    );
  }

  ShellLinkPreview _emptyPreview({
    required List<ShellLinkIssue> issues,
    required String shellPath,
    required String shellFileName,
  }) {
    return ShellLinkPreview(
      issues: issues,
      trialFieldChanges: const [],
      assessmentFieldChanges: const [],
      unmatchedShellColumns: const [],
      unmatchedTrialAssessments: const [],
      matchedAssessmentColumnCount: 0,
      shellFilePath: shellPath,
      shellFileName: shellFileName,
      shellTitle: '',
      shellPlotCount: 0,
      trialMatchedPlotCount: 0,
      trialPlotCount: 0,
    );
  }

  Future<Map<int, AssessmentDefinition>> _loadDefinitions(
    List<TrialAssessment> tas,
  ) async {
    final ids = tas.map((e) => e.assessmentDefinitionId).toSet().toList();
    if (ids.isEmpty) return {};
    final defs = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.isIn(ids)))
        .get();
    return {for (final d in defs) d.id: d};
  }

  Set<int> _trialPlotNumbers(List<Plot> dataPlots) {
    final out = <int>{};
    for (final pl in dataPlots) {
      if (pl.armPlotNumber != null) {
        out.add(pl.armPlotNumber!);
        continue;
      }
      final n = int.tryParse(pl.plotId.trim());
      if (n != null) out.add(n);
    }
    return out;
  }

  String _shellPestCode(ArmColumnMap col) {
    final se = col.seName?.trim() ?? '';
    if (se.isNotEmpty) return se.toUpperCase();
    final rt = col.ratingType?.trim() ?? '';
    if (rt.isNotEmpty) return rt.toUpperCase();
    return '';
  }
}
