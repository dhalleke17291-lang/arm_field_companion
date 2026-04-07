import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/excel_column_letters.dart';
import '../../../core/diagnostics/diagnostic_finding.dart';
import '../../../core/diagnostics/trial_export_diagnostics.dart'
    show kArmRatingShellExportAttemptLabel;
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../../../data/services/arm_shell_parser.dart';
import '../../../data/services/arm_value_injector.dart';
import '../../../domain/models/arm_assessment_identity.dart';
import '../../../domain/models/arm_assessment_matcher.dart';
import '../../../domain/models/arm_column_map.dart';
import '../../../domain/models/arm_rating_value.dart';
import '../../../domain/models/arm_round_trip_diagnostics.dart';
import '../../arm_import/data/arm_csv_parser.dart';
import '../../arm_import/data/arm_import_persistence_repository.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../../sessions/session_repository.dart';
import '../export_confidence_policy.dart';
import '../export_trial_usecase.dart' show PublishTrialExportDiagnostics;
import 'arm_rating_shell_cell_value.dart';
import 'arm_rating_shell_export_block_policy.dart';
import 'arm_shell_data_plots.dart';
import 'arm_rating_shell_result.dart';
import 'compute_arm_round_trip_diagnostics_usecase.dart';

/// Optional share override for tests (avoids platform Share).
typedef ArmRatingShellShareOverride = Future<void> Function(String filePath);

class ExportArmRatingShellUseCase {
  static const ArmAssessmentMatcher _armAssessmentMatcher =
      ArmAssessmentMatcher();

  final AppDatabase _db;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final RatingRepository _ratingRepository;
  final ArmImportPersistenceRepository _persistence;
  final ArmRatingShellShareOverride? shareOverride;

  /// Test-only: bypass [FilePicker] and return a shell `.xlsx` path (or null to cancel).
  final Future<String?> Function()? pickShellPathOverride;

  ExportArmRatingShellUseCase({
    required AppDatabase db,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required RatingRepository ratingRepository,
    required SessionRepository sessionRepository,
    required ArmImportPersistenceRepository persistence,
    this.shareOverride,
    this.pickShellPathOverride,
    PublishTrialExportDiagnostics? publishExportDiagnostics,
  })  : _db = db,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _trialAssessmentRepository = trialAssessmentRepository,
        _ratingRepository = ratingRepository,
        _persistence = persistence,
        _publishExportDiagnostics = publishExportDiagnostics,
        _computeArmRoundTripDiagnostics =
            ComputeArmRoundTripDiagnosticsUseCase(
          plotRepository: plotRepository,
          trialAssessmentRepository: trialAssessmentRepository,
          sessionRepository: sessionRepository,
          ratingRepository: ratingRepository,
        );

  final PublishTrialExportDiagnostics? _publishExportDiagnostics;
  final ComputeArmRoundTripDiagnosticsUseCase _computeArmRoundTripDiagnostics;

  Future<ArmRatingShellResult> execute({
    required Trial trial,
    /// When true, file is written but [Share] / [shareOverride] are skipped (UI shares with sheet origin).
    bool suppressShare = false,
  }) async {
    if (!trial.isArmLinked) {
      throw StateError(
        'ExportArmRatingShellUseCase must only be called for ARM-linked trials. '
        'Use ExportTrialUseCase for standalone trials.',
      );
    }

    final trialPk = trial.id;
    final exportDiagnosticsBuffer = <DiagnosticFinding>[];

    void publishExportDiagnostics() {
      _publishExportDiagnostics?.call(
        trialPk,
        List<DiagnosticFinding>.unmodifiable(
          List<DiagnosticFinding>.from(exportDiagnosticsBuffer),
        ),
        kArmRatingShellExportAttemptLabel,
      );
    }

    final profile = await _persistence.getLatestCompatibilityProfileForTrial(
      trial.id,
    );
    final gate = gateFromConfidence(profile?.exportConfidence);
    if (gate == ExportGate.block) {
      final msg = composeBlockedExportMessage(profile?.exportBlockReason);
      final finding = gate.toDiagnosticFinding(trialId: trialPk, message: msg);
      if (finding != null) exportDiagnosticsBuffer.add(finding);
      publishExportDiagnostics();
      return ArmRatingShellResult.failure(msg);
    }
    String? confidenceWarningMessage;
    if (gate == ExportGate.warn) {
      confidenceWarningMessage = kWarnExportMessage;
      final finding = gate.toDiagnosticFinding(
        trialId: trialPk,
        message: confidenceWarningMessage,
      );
      if (finding != null) exportDiagnosticsBuffer.add(finding);
    }
    final shellWarnings = <String>[];
    final warnedNullPestTaIds = <int>{};

    final loaded = await Future.wait([
      _plotRepository.getPlotsForTrial(trial.id),
      _trialAssessmentRepository.getForTrial(trial.id),
      _treatmentRepository.getTreatmentsForTrial(trial.id),
    ]);
    final plots = loaded[0] as List<Plot>;
    final shellDataPlots = armShellDataPlots(plots);
    final assessments = loaded[1] as List<TrialAssessment>;
    // ignore: unused_local_variable
    final treatments = loaded[2] as List<Treatment>;

    final roundTripReport = await _computeArmRoundTripDiagnostics.execute(
      trial: trial,
      plots: plots,
      assessments: assessments,
    );
    exportDiagnosticsBuffer.addAll(roundTripReport.toDiagnosticFindings());

    if (trial.isArmLinked &&
        shellDataPlots.isNotEmpty &&
        shellDataPlots.any((p) => p.armPlotNumber == null)) {
      debugPrint(
        'ExportArmRatingShell: trial ${trial.id} has data plots without armPlotNumber; '
        'shell plot matching may use plotId fallback.',
      );
    }

    if (plots.isEmpty) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_no_plots',
          severity: DiagnosticSeverity.blocker,
          message: 'No plots found for trial.',
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: true,
        ),
      );
      publishExportDiagnostics();
      return ArmRatingShellResult.failure('No plots found for trial.');
    }
    if (assessments.isEmpty) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_no_assessments',
          severity: DiagnosticSeverity.blocker,
          message: 'No assessments found for trial.',
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: true,
        ),
      );
      publishExportDiagnostics();
      return ArmRatingShellResult.failure('No assessments found for trial.');
    }

    final strictBlock = evaluateArmRatingShellStrictBlock(roundTripReport);
    if (strictBlock.blocksExport) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_strict_structural_block',
          severity: DiagnosticSeverity.blocker,
          message: strictBlock.userMessage,
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: true,
        ),
      );
      publishExportDiagnostics();
      return ArmRatingShellResult.failure(strictBlock.userMessage);
    }

    final defById = await _loadDefinitionsForTrialAssessments(assessments);
    final snapshot = profile != null
        ? await (_db.select(_db.importSnapshots)
              ..where((s) => s.id.equals(profile.snapshotId)))
            .getSingleOrNull()
        : null;

    final columnOrderOnExport = _parseColumnOrderJson(profile?.columnOrderOnExport);
    var assessmentColumns = _filterAssessmentColumns(
      columnOrderOnExport,
      assessments,
      defById,
      shellWarnings,
      warnedNullPestTaIds,
    );

    if (assessmentColumns.isEmpty) {
      assessmentColumns = _fallbackAssessmentHeadersFromSnapshot(snapshot) ??
          _fallbackAssessmentHeadersFromTrialAssessments(assessments, defById);
    }

    if (assessmentColumns.isEmpty) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_no_columns',
          severity: DiagnosticSeverity.blocker,
          message: 'No assessment columns could be determined.',
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: true,
        ),
      );
      publishExportDiagnostics();
      return ArmRatingShellResult.failure(
        'No assessment columns could be determined.',
      );
    }

    // ignore: unused_local_variable
    final snapshotTokens = _parseAssessmentTokens(snapshot?.assessmentTokens);

    final sessionId = roundTripReport.resolvedShellSessionId!;

    final String? shellPath;
    if (pickShellPathOverride != null) {
      shellPath = await pickShellPathOverride!();
      if (shellPath == null) {
        exportDiagnosticsBuffer.add(
          DiagnosticFinding(
            code: 'arm_rating_shell_cancelled',
            severity: DiagnosticSeverity.info,
            message: 'Export cancelled.',
            trialId: trialPk,
            source: DiagnosticSource.exportValidation,
            blocksExport: false,
          ),
        );
        publishExportDiagnostics();
        return ArmRatingShellResult.failure('Export cancelled.');
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        dialogTitle: 'Select ARM Rating Shell for ${trial.name}',
      );
      if (result == null || result.files.isEmpty) {
        exportDiagnosticsBuffer.add(
          DiagnosticFinding(
            code: 'arm_rating_shell_cancelled',
            severity: DiagnosticSeverity.info,
            message: 'Export cancelled.',
            trialId: trialPk,
            source: DiagnosticSource.exportValidation,
            blocksExport: false,
          ),
        );
        publishExportDiagnostics();
        return ArmRatingShellResult.failure('Export cancelled.');
      }
      shellPath = result.files.single.path;
    }
    if (shellPath == null) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_cancelled',
          severity: DiagnosticSeverity.info,
          message: 'Export cancelled.',
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: false,
        ),
      );
      publishExportDiagnostics();
      return ArmRatingShellResult.failure('Export cancelled.');
    }

    final parser = ArmShellParser(shellPath);
    final shellImport = await parser.parse();

    final sortedAssessments = List<TrialAssessment>.from(assessments);
    final withColIdx =
        assessments.where((a) => a.armImportColumnIndex != null).length;
    if (withColIdx == assessments.length && assessments.isNotEmpty) {
      sortedAssessments.sort(
        (a, b) => a.armImportColumnIndex!.compareTo(b.armImportColumnIndex!),
      );
    } else {
      if (assessments.isNotEmpty && withColIdx > 0) {
        debugPrint(
          'ExportArmRatingShell: trial ${trial.id} has mixed '
          'armImportColumnIndex; using sortOrder for assessment order.',
        );
      } else if (assessments.isNotEmpty && withColIdx == 0) {
        debugPrint(
          'ExportArmRatingShell: trial ${trial.id} has no armImportColumnIndex '
          'on trial_assessments; using sortOrder (legacy data).',
        );
      }
      sortedAssessments.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final effectiveColumns = shellImport.assessmentColumns.isNotEmpty
        ? (List<ArmColumnMap>.from(shellImport.assessmentColumns)
            ..sort((a, b) => a.columnIndex.compareTo(b.columnIndex)))
        : List.generate(
            sortedAssessments.length,
            (i) {
              final colIdx = 2 + i;
              final letter = columnIndexToLettersZeroBased(colIdx);
              return ArmColumnMap(
                armColumnId: letter,
                columnLetter: letter,
                columnIndex: colIdx,
              );
            },
          );

    if (shellImport.assessmentColumns.isNotEmpty) {
      for (var i = 0; i < sortedAssessments.length; i++) {
        if (i >= effectiveColumns.length) break;
        final ta = sortedAssessments[i];
        final col = effectiveColumns[i];
        final seCode = ta.pestCode?.trim().toUpperCase();
        final shellSeName = col.seName?.trim().toUpperCase();
        if (seCode != null &&
            shellSeName != null &&
            seCode != shellSeName) {
          debugPrint(
            'ExportArmRatingShell: positional mismatch warning — '
            'assessment[$i] pestCode="$seCode" but shell column '
            '"${col.columnLetter}" seName="$shellSeName". '
            'Injecting positionally.',
          );
        }
        final pc = ta.pestCode?.trim();
        if (pc != null && pc.isNotEmpty) {
          _logSeCodeMismatch(shellImport.assessmentColumns, pc, i);
        }
      }
    }

    final positionalFallbackTrialAssessmentIds = <int>{};
    final ratingValues = <ArmRatingValue>[];
    for (final pr in shellImport.plotRows) {
      final plot = _plotForShellPlotNumber(shellDataPlots, pr.plotNumber);
      if (plot == null) {
        debugPrint(
          'ExportArmRatingShell: no app plot for shell '
          'plotNumber ${pr.plotNumber}',
        );
        continue;
      }
      for (var i = 0; i < sortedAssessments.length; i++) {
        final ta = sortedAssessments[i];
        final def = defById[ta.assessmentDefinitionId];
        final identity = ArmAssessmentIdentity.fromTrialAssessment(ta, def);
        final match = _armAssessmentMatcher.findMatchingColumn(
          assessment: identity,
          columns: effectiveColumns,
          armImportColumnIndex: ta.armImportColumnIndex,
          positionalIndex: i,
          logDebug: debugPrint,
        );
        if (match.wasPositionalFallback) {
          positionalFallbackTrialAssessmentIds.add(ta.id);
        }
        final col = match.column;
        if (col == null) continue;

        final legacyId = ta.legacyAssessmentId;
        if (legacyId == null) continue;

        final rating = await _ratingRepository.getCurrentRating(
          trialId: trial.id,
          plotPk: plot.id,
          assessmentId: legacyId,
          sessionId: sessionId,
        );
        final valueStr = armRatingShellCellValueFromRating(rating);
        ratingValues.add(
          ArmRatingValue(
            plotNumber: pr.plotNumber,
            armColumnId: col.armColumnId,
            value: valueStr,
          ),
        );
      }
    }

    if (positionalFallbackTrialAssessmentIds.isNotEmpty) {
      final ids = positionalFallbackTrialAssessmentIds.toList()..sort();
      exportDiagnosticsBuffer.add(
        ArmRoundTripDiagnostic(
          code: ArmRoundTripDiagnosticCode.fallbackAssessmentMatchUsed,
          severity: ArmRoundTripDiagnosticSeverity.warning,
          message:
              'One or more trial assessments used positional shell column '
              'matching; armImportColumnIndex and rating type/unit did not '
              'resolve a unique column.',
          detail: 'TrialAssessment ids: ${ids.join(", ")}',
          trialId: trialPk,
          sessionId: sessionId,
        ).toDiagnosticFinding(),
      );

      final deterministic = deterministicAssessmentAnchorsExpectedForShellExport(
        assessments: assessments,
        latestProfileExportConfidence: profile?.exportConfidence,
      );
      final fallbackStrict = evaluateArmRatingShellStrictBlock(
        roundTripReport,
        positionalAssessmentFallbackUsed: true,
        deterministicAssessmentAnchorsExpected: deterministic,
      );
      if (fallbackStrict.blocksExport) {
        exportDiagnosticsBuffer.add(
          DiagnosticFinding(
            code: 'arm_rating_shell_strict_structural_block',
            severity: DiagnosticSeverity.blocker,
            message: fallbackStrict.userMessage,
            trialId: trialPk,
            source: DiagnosticSource.exportValidation,
            blocksExport: true,
          ),
        );
        publishExportDiagnostics();
        return ArmRatingShellResult.failure(fallbackStrict.userMessage);
      }
    }

    final injector = ArmValueInjector(shellImport);
    final safeBase = trial.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .trim();
    final safeName = safeBase.isEmpty ? 'trial_${trial.id}' : safeBase;
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${safeName}_RatingShell_filled.xlsx';
    await injector.inject(ratingValues, filePath);

    if (!suppressShare) {
      if (shareOverride != null) {
        await shareOverride!(filePath);
      } else {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          text: '${trial.name} – ARM Rating Shell',
        );
      }
    }

    for (var i = 0; i < shellWarnings.length; i++) {
      exportDiagnosticsBuffer.add(
        DiagnosticFinding(
          code: 'arm_rating_shell_warn_$i',
          severity: DiagnosticSeverity.warning,
          message: shellWarnings[i],
          trialId: trialPk,
          source: DiagnosticSource.exportValidation,
          blocksExport: false,
        ),
      );
    }
    publishExportDiagnostics();
    return ArmRatingShellResult.ok(
      filePath: filePath,
      warningMessage:
          _mergeWarnings(confidenceWarningMessage, shellWarnings),
    );
  }

  /// Prefer [Plot.armPlotNumber]. On duplicates, lowest [Plot.id] wins.
  /// Falls back to [Plot.plotId] int/string match (legacy).
  ///
  /// [plots] must be shell data plots only ([armShellDataPlots]); guard rows are
  /// never matched to shell rows.
  Plot? _plotForShellPlotNumber(List<Plot> plots, int plotNumber) {
    final byArm = plots.where((p) => p.armPlotNumber == plotNumber).toList();
    if (byArm.length > 1) {
      debugPrint(
        'ExportArmRatingShell: ${byArm.length} plots share armPlotNumber='
        '$plotNumber; using lowest Plots.id.',
      );
      byArm.sort((a, b) => a.id.compareTo(b.id));
      return byArm.first;
    }
    if (byArm.length == 1) return byArm.single;

    final fallback = plots.where((p) {
      final n = int.tryParse(p.plotId.trim());
      if (n != null) return n == plotNumber;
      return p.plotId.trim() == plotNumber.toString();
    }).toList();
    if (fallback.length > 1) {
      debugPrint(
        'ExportArmRatingShell: ${fallback.length} plots match shell '
        'plotNumber=$plotNumber via plotId; using lowest Plots.id.',
      );
      fallback.sort((a, b) => a.id.compareTo(b.id));
      return fallback.first;
    }
    if (fallback.length == 1) {
      return fallback.single;
    }
    return null;
  }

  void _logSeCodeMismatch(
    List<ArmColumnMap> columns,
    String seCode,
    int positionIndex,
  ) {
    final match = columns.where(
      (c) => c.seName?.trim().toUpperCase() == seCode.toUpperCase(),
    );
    if (match.isEmpty) {
      debugPrint(
        'ExportArmRatingShellUseCase: validation — seCode '
        '"$seCode" at position $positionIndex has no matching '
        'shell column by name. Injecting positionally.',
      );
    }
  }

  String? _mergeWarnings(String? base, List<String> shell) {
    if (shell.isEmpty) return base;
    final buf = StringBuffer();
    if (base != null && base.isNotEmpty) buf.writeln(base);
    for (final w in shell) {
      buf.writeln(w);
    }
    return buf.toString().trim();
  }

  void _addNullPestWarningIfNeeded(
    List<String> shellWarnings,
    TrialAssessment ta,
    String definitionCode,
    Set<int> warnedTaIds,
  ) {
    if (ta.pestCode != null && ta.pestCode!.trim().isNotEmpty) return;
    if (warnedTaIds.contains(ta.id)) return;
    warnedTaIds.add(ta.id);
    shellWarnings.add(
      'unknownPattern: TrialAssessment id=${ta.id} missing pestCode; '
      'matched definition code $definitionCode',
    );
  }

  Future<Map<int, AssessmentDefinition>> _loadDefinitionsForTrialAssessments(
    List<TrialAssessment> assessments,
  ) async {
    final ids = assessments.map((e) => e.assessmentDefinitionId).toSet();
    if (ids.isEmpty) return {};
    final defs = await (_db.select(_db.assessmentDefinitions)
          ..where((d) => d.id.isIn(ids)))
        .get();
    return {for (final d in defs) d.id: d};
  }

  List<String> _parseColumnOrderJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'ARM Rating Shell: columnOrderOnExport JSON parse failed: $e\n$st',
        );
      }
    }
    return [];
  }

  List<String> _filterAssessmentColumns(
    List<String> columnOrderOnExport,
    List<TrialAssessment> tas,
    Map<int, AssessmentDefinition> defById,
    List<String> shellWarnings,
    Set<int> warnedNullPestTaIds,
  ) {
    return columnOrderOnExport
        .where(
          (h) => _headerMatchesAssessmentColumn(
            h,
            tas,
            defById,
            shellWarnings,
            warnedNullPestTaIds,
          ),
        )
        .toList();
  }

  bool _headerMatchesAssessmentColumn(
    String h,
    List<TrialAssessment> tas,
    Map<int, AssessmentDefinition> defById,
    List<String> shellWarnings,
    Set<int> warnedNullPestTaIds,
  ) {
    final parser = ArmCsvParser();
    final withPest = tas
        .where((t) => t.pestCode != null && t.pestCode!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.pestCode!.length.compareTo(a.pestCode!.length));
    for (final ta in withPest) {
      final def = defById[ta.assessmentDefinitionId];
      final id = ArmAssessmentIdentity.fromTrialAssessment(ta, def);
      final parsed = parser.tryParseAssessmentToken(h);
      if (parsed != null &&
          parsed.toIdentity().canonicalKey == id.canonicalKey) {
        return true;
      }
      if (h.contains(ta.pestCode!)) return true;
    }
    for (final ta in tas) {
      if (ta.pestCode != null && ta.pestCode!.trim().isNotEmpty) continue;
      final def = defById[ta.assessmentDefinitionId];
      if (def == null || def.code.trim().isEmpty) continue;
      final id = ArmAssessmentIdentity.fromTrialAssessment(ta, def);
      final parsed = parser.tryParseAssessmentToken(h);
      if (parsed != null &&
          parsed.toIdentity().canonicalKey == id.canonicalKey) {
        _addNullPestWarningIfNeeded(
          shellWarnings,
          ta,
          def.code,
          warnedNullPestTaIds,
        );
        return true;
      }
      if (h.contains(def.code)) {
        _addNullPestWarningIfNeeded(
          shellWarnings,
          ta,
          def.code,
          warnedNullPestTaIds,
        );
        return true;
      }
    }
    return false;
  }

  List<String>? _fallbackAssessmentHeadersFromSnapshot(ImportSnapshot? snap) {
    if (snap == null) return null;
    try {
      final decoded = jsonDecode(snap.assessmentTokens) as List<dynamic>;
      return decoded
          .map((e) => (e as Map<String, dynamic>)['rawHeader'] as String).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'ARM Rating Shell: fallback assessment headers from snapshot failed: $e\n$st',
        );
      }
      return null;
    }
  }

  List<String> _fallbackAssessmentHeadersFromTrialAssessments(
    List<TrialAssessment> tas,
    Map<int, AssessmentDefinition> defById,
  ) {
    final sorted = [...tas]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final out = <String>[];
    for (final ta in sorted) {
      final def = defById[ta.assessmentDefinitionId];
      if (def == null || def.code.trim().isEmpty) continue;
      final tc = def.timingCode?.trim() ?? '';
      out.add(tc.isEmpty ? def.code : '${def.code} $tc');
    }
    return out;
  }

  List<Map<String, dynamic>>? _parseAssessmentTokens(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'ARM Rating Shell: assessmentTokens JSON parse failed: $e\n$st',
        );
      }
      return null;
    }
  }

}
