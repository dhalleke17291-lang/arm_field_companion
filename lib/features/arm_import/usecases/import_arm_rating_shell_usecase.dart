import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/session_state.dart';
import '../../../data/arm/arm_applications_repository.dart';
import '../../../data/arm/arm_column_mapping_repository.dart';
import '../../../data/repositories/trial_assessment_repository.dart';
import '../../../data/services/arm_shell_parser.dart';
import '../../../data/services/shell_storage_service.dart';
import '../../../domain/models/arm_column_map.dart';
import '../data/shell_rating_date_parser.dart';
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

  /// Number of **deduplicated** assessments created (= number of unique
  /// `(SE Name, Part Rated, Rating Type, Rating Unit)` tuples in the shell,
  /// not the number of ARM columns). See [ShellImportResult.armColumnCount]
  /// for the raw shell-column count.
  final int assessmentCount;

  /// Number of planned sessions created (= number of unique Rating Dates
  /// across all ARM columns). Sessions start in `'planned'` status and
  /// transition to `'open'` / `'closed'` through normal session flow.
  final int plannedSessionCount;

  /// Total number of ARM columns recorded in `arm_column_mappings`,
  /// including orphans with blank measurement metadata.
  final int armColumnCount;

  const ShellImportResult._({
    required this.success,
    this.trialId,
    this.errorMessage,
    this.plotCount = 0,
    this.treatmentCount = 0,
    this.assessmentCount = 0,
    this.plannedSessionCount = 0,
    this.armColumnCount = 0,
  });

  factory ShellImportResult.ok({
    required int trialId,
    required int plotCount,
    required int treatmentCount,
    required int assessmentCount,
    required int plannedSessionCount,
    required int armColumnCount,
  }) =>
      ShellImportResult._(
        success: true,
        trialId: trialId,
        plotCount: plotCount,
        treatmentCount: treatmentCount,
        assessmentCount: assessmentCount,
        plannedSessionCount: plannedSessionCount,
        armColumnCount: armColumnCount,
      );

  factory ShellImportResult.failure(String message) =>
      ShellImportResult._(success: false, errorMessage: message);
}

/// Imports a trial directly from an ARM Rating Shell (.xlsx file).
///
/// **Phase 1b model.** This importer no longer creates one `trial_assessment`
/// per ARM column. Instead it:
///
/// 1. **Deduplicates** ARM assessment columns into distinct `trial_assessments`
///    keyed by `(SE Name, Part Rated, Rating Type, Rating Unit)`. ARM models a
///    repeated "Weed Control" assessment across three dates as three separate
///    columns; this app models it as one assessment rated in three sessions.
/// 2. **Plans a session per unique Rating Date**, in status
///    [kSessionStatusPlanned]. A user transitions a planned session to
///    `open` / `closed` through normal session flow when they start rating.
/// 3. **Records the mapping** between each ARM column and its
///    `(trial_assessment, session)` pair in `arm_column_mappings`. This is
///    the bridge that lets export reproduce the shell's per-column-per-date
///    shape without forcing the core data model to mirror it.
/// 4. Writes verbatim ARM metadata to `arm_assessment_metadata` (one row per
///    deduplicated assessment) and `arm_session_metadata` (one row per
///    planned session) so round-trip export can reproduce the shell's
///    header exactly.
///
/// Orphan ARM columns — those with all measurement identity fields blank —
/// are preserved in `arm_column_mappings` with null `trial_assessment_id`
/// and `session_id` so export can re-emit them as empty columns without
/// breaking shell structure. They never surface in the UI.
///
/// The legacy per-column fields on `trial_assessments`
/// (`armImportColumnIndex`, `armColumnIdInteger`, `seName`, `seDescription`,
/// `armRatingType`, `armShellColumnId`, `armShellRatingDate`, `pestCode`)
/// are populated from the **first** ARM column in each dedup group. They
/// are grandfathered on core tables until Phase 0b migrates them onto the
/// extension tables; `arm_column_mappings` + `arm_assessment_metadata`
/// are the authoritative source from Phase 1b forward.
class ImportArmRatingShellUseCase {
  ImportArmRatingShellUseCase({
    required AppDatabase db,
    required TrialRepository trialRepository,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    // Kept in the signature for source-level compat; the new importer writes
    // trial_assessments directly inside the transaction because it needs the
    // inserted row id per dedup group (the bulk repo method returns nothing).
    // ignore: avoid_unused_constructor_parameters
    required TrialAssessmentRepository trialAssessmentRepository,
    required AssignmentRepository assignmentRepository,
    required ArmColumnMappingRepository armColumnMappingRepository,
    required ArmApplicationsRepository armApplicationsRepository,
  })  : _db = db,
        _trialRepository = trialRepository,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _assignmentRepository = assignmentRepository,
        _armColumnMappingRepository = armColumnMappingRepository,
        _armApplicationsRepository = armApplicationsRepository;

  final AppDatabase _db;
  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final AssignmentRepository _assignmentRepository;
  final ArmColumnMappingRepository _armColumnMappingRepository;
  final ArmApplicationsRepository _armApplicationsRepository;

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
      final plan = await _db.transaction<_ImportPlanOutcome>(() async {
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

        // --- Enrich treatments from the Treatments sheet (Phase 2b) ---
        //
        // insertTreatmentsBulkForNumbers creates bare rows (name =
        // "Treatment N", no type, no components). If the shell parsed a
        // Treatments sheet, enrich each row with the product / rate /
        // formulation data and write the ARM-specific coding
        // (armTypeCode, Form Conc / Unit / Type, row sort order) to
        // arm_treatment_metadata so round-trip export reproduces the
        // sheet verbatim.
        //
        // Dual-write rationale (see audit in PR for Phase 2b):
        //   - Treatments.treatmentType AND arm_treatment_metadata.armTypeCode
        //     both receive ARM's Type code. Core keeps working for
        //     control-treatment detection + display; AAM preserves the
        //     verbatim coding for round-trip even if core value is ever
        //     humanized.
        //   - Treatments.name AND TreatmentComponents.productName both
        //     receive the ARM Treatment Name when non-blank. Blank names
        //     (typical for CHK / untreated-check rows) keep the default
        //     "Treatment N" and get no component row.
        //   - CHK rows still receive an AAM row so the Treatments-sheet
        //     ordering round-trips correctly.
        final sheetRowByTrt = {
          for (final r in shell.treatmentSheetRows) r.trtNumber: r,
        };
        for (final entry in trtIdByNumber.entries) {
          final trtNum = entry.key;
          final trtId = entry.value;
          final sheetRow = sheetRowByTrt[trtNum];
          if (sheetRow == null) continue;

          final name = sheetRow.treatmentName;
          final type = sheetRow.typeCode;
          final hasNameOrType =
              (name != null && name.isNotEmpty) ||
                  (type != null && type.isNotEmpty);
          if (hasNameOrType) {
            await (_db.update(_db.treatments)
                  ..where((t) => t.id.equals(trtId)))
                .write(
              TreatmentsCompanion(
                name: name != null && name.isNotEmpty
                    ? Value(name)
                    : const Value.absent(),
                treatmentType: type != null && type.isNotEmpty
                    ? Value(type)
                    : const Value.absent(),
                lastEditedAt: Value(DateTime.now()),
              ),
            );
          }

          if (name != null && name.isNotEmpty) {
            await _db.into(_db.treatmentComponents).insert(
                  TreatmentComponentsCompanion.insert(
                    treatmentId: trtId,
                    trialId: id,
                    productName: name,
                    rate: Value(sheetRow.rate),
                    rateUnit: Value(sheetRow.rateUnit),
                    sortOrder: Value(sheetRow.rowIndex),
                  ),
                );
          }

          await _db.into(_db.armTreatmentMetadata).insert(
                ArmTreatmentMetadataCompanion.insert(
                  treatmentId: trtId,
                  armTypeCode: type != null && type.isNotEmpty
                      ? Value(type)
                      : const Value.absent(),
                  formConc: Value(sheetRow.formConc),
                  formConcUnit: Value(sheetRow.formConcUnit),
                  formType: Value(sheetRow.formType),
                  armRowSortOrder: Value(sheetRow.rowIndex),
                ),
              );
        }

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

        // --- Applications sheet → trial_application_events + arm_applications ---
        //
        // Universal fields that map cleanly to [TrialApplicationEvents] are
        // dual-written from known descriptor rows; the full 79-row verbatim
        // block is always stored on [ArmApplications] for round-trip.
        for (final appCol in shell.applicationSheetColumns) {
          final rows = appCol.row01To79;
          final rawDate = rows[0];
          if (rawDate == null) continue;
          final parsed = tryParseShellRatingDate(rawDate);
          if (parsed == null) continue;
          final appDate = parsed.startedAtUtc;

          Value<String?> str(int i) {
            final s = rows[i];
            if (s == null) return const Value.absent();
            return Value(s);
          }

          Value<double?> dbl(int i) {
            final s = rows[i];
            if (s == null) return const Value.absent();
            final d = double.tryParse(s);
            if (d == null) return const Value.absent();
            return Value(d);
          }

          final event = await _db.into(_db.trialApplicationEvents).insertReturning(
                TrialApplicationEventsCompanion.insert(
                  trialId: id,
                  applicationDate: appDate,
                  applicationTime: str(1),
                  applicationMethod: str(5),
                  operatorName: str(8),
                  equipmentUsed: Value(_applicationEquipmentDualWrite(rows)),
                  temperature: dbl(9),
                  humidity: dbl(12),
                  windSpeed: dbl(14),
                  windDirection: str(17),
                  cloudCoverPct: dbl(26),
                  soilMoisture: str(24),
                  soilTemperature: dbl(22),
                  nozzleType: str(39),
                  operatingPressure: dbl(37),
                  pressureUnit: str(38),
                  groundSpeed: dbl(62),
                  speedUnit: str(63),
                  waterVolume: dbl(70),
                  waterVolumeUnit: str(71),
                  spraySolutionPh: dbl(76),
                  status: const Value('applied'),
                  appliedAt: Value(appDate),
                ),
              );

          await _armApplicationsRepository.upsertForEvent(
            event.id,
            _armApplicationsCompanionFromRows(
              trialApplicationEventId: event.id,
              armSheetColumnIndex: appCol.columnIndex,
              rows: rows,
            ),
          );
        }

        // --- Dedup assessment columns + plan sessions ---
        //
        // Two parallel groupings over shell.assessmentColumns:
        //   - by dedup key (SE Name | Part Rated | Rating Type | Rating Unit)
        //     → one trial_assessment + one arm_assessment_metadata per group;
        //   - by Rating Date                                  → one planned
        //     session + one arm_session_metadata per unique date.
        //
        // Both mappings feed the final arm_column_mappings bridge: one row per
        // ARM column, keyed to its dedup group and its date. Orphan columns
        // (no identity fields) stay unmapped on both sides — they only live
        // in arm_column_mappings with null FKs so round-trip export can still
        // emit them as structurally present but empty.
        final dedupGroups = _groupColumnsByDedupKey(shell.assessmentColumns);

        final dedupAssessmentIds = <String, int>{};
        var sortOrder = 0;
        for (final entry in dedupGroups.entries) {
          final first = entry.value.first;
          final pestCode =
              _firstNonEmpty([first.pestCodeFromSheet, first.seName]);
          final codeKey =
              _firstNonEmpty([pestCode, first.ratingType]) ?? entry.key;
          final code = 'SHELL_$codeKey'.replaceAll(' ', '_').toUpperCase();
          final name = _firstNonEmpty([
                first.seDescription,
                first.ratingType,
                first.seName,
                pestCode,
              ]) ??
              'Assessment ${sortOrder + 1}';
          final unit = first.ratingUnit;

          var defId = await _findDefinitionByCode(code);
          defId ??= await _db.into(_db.assessmentDefinitions).insert(
                AssessmentDefinitionsCompanion.insert(
                  code: code,
                  name: name,
                  category: 'custom',
                  unit: Value(unit),
                  // The definition's timingCode was historically set from the
                  // first column's ratingDate. With dedup, a single definition
                  // may span multiple dates — the per-column rating date moves
                  // to arm_session_metadata / arm_column_mappings. Keep the
                  // first-column date here for backward compat with
                  // ArmAssessmentMatcher (legacy exporter fallback) and the
                  // protocol-token heuristics.
                  timingCode: Value(first.ratingDate),
                  eppoCode: Value(pestCode),
                  cropPart: Value(first.partRated),
                  appTimingCode: Value(first.appTimingCode),
                  trtEvalInterval: Value(first.trtEvalInterval),
                  collectBasis: Value(first.collectBasis),
                ),
              );

          final taId = await _db.into(_db.trialAssessments).insert(
                TrialAssessmentsCompanion.insert(
                  trialId: id,
                  assessmentDefinitionId: defId,
                  displayNameOverride: Value(name),
                  selectedFromProtocol: const Value(true),
                  selectedManually: const Value(false),
                  defaultInSessions: const Value(true),
                  sortOrder: Value(sortOrder),
                ),
              );

          dedupAssessmentIds[entry.key] = taId;

          // Unit 5d: pestCode / seName / seDescription / armRatingType now
          // live only on arm_assessment_metadata. The four per-column ARM
          // anchor fields (armImportColumnIndex, armColumnIdInteger,
          // armShellColumnId, armShellRatingDate) moved to AAM in v60.
          await _armColumnMappingRepository.insertAssessmentMetadataBulk([
            ArmAssessmentMetadataCompanion.insert(
              trialAssessmentId: taId,
              seName: Value(_firstNonEmpty([first.seName])),
              seDescription: Value(_firstNonEmpty([first.seDescription])),
              partRated: Value(_firstNonEmpty([first.partRated])),
              ratingType: Value(_firstNonEmpty([first.ratingType])),
              ratingUnit: Value(_firstNonEmpty([first.ratingUnit])),
              collectBasis: Value(_firstNonEmpty([first.collectBasis])),
              numSubsamples: Value(first.numSubsamples),
              pestCode: Value(pestCode),
              armImportColumnIndex: Value(first.columnIndex),
              armColumnIdInteger: Value(first.armColumnIdInteger),
              armShellColumnId: Value(_firstNonEmpty([first.armColumnId])),
              armShellRatingDate: Value(_firstNonEmpty([first.ratingDate])),
              shellPestType: Value(_firstNonEmpty([first.pestType])),
              shellPestName: Value(_firstNonEmpty([first.pestName])),
              shellCropCode: Value(_firstNonEmpty([first.cropCodeArm])),
              shellCropName: Value(_firstNonEmpty([first.cropNameArm])),
              shellCropVariety: Value(_firstNonEmpty([first.cropVariety])),
              shellRatingTime: Value(_firstNonEmpty([first.ratingTime])),
              shellCropOrPest: Value(_firstNonEmpty([first.cropOrPest])),
              shellSampleSize: Value(_firstNonEmpty([first.sampleSize])),
              shellSizeUnit: Value(_firstNonEmpty([first.sizeUnit])),
              shellCollectionBasisUnit:
                  Value(_firstNonEmpty([first.collectionBasisUnit])),
              shellReportingBasis: Value(_firstNonEmpty([first.reportingBasis])),
              shellReportingBasisUnit:
                  Value(_firstNonEmpty([first.reportingBasisUnit])),
              shellStageScale: Value(_firstNonEmpty([first.stageScale])),
              shellCropStageMaj: Value(_firstNonEmpty([first.cropStageMaj])),
              shellCropStageMin: Value(_firstNonEmpty([first.cropStageMin])),
              shellCropStageMax: Value(_firstNonEmpty([first.cropStageMax])),
              shellCropDensity: Value(_firstNonEmpty([first.cropDensity])),
              shellCropDensityUnit:
                  Value(_firstNonEmpty([first.cropDensityUnit])),
              shellPestStageMaj: Value(_firstNonEmpty([first.pestStageMaj])),
              shellPestStageMin: Value(_firstNonEmpty([first.pestStageMin])),
              shellPestStageMax: Value(_firstNonEmpty([first.pestStageMax])),
              shellPestDensity: Value(_firstNonEmpty([first.pestDensity])),
              shellPestDensityUnit:
                  Value(_firstNonEmpty([first.pestDensityUnit])),
              shellAssessedBy: Value(_firstNonEmpty([first.assessedBy])),
              shellEquipment: Value(_firstNonEmpty([first.equipment])),
              shellUntreatedRatingType:
                  Value(_firstNonEmpty([first.untreatedRatingType])),
              shellArmActions: Value(_firstNonEmpty([first.armActions])),
              shellAppTimingCode: Value(_firstNonEmpty([first.appTimingCode])),
              shellTrtEvalInterval:
                  Value(_firstNonEmpty([first.trtEvalInterval])),
              shellPlantEvalInterval:
                  Value(_firstNonEmpty([first.datInterval])),
            ),
          ]);

          sortOrder++;
        }

        // --- Plan one session per unique Rating Date ---
        //
        // Planned sessions: endedAt null, status 'planned'. They do not
        // surface as "open" field sessions (see session_repository filters);
        // they appear in session lists as pre-scheduled slots the user will
        // later start.
        final dateToSessionId = <String, int>{};
        final sortedDates = shell.assessmentColumns
            .map((c) => c.ratingDate?.trim())
            .whereType<String>()
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        for (final dateStr in sortedDates) {
          final parsed = tryParseShellRatingDate(dateStr);
          final sessionDateLocal = parsed?.canonicalYyyyMmDd ?? dateStr.trim();
          final sessionName = 'Planned — $sessionDateLocal';
          final repCol = shell.assessmentColumns.firstWhere(
            (c) => (c.ratingDate?.trim() ?? '') == dateStr,
          );
          final rater = _firstNonEmpty([repCol.assessedBy]);

          final sessionId = await _db.into(_db.sessions).insert(
                SessionsCompanion.insert(
                  trialId: id,
                  name: sessionName,
                  sessionDateLocal: sessionDateLocal,
                  startedAt: parsed != null
                      ? Value(parsed.startedAtUtc)
                      : const Value.absent(),
                  raterName: rater != null ? Value(rater) : const Value.absent(),
                  status: const Value(kSessionStatusPlanned),
                ),
              );
          dateToSessionId[dateStr] = sessionId;

          // One representative column per date seeds the session-level ARM
          // metadata (timing code / crop stage / DA-A intervals). ARM can in
          // principle assign slightly different crop-stage text per column on
          // the same date; if the shell carries that divergence we keep the
          // first column's values here and let export regenerate per-column
          // text from arm_column_mappings + the original shell.
          await _armColumnMappingRepository.insertSessionMetadataBulk([
            ArmSessionMetadataCompanion.insert(
              sessionId: sessionId,
              armRatingDate: sessionDateLocal,
              timingCode: Value(_firstNonEmpty([repCol.appTimingCode])),
              cropStageMaj: Value(_firstNonEmpty([repCol.cropStageMaj])),
              cropStageMin: Value(_firstNonEmpty([repCol.cropStageMin])),
              cropStageScale: Value(_firstNonEmpty([repCol.stageScale])),
              trtEvalInterval:
                  Value(_firstNonEmpty([repCol.trtEvalInterval])),
              plantEvalInterval: Value(_firstNonEmpty([repCol.datInterval])),
              raterInitials: Value(_firstNonEmpty([repCol.assessedBy])),
            ),
          ]);
        }

        // --- Column mappings: one row per ARM column ---
        final mappingRows = <ArmColumnMappingsCompanion>[];
        for (final col in shell.assessmentColumns) {
          final key = _dedupKeyFor(col);
          final taId = key == null ? null : dedupAssessmentIds[key];
          final sessionId = (col.ratingDate?.trim().isNotEmpty ?? false)
              ? dateToSessionId[col.ratingDate!.trim()]
              : null;

          mappingRows.add(
            ArmColumnMappingsCompanion.insert(
              trialId: id,
              armColumnId: col.armColumnId,
              armColumnIndex: col.columnIndex,
              armColumnIdInteger: Value(col.armColumnIdInteger),
              trialAssessmentId: Value(taId),
              sessionId: Value(sessionId),
            ),
          );
        }
        await _armColumnMappingRepository.insertBulk(mappingRows);

        return _ImportPlanOutcome(
          trialId: id,
          dedupAssessmentCount: dedupAssessmentIds.length,
          plannedSessionCount: dateToSessionId.length,
          armColumnCount: shell.assessmentColumns.length,
          plotCount: shell.plotRows.length,
          treatmentCount: trtNumbers.length,
        );
      });

      // 5–6: File I/O + mark ARM-linked only when fully successful.
      try {
        final internalPath = await ShellStorageService.storeShell(
          sourcePath: shellPath,
          trialId: plan.trialId,
        );
        await _db.into(_db.armTrialMetadata).insertOnConflictUpdate(
              ArmTrialMetadataCompanion(
                trialId: Value(plan.trialId),
                isArmLinked: const Value(true),
                armImportedAt: Value(DateTime.now().toUtc()),
                armSourceFile: Value(shell.shellFilePath),
                shellInternalPath: Value(internalPath),
                armLinkedShellPath: Value(shellPath),
              ),
            );
        await _trialRepository.updateTrialSetup(
          plan.trialId,
          TrialsCompanion(
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      } catch (e) {
        await _rollbackFailedShellImport(plan.trialId);
        return ShellImportResult.failure(
          'Shell import failed: could not store shell or finalize trial ($e)',
        );
      }

      return ShellImportResult.ok(
        trialId: plan.trialId,
        plotCount: plan.plotCount,
        treatmentCount: plan.treatmentCount,
        assessmentCount: plan.dedupAssessmentCount,
        plannedSessionCount: plan.plannedSessionCount,
        armColumnCount: plan.armColumnCount,
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

  /// Groups ARM columns by dedup key preserving shell column order for each
  /// group. Orphan columns (all identity fields blank) are omitted — they get
  /// a mapping row with null FKs but no trial_assessment.
  Map<String, List<ArmColumnMap>> _groupColumnsByDedupKey(
    List<ArmColumnMap> columns,
  ) {
    final result = <String, List<ArmColumnMap>>{};
    for (final col in columns) {
      final key = _dedupKeyFor(col);
      if (key == null) continue;
      result.putIfAbsent(key, () => <ArmColumnMap>[]).add(col);
    }
    return result;
  }

  /// Dedup identity: `(SE Name | Part Rated | Rating Type | Rating Unit)`.
  /// Returns null for orphan columns (all four fields blank). Each non-null
  /// value is trimmed and uppercased so "W003"/"w003" / trailing-whitespace
  /// collide into the same assessment.
  String? _dedupKeyFor(ArmColumnMap col) {
    final seName = col.seName?.trim();
    final partRated = col.partRated?.trim();
    final ratingType = col.ratingType?.trim();
    final ratingUnit = col.ratingUnit?.trim();
    if ((seName == null || seName.isEmpty) &&
        (partRated == null || partRated.isEmpty) &&
        (ratingType == null || ratingType.isEmpty) &&
        (ratingUnit == null || ratingUnit.isEmpty)) {
      return null;
    }
    return [
      seName?.toUpperCase() ?? '',
      partRated?.toUpperCase() ?? '',
      ratingType?.toUpperCase() ?? '',
      ratingUnit?.toUpperCase() ?? '',
    ].join('|');
  }
}

class _ImportPlanOutcome {
  const _ImportPlanOutcome({
    required this.trialId,
    required this.dedupAssessmentCount,
    required this.plannedSessionCount,
    required this.armColumnCount,
    required this.plotCount,
    required this.treatmentCount,
  });

  final int trialId;
  final int dedupAssessmentCount;
  final int plannedSessionCount;
  final int armColumnCount;
  final int plotCount;
  final int treatmentCount;
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

/// Applications sheet R36–R37 (0-based indices 35–36): Equipment + Type →
/// one core field (matches `arm_applications.row36` / `row37`).
String? _applicationEquipmentDualWrite(List<String?> rows) {
  final a = rows[35]?.trim();
  final b = rows[36]?.trim();
  final parts = <String>[
    if (a != null && a.isNotEmpty) a,
    if (b != null && b.isNotEmpty) b,
  ];
  if (parts.isEmpty) return null;
  return parts.join(' / ');
}

ArmApplicationsCompanion _armApplicationsCompanionFromRows({
  required String trialApplicationEventId,
  required int armSheetColumnIndex,
  required List<String?> rows,
}) {
  assert(rows.length == 79);
  Value<String?> rv(int i) {
    final s = rows[i];
    if (s == null) return const Value.absent();
    return Value(s);
  }
  return ArmApplicationsCompanion.insert(
    trialApplicationEventId: trialApplicationEventId,
    armSheetColumnIndex: Value(armSheetColumnIndex),
    row01: rv(0),
    row02: rv(1),
    row03: rv(2),
    row04: rv(3),
    row05: rv(4),
    row06: rv(5),
    row07: rv(6),
    row08: rv(7),
    row09: rv(8),
    row10: rv(9),
    row11: rv(10),
    row12: rv(11),
    row13: rv(12),
    row14: rv(13),
    row15: rv(14),
    row16: rv(15),
    row17: rv(16),
    row18: rv(17),
    row19: rv(18),
    row20: rv(19),
    row21: rv(20),
    row22: rv(21),
    row23: rv(22),
    row24: rv(23),
    row25: rv(24),
    row26: rv(25),
    row27: rv(26),
    row28: rv(27),
    row29: rv(28),
    row30: rv(29),
    row31: rv(30),
    row32: rv(31),
    row33: rv(32),
    row34: rv(33),
    row35: rv(34),
    row36: rv(35),
    row37: rv(36),
    row38: rv(37),
    row39: rv(38),
    row40: rv(39),
    row41: rv(40),
    row42: rv(41),
    row43: rv(42),
    row44: rv(43),
    row45: rv(44),
    row46: rv(45),
    row47: rv(46),
    row48: rv(47),
    row49: rv(48),
    row50: rv(49),
    row51: rv(50),
    row52: rv(51),
    row53: rv(52),
    row54: rv(53),
    row55: rv(54),
    row56: rv(55),
    row57: rv(56),
    row58: rv(57),
    row59: rv(58),
    row60: rv(59),
    row61: rv(60),
    row62: rv(61),
    row63: rv(62),
    row64: rv(63),
    row65: rv(64),
    row66: rv(65),
    row67: rv(66),
    row68: rv(67),
    row69: rv(68),
    row70: rv(69),
    row71: rv(70),
    row72: rv(71),
    row73: rv(72),
    row74: rv(73),
    row75: rv(74),
    row76: rv(75),
    row77: rv(76),
    row78: rv(77),
    row79: rv(78),
  );
}
