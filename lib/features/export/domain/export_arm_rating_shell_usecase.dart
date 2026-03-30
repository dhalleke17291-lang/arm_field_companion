import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../../arm_import/data/arm_import_persistence_repository.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../export_confidence_policy.dart';
import 'arm_rating_shell_result.dart';

/// Optional share override for tests (avoids platform Share).
typedef ArmRatingShellShareOverride = Future<void> Function(String filePath);

class ExportArmRatingShellUseCase {
  final AppDatabase _db;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final RatingRepository _ratingRepository;
  final ArmImportPersistenceRepository _persistence;
  final ArmRatingShellShareOverride? shareOverride;

  ExportArmRatingShellUseCase({
    required AppDatabase db,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required TrialAssessmentRepository trialAssessmentRepository,
    required RatingRepository ratingRepository,
    required ArmImportPersistenceRepository persistence,
    this.shareOverride,
  })  : _db = db,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _trialAssessmentRepository = trialAssessmentRepository,
        _ratingRepository = ratingRepository,
        _persistence = persistence;

  Future<ArmRatingShellResult> execute({
    required Trial trial,
    /// When true, file is written but [Share] / [shareOverride] are skipped (UI shares with sheet origin).
    bool suppressShare = false,
  }) async {
    final profile = await _persistence.getLatestCompatibilityProfileForTrial(
      trial.id,
    );
    final gate = gateFromConfidence(profile?.exportConfidence);
    if (gate == ExportGate.block) {
      var msg = kBlockedExportMessage;
      final reason = profile?.exportBlockReason;
      if (reason != null && reason.trim().isNotEmpty) {
        msg = '$msg Reason: $reason';
      }
      return ArmRatingShellResult.failure(msg);
    }
    String? confidenceWarningMessage;
    if (gate == ExportGate.warn) {
      confidenceWarningMessage = kWarnExportMessage;
    }
    final shellWarnings = <String>[];
    final warnedNullPestTaIds = <int>{};

    final loaded = await Future.wait([
      _plotRepository.getPlotsForTrial(trial.id),
      _trialAssessmentRepository.getForTrial(trial.id),
      _treatmentRepository.getTreatmentsForTrial(trial.id),
    ]);
    final plots = loaded[0] as List<Plot>;
    final assessments = loaded[1] as List<TrialAssessment>;
    final treatments = loaded[2] as List<Treatment>;

    if (plots.isEmpty) {
      return ArmRatingShellResult.failure('No plots found for trial.');
    }
    if (assessments.isEmpty) {
      return ArmRatingShellResult.failure('No assessments found for trial.');
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
      return ArmRatingShellResult.failure(
        'No assessment columns could be determined.',
      );
    }

    final tokens = _parseAssessmentTokens(snapshot?.assessmentTokens);

    // STEP 3 — treatment lookup by numeric key derived from treatment code.
    final treatmentByNumber = <int, Treatment>{
      for (final t in treatments) _treatmentNumberKey(t): t,
    };

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    _setCellText(sheet, 0, 0, trial.name);

    _setCellText(sheet, 1, 0, 'Plot No.');
    _setCellText(sheet, 1, 1, 'trt');
    _setCellText(sheet, 1, 2, 'reps');
    _setCellText(sheet, 1, 3, 'Treatment Name');
    for (var i = 0; i < assessmentColumns.length; i++) {
      _setCellText(sheet, 1, 4 + i, assessmentColumns[i]);
    }

    final sortedPlots = [...plots]..sort((a, b) {
        final ka = _plotNumberKey(a);
        final kb = _plotNumberKey(b);
        return ka.compareTo(kb);
      });

    final sessionId = await _resolveMostRecentSessionId(trial.id);

    for (var plotIndex = 0; plotIndex < sortedPlots.length; plotIndex++) {
      final plot = sortedPlots[plotIndex];
      final row = 2 + plotIndex;
      final treatmentId = await _treatmentIdForPlot(plot.id, trial.id);
      final effectiveTreatment = treatmentId == null
          ? null
          : treatments.firstWhereOrNull((t) => t.id == treatmentId);
      final treatmentKey =
          effectiveTreatment != null ? _treatmentNumberKey(effectiveTreatment) : null;
      final treatmentFromMap = treatmentKey != null
          ? treatmentByNumber[treatmentKey]
          : null;
      final tRow = (treatmentFromMap != null &&
              effectiveTreatment != null &&
              treatmentFromMap.id == effectiveTreatment.id)
          ? treatmentFromMap
          : effectiveTreatment;

      _setCellText(sheet, row, 0, plot.plotId);
      _setCellText(
        sheet,
        row,
        1,
        tRow?.code ?? '',
      );
      _setCellText(
        sheet,
        row,
        2,
        plot.rep != null ? plot.rep.toString() : '',
      );
      _setCellText(
        sheet,
        row,
        3,
        tRow?.name ?? '',
      );

      for (var ai = 0; ai < assessmentColumns.length; ai++) {
        final header = assessmentColumns[ai];
        final col = 4 + ai;
        if (sessionId == null) {
          _setCellText(sheet, row, col, '');
          continue;
        }
        final ta = _matchTrialAssessmentForHeader(
          header,
          assessments,
          defById,
          tokens,
          shellWarnings,
          warnedNullPestTaIds,
        );
        final legacyId = ta?.legacyAssessmentId;
        if (legacyId == null) {
          _setCellText(sheet, row, col, '');
          continue;
        }
        final rating = await _ratingRepository.getCurrentRating(
          trialId: trial.id,
          plotPk: plot.id,
          assessmentId: legacyId,
          sessionId: sessionId,
        );
        if (rating == null) {
          _setCellText(sheet, row, col, '');
          continue;
        }
        if (rating.numericValue != null) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
              .value = DoubleCellValue(rating.numericValue!);
        } else if (rating.textValue != null &&
            rating.textValue!.trim().isNotEmpty) {
          _setCellText(sheet, row, col, rating.textValue!);
        } else {
          _setCellText(sheet, row, col, '');
        }
      }
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = trial.name
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .trim()
            .isEmpty
        ? 'trial_${trial.id}'
        : trial.name
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        '${tempDir.path}/AGQ_${safeName}_RatingShell_$timestamp.xlsx';

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      return ArmRatingShellResult.failure('Failed to encode Excel file.');
    }
    await File(filePath).writeAsBytes(fileBytes);

    if (!suppressShare) {
      if (shareOverride != null) {
        await shareOverride!(filePath);
      } else {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: '${trial.name} – ARM Rating Shell',
        );
      }
    }

    return ArmRatingShellResult.ok(
      filePath: filePath,
      warningMessage:
          _mergeWarnings(confidenceWarningMessage, shellWarnings),
    );
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
    } catch (_) {}
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
    final withPest = tas
        .where((t) => t.pestCode != null && t.pestCode!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.pestCode!.length.compareTo(a.pestCode!.length));
    for (final ta in withPest) {
      if (h.contains(ta.pestCode!)) return true;
    }
    for (final ta in tas) {
      if (ta.pestCode != null && ta.pestCode!.trim().isNotEmpty) continue;
      final def = defById[ta.assessmentDefinitionId];
      if (def != null &&
          def.code.trim().isNotEmpty &&
          h.contains(def.code)) {
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
    } catch (_) {
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
    } catch (_) {
      return null;
    }
  }

  int _treatmentNumberKey(Treatment t) {
    final n = int.tryParse(t.code.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null) return n;
    return int.tryParse(t.code) ?? t.id;
  }

  /// ARM plot label order: parse [Plot.plotId] as int when possible (101, 201);
  /// otherwise [plotSortIndex], then database id.
  int _plotNumberKey(Plot p) {
    final n = int.tryParse(p.plotId.trim());
    if (n != null) return n;
    return p.plotSortIndex ?? p.id;
  }

  Future<int?> _treatmentIdForPlot(int plotPk, int trialId) async {
    final assign = await (_db.select(_db.assignments)
          ..where((a) => a.plotId.equals(plotPk) & a.trialId.equals(trialId)))
        .getSingleOrNull();
    if (assign?.treatmentId != null) return assign!.treatmentId;
    final plot = await (_db.select(_db.plots)..where((p) => p.id.equals(plotPk)))
        .getSingleOrNull();
    return plot?.treatmentId;
  }

  Future<int?> _resolveMostRecentSessionId(int trialId) async {
    final row = await (_db.select(_db.sessions)
          ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  TrialAssessment? _matchTrialAssessmentForHeader(
    String header,
    List<TrialAssessment> tas,
    Map<int, AssessmentDefinition> defById,
    List<Map<String, dynamic>>? tokens,
    List<String> shellWarnings,
    Set<int> warnedNullPestTaIds,
  ) {
    final withPest = tas
        .where((t) => t.pestCode != null && t.pestCode!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.pestCode!.length.compareTo(a.pestCode!.length));
    for (final ta in withPest) {
      if (header.contains(ta.pestCode!)) return ta;
    }

    if (tokens != null) {
      for (final t in tokens) {
        if (t['rawHeader'] != header) continue;
        final ac = (t['armCode'] as String?)?.trim();
        final tc = (t['timingCode'] as String?)?.trim() ?? '';
        if (ac == null) continue;
        for (final ta in tas) {
          final pc = ta.pestCode?.trim();
          if (pc != null && pc.toUpperCase() == ac.toUpperCase()) {
            final def = defById[ta.assessmentDefinitionId];
            final defTiming = def?.timingCode?.trim() ?? '';
            if (tc.isEmpty || defTiming == tc) return ta;
          }
        }
        for (final ta in tas) {
          final def = defById[ta.assessmentDefinitionId];
          if (def == null) continue;
          if (def.code.toUpperCase() == ac.toUpperCase()) {
            final defTiming = def.timingCode?.trim() ?? '';
            if (tc.isEmpty || defTiming == tc) {
              _addNullPestWarningIfNeeded(
                shellWarnings,
                ta,
                def.code,
                warnedNullPestTaIds,
              );
              return ta;
            }
          }
        }
      }
    }

    for (final ta in tas) {
      if (ta.pestCode != null && ta.pestCode!.trim().isNotEmpty) continue;
      final def = defById[ta.assessmentDefinitionId];
      if (def != null &&
          def.code.trim().isNotEmpty &&
          header.contains(def.code)) {
        _addNullPestWarningIfNeeded(
          shellWarnings,
          ta,
          def.code,
          warnedNullPestTaIds,
        );
        return ta;
      }
    }
    return null;
  }

  void _setCellText(Sheet sheet, int row, int col, String text) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(text);
  }
}
