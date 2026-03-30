import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../data/repositories/assignment_repository.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/repositories/treatment_repository.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/usecases/save_rating_usecase.dart';
import '../../sessions/session_repository.dart';
import '../../trials/trial_repository.dart';
import '../data/arm_assessment_definition_resolver.dart';
import '../data/arm_csv_parser.dart';
import '../data/arm_import_persistence_repository.dart';
import '../data/arm_import_report_builder.dart';
import '../data/arm_import_snapshot_service.dart';
import '../data/compatibility_profile_builder.dart';
import '../domain/models/arm_column_classification.dart';
import '../domain/models/parsed_arm_csv.dart';
import '../domain/models/resolved_arm_assessment_definitions.dart';
import '../domain/models/unknown_pattern_flag.dart';
import '../domain/results/arm_import_result.dart';

/// Orchestrates ARM CSV import: parse → snapshot/profile/report → persist (metadata only in this step).
class ArmImportUseCase {
  ArmImportUseCase(
    this._db,
    this._trialRepository,
    this._treatmentRepository,
    this._plotRepository,
    this._assignmentRepository,
    this._assessmentDefinitionResolver,
    this._trialAssessmentRepository,
    this._sessionRepository,
    this._saveRatingUseCase,
    this._parser,
    this._snapshotService,
    this._profileBuilder,
    this._persistence,
    this._reportBuilder,
  );

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final TreatmentRepository _treatmentRepository;
  final PlotRepository _plotRepository;
  final AssignmentRepository _assignmentRepository;
  final ArmAssessmentDefinitionResolver _assessmentDefinitionResolver;
  final TrialAssessmentRepository _trialAssessmentRepository;
  final SessionRepository _sessionRepository;
  final SaveRatingUseCase _saveRatingUseCase;
  final ArmCsvParser _parser;
  final ArmImportSnapshotService _snapshotService;
  final CompatibilityProfileBuilder _profileBuilder;
  final ArmImportPersistenceRepository _persistence;
  final ArmImportReportBuilder _reportBuilder;

  /// Imports from raw [content] (full CSV text). [sourceFileName] is stored on snapshot / trial ARM fields.
  Future<ArmImportResult> execute(
    String content, {
    required String sourceFileName,
  }) async {
    try {
      if (content.isEmpty) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      List<List<dynamic>> table;
      try {
        table = const CsvToListConverter(eol: '\n').convert(content);
      } catch (_) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      if (table.isEmpty || table.first.isEmpty) {
        return ArmImportResult.failure('Import file is empty or invalid.');
      }

      final headers = table.first.map((c) => c.toString()).toList();
      final dataRows = table.skip(1).toList();

      final parsed = _parser.parse(
        headers: headers,
        rows: dataRows,
        sourceFileName: sourceFileName,
      );

      final snapshotPayload = _snapshotService.buildSnapshot(
        parsed: parsed,
        sourceFile: sourceFileName,
        rawCsv: content,
      );

      final duplicateDetected = await _persistence.existsByChecksum(
        snapshotPayload.rawFileChecksum,
      );

      final priorTrialIds = duplicateDetected
          ? await _persistence.getTrialIdsByChecksum(
              snapshotPayload.rawFileChecksum,
            )
          : const <int>[];

      final profilePayload = _profileBuilder.build(
        parsed: parsed,
        snapshot: snapshotPayload,
      );

      final report = _reportBuilder.build(parsed);

      final trialName = _trialNameFromSourceFile(sourceFileName);

      late int trialId;
      late ResolvedArmAssessmentDefinitions resolvedAssessments;
      late List<String> linkWarnings;
      late int? importSessionId;

      await _db.transaction(() async {
        trialId = await _trialRepository.createTrial(
          name: trialName,
          workspaceType: 'efficacy',
        );

        final treatments = _collectUniqueTreatments(parsed);
        final treatmentCodeToId = <String, int>{};
        for (final treatment in treatments) {
          final id = await _treatmentRepository.insertTreatment(
            trialId: trialId,
            code: treatment.code,
            name: treatment.name,
            treatmentType: treatment.treatmentType,
          );
          treatmentCodeToId[treatment.code] = id;
        }
        assert(treatmentCodeToId.length == treatments.length);

        await _insertPlotsAndAssignments(
          parsed: parsed,
          trialId: trialId,
          treatmentCodeToId: treatmentCodeToId,
        );

        resolvedAssessments = await _assessmentDefinitionResolver.resolveAll(
          trialId: trialId,
          assessments: parsed.assessments,
        );

        linkWarnings = await _insertTrialAssessmentsFromResolved(
          parsed: parsed,
          trialId: trialId,
          assessmentKeyToDefinitionId:
              resolvedAssessments.assessmentKeyToDefinitionId,
        );

        importSessionId = await _createOrReuseImportSession(trialId: trialId);

        final snapshotId = await _persistence.insertImportSnapshot(
          snapshotPayload,
          trialId: trialId,
        );

        await _persistence.insertCompatibilityProfile(
          profilePayload,
          trialId: trialId,
          snapshotId: snapshotId,
        );

        await _persistence.markTrialAsArmLinked(
          trialId: trialId,
          sourceFile: sourceFileName,
          armVersion: snapshotPayload.armVersion,
        );
      });

      if (importSessionId != null) {
        await _importRatingsFromParsedCsv(
          parsed: parsed,
          trialId: trialId,
          importSessionId: importSessionId!,
          assessmentKeyToDefinitionId:
              resolvedAssessments.assessmentKeyToDefinitionId,
        );
      }

      final mergedWarnings = [
        ..._mergeWarningsInOrder(
          report.warnings,
          resolvedAssessments.warnings,
          linkWarnings,
        ),
        if (duplicateDetected)
          'This file appears to have been imported before. Proceed with caution.',
      ];
      final mergedUnknownPatterns = _mergeUnknownPatterns(
        parsed.unknownPatterns,
        resolvedAssessments.unknownPatterns,
      );

      return ArmImportResult.success(
        trialId: trialId,
        importSessionId: importSessionId,
        confidence: parsed.importConfidence,
        warnings: mergedWarnings,
        unknownPatterns: mergedUnknownPatterns,
        duplicateDetected: duplicateDetected,
        priorTrialIds: priorTrialIds,
        plotCount: snapshotPayload.plotCount,
        treatmentCount: snapshotPayload.treatmentCount,
        assessmentCount: snapshotPayload.assessmentCount,
      );
    } on DuplicateTrialException catch (e) {
      return ArmImportResult.failure('ARM import failed: $e');
    } catch (e) {
      return ArmImportResult.failure('ARM import failed: $e');
    }
  }

  /// Inserts one plot per data row (no deduplication). Assignments use plot PKs in
  /// [Plots.id] insertion order, aligned with rows that produced each companion.
  Future<void> _insertPlotsAndAssignments({
    required ParsedArmCsv parsed,
    required int trialId,
    required Map<String, int> treatmentCodeToId,
  }) async {
    final plotHeader = _findHeaderByRole(parsed.columns, 'plotNumber');
    final repHeader = _findHeaderByRole(parsed.columns, 'rep');
    final trtHeader = _findHeaderByRole(parsed.columns, 'treatmentNumber');

    if (plotHeader == null || repHeader == null) {
      return;
    }

    final companions = <PlotsCompanion>[];
    final insertedRowIndices = <int>[];

    for (var i = 0; i < parsed.dataRows.length; i++) {
      final row = parsed.dataRows[i];
      final pv = row[plotHeader];
      if (pv == null || pv.trim().isEmpty) continue;

      final repRaw = row[repHeader];
      final rep = int.tryParse(repRaw ?? '');

      companions.add(
        PlotsCompanion.insert(
          trialId: trialId,
          plotId: pv.trim(),
          plotSortIndex: Value(i + 1),
          rep: Value(rep),
        ),
      );
      insertedRowIndices.add(i);
    }

    if (companions.isEmpty) {
      return;
    }

    await _plotRepository.insertPlotsBulk(companions);

    if (trtHeader == null) {
      return;
    }

    final plotRows = await (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();

    if (plotRows.length != companions.length) {
      throw StateError(
        'Plot insert count ${plotRows.length} does not match companions ${companions.length}.',
      );
    }

    for (var j = 0; j < plotRows.length; j++) {
      final plot = plotRows[j];
      final row = parsed.dataRows[insertedRowIndices[j]];
      final trtRaw = row[trtHeader];
      if (trtRaw == null || trtRaw.trim().isEmpty) continue;

      final code = trtRaw.trim();
      final tid = treatmentCodeToId[code];
      if (tid == null) continue;

      await _assignmentRepository.upsert(
        trialId: trialId,
        plotId: plot.id,
        treatmentId: tid,
        assignmentSource: 'imported',
        assignedAt: DateTime.now().toUtc(),
      );
    }
  }

  /// One [TrialAssessment] per unique [AssessmentToken.assessmentKey], column order.
  Future<List<String>> _insertTrialAssessmentsFromResolved({
    required ParsedArmCsv parsed,
    required int trialId,
    required Map<String, int> assessmentKeyToDefinitionId,
  }) async {
    final linkWarnings = <String>[];
    final seenKeys = <String>{};
    var sortOrder = 0;
    for (final token in parsed.assessments) {
      final key = token.assessmentKey;
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      final defId = assessmentKeyToDefinitionId[key];
      if (defId == null) {
        linkWarnings.add('Assessment could not be linked: $key');
        continue;
      }
      await _trialAssessmentRepository.addToTrial(
        trialId: trialId,
        assessmentDefinitionId: defId,
        displayNameOverride: null,
        required_: false,
        selectedFromProtocol: true,
        selectedManually: false,
        defaultInSessions: true,
        sortOrder: sortOrder,
        isActive: true,
        pestCode: token.armCode,
      );
      sortOrder++;
    }
    return linkWarnings;
  }

  /// Creates [Sessions] + [SessionAssessments] for legacy [Assessments] rows, or
  /// reuses an existing open session when [OpenSessionExistsException] is thrown.
  Future<int?> _createOrReuseImportSession({required int trialId}) async {
    final trialAssessments = await _trialAssessmentRepository.getForTrial(trialId);
    final trialAssessmentIdToLegacyAssessmentId = <int, int>{};
    final legacyAssessmentIds = <int>[];
    for (final ta in trialAssessments) {
      final ids =
          await _trialAssessmentRepository.getOrCreateLegacyAssessmentIdsForTrialAssessments(
        trialId,
        [ta.id],
      );
      if (ids.length == 1) {
        trialAssessmentIdToLegacyAssessmentId[ta.id] = ids.first;
        legacyAssessmentIds.add(ids.first);
      }
    }
    assert(
      trialAssessmentIdToLegacyAssessmentId.length == legacyAssessmentIds.length,
    );
    if (legacyAssessmentIds.isEmpty) {
      return null;
    }

    try {
      final session = await _sessionRepository.createSession(
        trialId: trialId,
        name: 'ARM Import Session',
        sessionDateLocal: _sessionDateLocalToday(),
        assessmentIds: legacyAssessmentIds,
        raterName: null,
        createdByUserId: null,
      );
      return session.id;
    } on OpenSessionExistsException catch (e) {
      final existing = await _sessionRepository.getOpenSession(e.trialId);
      if (existing == null) rethrow;
      return existing.id;
    }
  }

  /// Row index in [ParsedArmCsv.dataRows] → [Plots.id] for rows that produced a plot
  /// companion (same alignment as [_insertPlotsAndAssignments]).
  Future<Map<int, int>> _buildRowIndexToPlotPk({
    required ParsedArmCsv parsed,
    required int trialId,
  }) async {
    final plotHeader = _findHeaderByRole(parsed.columns, 'plotNumber');
    final repHeader = _findHeaderByRole(parsed.columns, 'rep');
    if (plotHeader == null || repHeader == null) {
      return {};
    }
    final insertedRowIndices = <int>[];
    for (var i = 0; i < parsed.dataRows.length; i++) {
      final row = parsed.dataRows[i];
      final pv = row[plotHeader];
      if (pv == null || pv.trim().isEmpty) continue;
      insertedRowIndices.add(i);
    }
    if (insertedRowIndices.isEmpty) {
      return {};
    }
    final plotRows = await (_db.select(_db.plots)
          ..where((p) => p.trialId.equals(trialId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    if (plotRows.length != insertedRowIndices.length) {
      throw StateError(
        'Plot count ${plotRows.length} does not match inserted rows '
        '${insertedRowIndices.length}.',
      );
    }
    final out = <int, int>{};
    for (var k = 0; k < plotRows.length; k++) {
      out[insertedRowIndices[k]] = plotRows[k].id;
    }
    return out;
  }

  /// [AssessmentToken.assessmentKey] → legacy [Assessments.id] for rating rows.
  Future<Map<String, int>> _buildAssessmentKeyToLegacyAssessmentId({
    required int trialId,
    required ParsedArmCsv parsed,
    required Map<String, int> assessmentKeyToDefinitionId,
  }) async {
    final trialAssessments = await _trialAssessmentRepository.getForTrial(trialId);
    final out = <String, int>{};
    final seenKeys = <String>{};
    for (final token in parsed.assessments) {
      final key = token.assessmentKey;
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      final defId = assessmentKeyToDefinitionId[key];
      if (defId == null) continue;
      TrialAssessment? trialAssess;
      for (final t in trialAssessments) {
        if (t.assessmentDefinitionId == defId) {
          trialAssess = t;
          break;
        }
      }
      if (trialAssess == null) continue;
      final ids = await _trialAssessmentRepository
          .getOrCreateLegacyAssessmentIdsForTrialAssessments(
        trialId,
        [trialAssess.id],
      );
      if (ids.length == 1) {
        out[key] = ids.first;
      }
    }
    return out;
  }

  Future<void> _importRatingsFromParsedCsv({
    required ParsedArmCsv parsed,
    required int trialId,
    required int importSessionId,
    required Map<String, int> assessmentKeyToDefinitionId,
  }) async {
    final rowIndexToPlotPk = await _buildRowIndexToPlotPk(
      parsed: parsed,
      trialId: trialId,
    );
    if (rowIndexToPlotPk.isEmpty) {
      return;
    }
    final assessmentKeyToLegacy = await _buildAssessmentKeyToLegacyAssessmentId(
      trialId: trialId,
      parsed: parsed,
      assessmentKeyToDefinitionId: assessmentKeyToDefinitionId,
    );
    if (assessmentKeyToLegacy.isEmpty) {
      return;
    }

    final assessmentColumns =
        parsed.columns.where((c) => c.assessmentToken != null).toList();
    for (var j = 0; j < parsed.dataRows.length; j++) {
      final plotPk = rowIndexToPlotPk[j];
      if (plotPk == null) {
        continue;
      }
      final row = parsed.dataRows[j];
      for (final col in assessmentColumns) {
        final token = col.assessmentToken!;
        final key = token.assessmentKey;
        final legacyId = assessmentKeyToLegacy[key];
        if (legacyId == null) {
          continue;
        }
        final raw = row[col.header];
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }
        final cellValue = raw.trim();
        double? numericValue;
        String? textValue;
        final numeric = double.tryParse(cellValue);
        if (numeric != null) {
          numericValue = numeric;
          textValue = null;
        } else {
          numericValue = null;
          textValue = cellValue;
        }
        final result = await _saveRatingUseCase.execute(
          SaveRatingInput(
            trialId: trialId,
            plotPk: plotPk,
            assessmentId: legacyId,
            sessionId: importSessionId,
            resultStatus: 'RECORDED',
            numericValue: numericValue,
            textValue: textValue,
            isSessionClosed: false,
          ),
        );
        if (!result.isSuccess) {
          throw StateError(result.errorMessage ?? 'Rating save failed');
        }
      }
    }
  }
}

String? _findHeaderByRole(
  List<ArmColumnClassification> columns,
  String role,
) {
  for (final c in columns) {
    if (c.identityRole == role) return c.header;
  }
  return null;
}

List<_ArmTreatmentRow> _collectUniqueTreatments(ParsedArmCsv parsed) {
  final trtHeader = _findHeaderByRole(parsed.columns, 'treatmentNumber');
  if (trtHeader == null) return [];

  final nameHeader = _findHeaderByRole(parsed.columns, 'treatmentName');
  final typeHeader = _findHeaderByRole(parsed.columns, 'type');

  final seen = <String>{};
  final result = <_ArmTreatmentRow>[];

  for (final row in parsed.dataRows) {
    final raw = row[trtHeader];
    if (raw == null || raw.trim().isEmpty) continue;
    final code = raw.trim();
    if (seen.contains(code)) continue;
    seen.add(code);

    final String name;
    if (nameHeader != null) {
      final n = row[nameHeader];
      if (n != null && n.trim().isNotEmpty) {
        name = n.trim();
      } else {
        name = 'Treatment $code';
      }
    } else {
      name = 'Treatment $code';
    }

    String? treatmentType;
    if (typeHeader != null) {
      final t = row[typeHeader];
      if (t != null && t.trim().isNotEmpty) {
        treatmentType = t.trim();
      }
    }

    result.add(_ArmTreatmentRow(
      code: code,
      name: name,
      treatmentType: treatmentType,
    ));
  }

  return result;
}

class _ArmTreatmentRow {
  const _ArmTreatmentRow({
    required this.code,
    required this.name,
    this.treatmentType,
  });

  final String code;
  final String name;
  final String? treatmentType;
}

String _trialNameFromSourceFile(String sourceFileName) {
  final base = p.basename(sourceFileName.trim());
  if (base.isEmpty) return 'ARM import';
  final dot = base.lastIndexOf('.');
  if (dot <= 0) return base;
  return base.substring(0, dot);
}

String _sessionDateLocalToday() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

List<String> _mergeWarningsInOrder(
  List<String> reportWarnings,
  List<String> resolverWarnings,
  List<String> linkWarnings,
) {
  final seen = <String>{};
  final out = <String>[];
  void addAll(Iterable<String> items) {
    for (final w in items) {
      if (seen.add(w)) out.add(w);
    }
  }

  addAll(reportWarnings);
  addAll(resolverWarnings);
  addAll(linkWarnings);
  return out;
}

String _unknownPatternKey(UnknownPatternFlag f) =>
    '${f.type}|${f.severity}|${f.affectsExport}|${f.rawValue}';

List<UnknownPatternFlag> _mergeUnknownPatterns(
  List<UnknownPatternFlag> parsed,
  List<UnknownPatternFlag> resolver,
) {
  final seen = <String>{};
  final out = <UnknownPatternFlag>[];
  for (final f in parsed) {
    final k = _unknownPatternKey(f);
    seen.add(k);
    out.add(f);
  }
  for (final f in resolver) {
    final k = _unknownPatternKey(f);
    if (seen.contains(k)) continue;
    seen.add(k);
    out.add(f);
  }
  return out;
}
