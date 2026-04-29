import 'dart:async';

import '../data/repositories/notes_repository.dart';
import "../data/repositories/treatment_repository.dart";
import "../data/repositories/assignment_repository.dart";
import "../data/repositories/assessment_definition_repository.dart";
import "../data/repositories/trial_assessment_repository.dart";
import "../data/repositories/application_repository.dart";
import "../data/repositories/application_plot_assignment_repository.dart";
import "../data/repositories/application_product_repository.dart";
import "../data/repositories/seeding_repository.dart";
import '../data/repositories/weather_snapshot_repository.dart';
import "../domain/models/plot_context.dart";
import "../domain/ratings/rating_integrity_guard.dart";
import "../domain/se_type_profiles/se_type_profile_repository.dart";
import '../domain/signals/signal_providers.dart';
import "../domain/usecases/resolve_plot_treatment.dart";
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'database/app_database.dart';
import '../features/backup/auto_backup_service.dart';
import 'connectivity/application_weather_backfill_service.dart';
import 'connectivity/connectivity_service.dart';
import 'connectivity/seeding_weather_backfill_service.dart';
import 'connectivity/weather_backfill_service.dart';
import '../features/derived/domain/trajectory_analysis.dart';
import '../features/backup/backup_passphrase_store.dart';
import '../features/backup/backup_service.dart';
import '../features/backup/restore_service.dart';
import 'trial_operational_watch_merge.dart';
import 'ui/trial_application_product_summary.dart';
import 'session_state.dart';
import 'trial_state.dart';
import '../features/trials/trial_repository.dart';
import '../features/plots/plot_repository.dart';
import '../features/plots/usecases/update_plot_details_usecase.dart';
import '../features/plots/usecases/generate_rep_guard_plots_usecase.dart';
import '../features/plots/usecases/update_plot_assignment_usecase.dart';
import '../features/protocol_import/protocol_import_usecase.dart';
import '../features/sessions/session_repository.dart';
import '../features/sessions/session_timing_helper.dart';
import '../domain/intelligence/trial_intelligence_service.dart';
import '../domain/models/trial_insight.dart';
import '../features/ratings/rating_repository.dart';
import '../features/photos/photo_repository.dart';
import '../features/trials/usecases/create_trial_usecase.dart';
import '../features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import '../features/trials/standalone/generate_standalone_plot_layout_usecase.dart';
import '../features/assessments/add_curated_library_assessments_to_trial_usecase.dart';
import '../features/trials/usecases/update_treatment_usecase.dart';
import '../features/trials/usecases/delete_treatment_usecase.dart';
import '../features/ratings/usecases/amend_plot_rating_usecase.dart';
import '../features/ratings/usecases/save_rating_usecase.dart';
import '../features/ratings/usecases/undo_rating_usecase.dart';
import '../features/ratings/usecases/apply_correction_usecase.dart';
import '../features/ratings/usecases/void_rating_usecase.dart';
import '../features/ratings/usecases/rating_lineage_usecase.dart';
import '../features/sessions/usecases/create_session_usecase.dart';
import '../features/sessions/usecases/close_session_usecase.dart';
import '../features/sessions/usecases/start_or_continue_rating_usecase.dart';
import '../features/sessions/usecases/compute_session_completeness_usecase.dart';
import '../features/sessions/usecases/evaluate_session_close_policy_usecase.dart';
import '../features/sessions/domain/session_completeness_report.dart';
import '../features/export/data/export_repository.dart';
import '../features/export/domain/export_session_csv_usecase.dart';
import '../features/export/domain/export_session_arm_xml_usecase.dart';
import '../features/export/domain/export_trial_closed_sessions_usecase.dart';
import '../features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart';
import '../features/export/domain/export_deleted_session_recovery_zip_usecase.dart';
import '../features/export/domain/export_deleted_trial_recovery_zip_usecase.dart';
import '../features/export/export_trial_ratings_share_usecase.dart';
import '../features/export/export_trial_usecase.dart';
import '../features/export/evidence_report_assembly_service.dart';
import '../features/export/evidence_report_pdf_builder.dart';
import '../features/export/export_evidence_report_usecase.dart';
import '../features/export/export_trial_report_usecase.dart';
import '../features/export/export_trial_pdf_report_usecase.dart';
import '../features/export/domain/arm_shell_link_usecase.dart';
import '../features/export/domain/export_arm_rating_shell_usecase.dart';
import '../features/export/domain/compute_arm_round_trip_diagnostics_usecase.dart';
import '../features/export/usecases/arm_export_preflight_usecase.dart';
import '../features/export/report_data_assembly_service.dart';
import '../features/export/standalone_report_data.dart';
import '../features/export/report_pdf_builder_service.dart';
import '../features/arm_import/data/arm_assessment_definition_resolver.dart';
import '../features/arm_import/data/arm_import_persistence_repository.dart';
import '../features/arm_import/data/arm_import_report_builder.dart';
import '../features/arm_import/data/arm_import_snapshot_service.dart';
import '../features/arm_import/data/arm_plot_insert_service.dart';
import '../features/arm_import/data/compatibility_profile_builder.dart';
import '../data/arm/arm_column_mapping_repository.dart';
import '../data/arm/arm_trial_metadata_repository.dart';
import '../data/arm/arm_applications_repository.dart';
import '../data/arm/arm_treatment_metadata_repository.dart';
import '../features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import '../features/arm_protocol/arm_protocol_tab.dart';
import '../features/derived/domain/trial_statistics.dart';
import '../features/photos/usecases/save_photo_usecase.dart';
import '../features/users/user_repository.dart';
import '../features/diagnostics/integrity_check_repository.dart';
import '../features/diagnostics/scan_rcbd_layouts_usecase.dart';
import '../features/diagnostics/assessment_completion.dart';
import 'plot_analysis_eligibility.dart';
import '../features/diagnostics/trial_readiness.dart';
import '../features/diagnostics/trial_readiness_service.dart';
import 'diagnostics/diagnostic_finding.dart';
import 'diagnostics/trial_export_diagnostics.dart';
import '../features/today/domain/activity_event.dart';
import '../features/today/today_activity_repository.dart';
import 'current_user.dart';
import 'diagnostics/diagnostics_store.dart';
import 'last_session_store.dart';
import 'export_guard.dart';
import 'workspace/workspace_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ARCHITECTURE RULE: Use case return types
/// New use cases must return domain result types (e.g. SaveRatingResult),
/// never raw Drift row types (e.g. RatingRecord, Session, Trial).
/// Existing use cases that return Drift rows are documented technical debt:
/// - SaveRatingUseCase (RatingRecord)
/// - CreateSessionUseCase (Session)
/// - CreateTrialUseCase (Trial)
/// - StartOrContinueRatingUseCase (Trial, Session, List<Plot>, List<Assessment>)
/// - ApplyCorrectionUseCase (RatingCorrection)
/// - SavePhotoUseCase (Photo)
/// These will be migrated to domain types when their consumers are next modified.

final exportGuardProvider = Provider<ExportGuard>((ref) => ExportGuard());

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final trialExportDiagnosticsMapProvider = StateNotifierProvider<
    TrialExportDiagnosticsMapNotifier,
    Map<int, TrialExportDiagnosticsSnapshot>>((ref) {
  return TrialExportDiagnosticsMapNotifier(ref.watch(databaseProvider));
});

final trialRepositoryProvider = Provider<TrialRepository>((ref) {
  return TrialRepository(ref.watch(databaseProvider));
});

final plotRepositoryProvider = Provider<PlotRepository>((ref) {
  return PlotRepository(ref.watch(databaseProvider));
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(databaseProvider));
});

/// Non-deleted field observations for a trial (newest first).
final notesForTrialProvider =
    StreamProvider.autoDispose.family<List<Note>, int>((ref, trialId) {
  return ref.watch(notesRepositoryProvider).watchNotesForTrial(trialId);
});

final updatePlotDetailsUseCaseProvider =
    Provider<UpdatePlotDetailsUseCase>((ref) {
  return UpdatePlotDetailsUseCase(ref.watch(plotRepositoryProvider));
});

final updatePlotGuardRowUseCaseProvider =
    Provider<UpdatePlotGuardRowUseCase>((ref) {
  return UpdatePlotGuardRowUseCase(ref.watch(plotRepositoryProvider));
});

final generateRepGuardPlotsUseCaseProvider =
    Provider<GenerateRepGuardPlotsUseCase>((ref) {
  return GenerateRepGuardPlotsUseCase(
    ref.watch(databaseProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(trialRepositoryProvider),
  );
});

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(ref.watch(databaseProvider));
});

final assessmentDefinitionRepositoryProvider =
    Provider<AssessmentDefinitionRepository>((ref) {
  return AssessmentDefinitionRepository(ref.watch(databaseProvider));
});

final trialAssessmentRepositoryProvider =
    Provider<TrialAssessmentRepository>((ref) {
  return TrialAssessmentRepository(ref.watch(databaseProvider));
});

final armImportPersistenceRepositoryProvider =
    Provider<ArmImportPersistenceRepository>((ref) {
  return ArmImportPersistenceRepository(ref.watch(databaseProvider));
});

final armImportSnapshotServiceProvider =
    Provider<ArmImportSnapshotService>((ref) => ArmImportSnapshotService());

final compatibilityProfileBuilderProvider =
    Provider<CompatibilityProfileBuilder>((ref) => CompatibilityProfileBuilder());

final armImportReportBuilderProvider =
    Provider<ArmImportReportBuilder>((ref) => ArmImportReportBuilder());

final armColumnMappingRepositoryProvider =
    Provider<ArmColumnMappingRepository>((ref) {
  return ArmColumnMappingRepository(ref.watch(databaseProvider));
});

final armTrialMetadataRepositoryProvider =
    Provider<ArmTrialMetadataRepository>((ref) {
  return ArmTrialMetadataRepository(ref.watch(databaseProvider));
});

/// ARM shell-link row for [trialId]; null when the trial is standalone (no row).
final armTrialMetadataStreamProvider =
    StreamProvider.family<ArmTrialMetadataData?, int>((ref, trialId) {
  return ref
      .watch(armTrialMetadataRepositoryProvider)
      .watchForTrial(trialId);
});

/// Persistence for per-treatment ARM coding (Phase 0b-treatments).
///
/// Scaffold only: no writer consumes this today. Phase 2 (ARM Treatments
/// sheet import) will populate rows; the ARM Protocol tab Treatments
/// sub-section (Phase 6) will read them. Registering the provider here —
/// the DI composition root is already allow-listed to import
/// `lib/data/arm/` — means later phases can wire in without touching
/// the boundary test.
final armTreatmentMetadataRepositoryProvider =
    Provider<ArmTreatmentMetadataRepository>((ref) {
  return ArmTreatmentMetadataRepository(ref.watch(databaseProvider));
});

/// ARM Applications-sheet extension (Phase 3a). One row per
/// [TrialApplicationEvents] when the shell importer populates it (Phase 3c).
final armApplicationsRepositoryProvider =
    Provider<ArmApplicationsRepository>((ref) {
  return ArmApplicationsRepository(ref.watch(databaseProvider));
});

/// Joined application events + `arm_applications` for the ARM Protocol tab
/// (Phase 3d). Empty when the trial has no Applications-sheet import rows.
final armSheetApplicationsForTrialProvider = StreamProvider.autoDispose
    .family<List<ArmSheetApplicationRow>, int>((ref, trialId) {
  return ref
      .watch(armApplicationsRepositoryProvider)
      .watchArmSheetApplicationsForTrial(trialId);
});

/// Factory for building the ARM Protocol tab widget.
///
/// Lives in providers.dart (the DI composition root) so that
/// [trial_detail_screen.dart] can add the tab to its IndexedStack without
/// importing from the ARM subtree directly. The function signature is plain
/// Dart — no ARM types leak into the caller.
final armProtocolTabBuilderProvider =
    Provider<Widget Function(int trialId)>((ref) {
  return (trialId) => ArmProtocolTab(trialId: trialId);
});

/// Nullable ARM session metadata for a given session id.
///
/// Returns null for sessions that were not created by the ARM importer
/// (standalone trials, ARM trials imported before Phase 1b, or non-planned
/// sessions created manually). Core UI code consults this provider so it
/// can show ARM-expected timing/stage/interval lines without importing
/// anything ARM-specific.
final armSessionMetadataProvider =
    FutureProvider.family<ArmSessionMetadataData?, int>((ref, sessionId) {
  return ref
      .watch(armColumnMappingRepositoryProvider)
      .getSessionMetadata(sessionId);
});

/// Map of `trialAssessmentId → ArmAssessmentMetadataData` for an ARM-linked
/// trial. Used by the ARM Protocol tab to read the per-column ARM fields
/// (column IDs, rating dates, SE codes) from `arm_assessment_metadata`
/// rather than `trial_assessments`, so per-column ARM data can live on
/// the extension table. See docs/ARM_SEPARATION.md.
final armAssessmentMetadataMapForTrialProvider =
    FutureProvider.family<Map<int, ArmAssessmentMetadataData>, int>(
        (ref, trialId) async {
  final rows = await ref
      .watch(armColumnMappingRepositoryProvider)
      .getAssessmentMetadatasForTrial(trialId);
  return {for (final r in rows) r.trialAssessmentId: r};
});

/// All ARM column mappings for [trialId], ordered by shell column index.
/// Used by the ARM Protocol tab's Assessments sub-section to render one row
/// per ARM column so the same assessment rated on multiple dates shows as
/// distinct rows (same identity, different date / timing / growth stage).
final armColumnMappingsForTrialProvider =
    FutureProvider.family<List<ArmColumnMapping>, int>((ref, trialId) {
  return ref.watch(armColumnMappingRepositoryProvider).getForTrial(trialId);
});

/// Map of `sessionId → ArmSessionMetadataData` for an ARM-linked trial.
/// Lets the ARM Protocol tab look up per-date timing / crop-stage / interval
/// fields when rendering per-column assessment rows.
final armSessionMetadataMapForTrialProvider =
    FutureProvider.family<Map<int, ArmSessionMetadataData>, int>(
        (ref, trialId) async {
  final rows = await ref
      .watch(armColumnMappingRepositoryProvider)
      .getSessionMetadatasForTrial(trialId);
  return {for (final r in rows) r.sessionId: r};
});

/// Map of treatment PK → [ArmTreatmentMetadataData] for every treatment
/// of an ARM-linked trial that has Treatments-sheet data (Phase 2b).
/// Used by the ARM Protocol tab's Treatments sub-section (Phase 2c) to
/// read the verbatim ARM coding (`armTypeCode`, `formConc`,
/// `formConcUnit`, `formType`, `armRowSortOrder`) alongside the core
/// treatment rows. Standalone trials return an empty map because they
/// never receive AAM rows. See docs/ARM_SEPARATION.md.
final armTreatmentMetadataMapForTrialProvider =
    FutureProvider.family<Map<int, ArmTreatmentMetadataData>, int>(
  (ref, trialId) async => ref
      .watch(armTreatmentMetadataRepositoryProvider)
      .getMapForTrial(trialId),
);

final importArmRatingShellUseCaseProvider =
    Provider<ImportArmRatingShellUseCase>((ref) {
  return ImportArmRatingShellUseCase(
    db: ref.watch(databaseProvider),
    trialRepository: ref.watch(trialRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    trialAssessmentRepository: ref.watch(trialAssessmentRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    armColumnMappingRepository: ref.watch(armColumnMappingRepositoryProvider),
    armApplicationsRepository: ref.watch(armApplicationsRepositoryProvider),
  );
});

final armAssessmentDefinitionResolverProvider =
    Provider<ArmAssessmentDefinitionResolver>((ref) {
  return ArmAssessmentDefinitionResolver(
    ref.watch(assessmentDefinitionRepositoryProvider),
  );
});

final armPlotInsertServiceProvider = Provider<ArmPlotInsertService>((ref) {
  return ArmPlotInsertService(
    ref.watch(databaseProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(trialRepositoryProvider),
  );
});

final assessmentDefinitionsProvider =
    StreamProvider<List<AssessmentDefinition>>((ref) {
  return ref
      .watch(assessmentDefinitionRepositoryProvider)
      .watchAll(activeOnly: true);
});

final trialAssessmentsForTrialProvider =
    StreamProvider.family<List<TrialAssessment>, int>((ref, trialId) {
  return ref.watch(trialAssessmentRepositoryProvider).watchForTrial(trialId);
});

final trialAssessmentsWithDefinitionsForTrialProvider =
    StreamProvider.family<List<(TrialAssessment, AssessmentDefinition)>, int>(
        (ref, trialId) {
  return ref
      .watch(trialAssessmentRepositoryProvider)
      .watchForTrialWithDefinitions(trialId);
});

/// Per–trial-assessment progress: distinct data plots with a **current** rating
/// for that legacy assessment id. Keys are [TrialAssessment.id] or negative
/// legacy [Assessment.id] for unlinked rows. See [AssessmentCompletion].
final trialAssessmentCompletionProvider = StreamProvider.autoDispose
    .family<Map<int, AssessmentCompletion>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final ratingRepo = ref.read(ratingRepositoryProvider);
    final plots = await ref.read(plotsForTrialProvider(trialId).future);
    final totalDataPlots = plots.where((p) => !p.isGuardRow).length;
    final analyzablePlotCount = plots.where(isAnalyzablePlot).length;
    final excludedFromAnalysisCount = totalDataPlots - analyzablePlotCount;
    final counts =
        await ratingRepo.getRatedDataPlotCountsPerLegacyAssessment(trialId);
    final pairs = await ref
        .read(trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);
    final legacy = await ref.read(assessmentsForTrialProvider(trialId).future);
    final taRepo = ref.read(trialAssessmentRepositoryProvider);
    final out = <int, AssessmentCompletion>{};
    final linkedLegacy = <int>{};
    for (final (ta, def) in pairs) {
      final lid = await taRepo.resolveLegacyAssessmentId(ta);
      if (lid != null) linkedLegacy.add(lid);
      final rated = lid != null ? (counts[lid] ?? 0) : 0;
      final name = ta.displayNameOverride?.trim().isNotEmpty == true
          ? ta.displayNameOverride!.trim()
          : def.name;
      out[ta.id] = AssessmentCompletion(
        trialAssessmentId: ta.id,
        assessmentName: name,
        ratedPlotCount: rated,
        analyzablePlotCount: analyzablePlotCount,
        totalDataPlots: totalDataPlots,
        excludedFromAnalysisCount: excludedFromAnalysisCount,
      );
    }
    for (final a in legacy) {
      if (linkedLegacy.contains(a.id)) continue;
      final rated = counts[a.id] ?? 0;
      out[-a.id] = AssessmentCompletion(
        trialAssessmentId: -a.id,
        assessmentName: a.name,
        ratedPlotCount: rated,
        analyzablePlotCount: analyzablePlotCount,
        totalDataPlots: totalDataPlots,
        excludedFromAnalysisCount: excludedFromAnalysisCount,
      );
    }
    return out;
  });
});

String _normalizeResultDirection(String? value) {
  switch (value) {
    case 'higherBetter':
    case 'higher_is_better':
      return 'higherBetter';
    case 'lowerBetter':
    case 'lower_is_better':
      return 'lowerBetter';
    default:
      return 'neutral';
  }
}

/// Matches [TrialAssessmentRepository.getOrCreateLegacyAssessmentIdsForTrialAssessments]
/// legacy row naming and [ExportRepository.buildTrialExportRows] `assessment_name`.
Future<String> _assessmentNameForTrialStatistics(
  AppDatabase db,
  TrialAssessment ta,
  AssessmentDefinition def,
) async {
  final displayBase = ta.displayNameOverride ?? def.name;
  if (ta.legacyAssessmentId != null) {
    final legacy = await (db.select(db.assessments)
          ..where((a) => a.id.equals(ta.legacyAssessmentId!)))
        .getSingleOrNull();
    if (legacy != null) return legacy.name;
  }
  return '$displayBase — TA${ta.id}';
}

/// Statistics for all assessments in a trial, keyed by trialAssessmentId.
/// Each value is a list sorted by sessionDate ASC — one entry per session that
/// has ratings for that assessment. Returns an empty map if no assessments exist.
/// Recomputes when operational trial data changes.
final trialAssessmentStatisticsProvider = StreamProvider.autoDispose
    .family<Map<int, List<AssessmentStatistics>>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final plots = await ref.watch(plotsForTrialProvider(trialId).future);
    final assessmentPairs = await ref.watch(
      trialAssessmentsWithDefinitionsForTrialProvider(trialId).future,
    );

    if (plots.isEmpty || assessmentPairs.isEmpty) return {};

    // ARM rating type lives on arm_assessment_metadata (v61). Standalone
    // trials have no AAM rows, so the lookup is a no-op for them.
    final aamRows = await ref
        .read(armColumnMappingRepositoryProvider)
        .getAssessmentMetadatasForTrial(trialId);
    final aamByTaId = <int, ArmAssessmentMetadataData>{
      for (final r in aamRows) r.trialAssessmentId: r,
    };

    // Session date lookup for ARM trials (no-op for standalone).
    final sessionMetaMap = await ref
        .read(armSessionMetadataMapForTrialProvider(trialId).future);

    final exportRepo = ref.read(exportRepositoryProvider);
    final rawRows = await exportRepo.buildTrialExportRows(trialId: trialId);

    final ratingRows = rawRows
        .map(
          (r) => RatingResultRow(
            plotId: (r['plot_id'] ?? '').toString(),
            rep: (r['rep'] as int?) ?? 0,
            treatmentCode: (r['treatment_code'] ?? '-').toString(),
            assessmentName: (r['assessment_name'] ?? '').toString(),
            unit: (r['unit'] ?? '').toString(),
            value: (r['value'] ?? '').toString(),
            resultStatus: (r['result_status'] ?? '').toString(),
            resultDirection: (r['result_direction'] ?? 'neutral').toString(),
            sessionId: r['session_id'] as int?,
          ),
        )
        .toList();

    final analyzablePlots = plots.where(isAnalyzablePlot).toList();
    final totalPlots = analyzablePlots.length;
    final analyzablePlotLabels = analyzablePlots.map((p) => p.plotId).toSet();
    final filteredRatingRows =
        ratingRows.where((r) => analyzablePlotLabels.contains(r.plotId)).toList();
    final allReps = analyzablePlots.map((p) => p.rep).whereType<int>().toSet();

    final result = <int, List<AssessmentStatistics>>{};
    for (final pair in assessmentPairs) {
      final ta = pair.$1;
      final def = pair.$2;
      final name = await _assessmentNameForTrialStatistics(db, ta, def);
      final unit = def.unit ?? '';
      final direction = _normalizeResultDirection(def.resultDirection);
      final ratingType = aamByTaId[ta.id]?.ratingType;

      // Find all sessions that have ratings for this assessment, sorted by date.
      final sessionIds = filteredRatingRows
          .where((r) => r.assessmentName == name && r.sessionId != null)
          .map((r) => r.sessionId!)
          .toSet()
          .toList()
        ..sort();

      if (sessionIds.isEmpty) {
        // No ratings yet — one empty stat so the card shows "no data".
        result[ta.id] = [
          computeAssessmentStatistics(
            const [],
            name,
            ta.id,
            unit,
            direction,
            totalPlots,
            allReps,
            assessmentCode: ratingType,
          ),
        ];
        continue;
      }

      result[ta.id] = [
        for (final sid in sessionIds)
          computeAssessmentStatistics(
            filteredRatingRows
                .where(
                    (r) => r.assessmentName == name && r.sessionId == sid)
                .toList(),
            name,
            ta.id,
            unit,
            direction,
            totalPlots,
            allReps,
            assessmentCode: ratingType,
            sessionId: sid,
            sessionDate: sessionMetaMap[sid]?.armRatingDate,
          ),
      ];
    }
    return result;
  });
});

/// Raw rating rows for a trial as RatingResultRow list.
/// Uses identical parsing to trialAssessmentStatisticsProvider
/// to ensure stats and per-plot detail always agree.
final trialRatingRowsProvider = StreamProvider.autoDispose
    .family<List<RatingResultRow>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final exportRepo = ref.read(exportRepositoryProvider);
    final rawRows = await exportRepo.buildTrialExportRows(trialId: trialId);
    final plots = await ref.watch(plotsForTrialProvider(trialId).future);
    final analyzablePlotLabels =
        plots.where(isAnalyzablePlot).map((p) => p.plotId).toSet();
    return rawRows
        .map(
          (r) => RatingResultRow(
            plotId: (r['plot_id'] ?? '').toString(),
            rep: (r['rep'] as int?) ?? 0,
            treatmentCode: (r['treatment_code'] ?? '-').toString(),
            assessmentName: (r['assessment_name'] ?? '').toString(),
            unit: (r['unit'] ?? '').toString(),
            value: (r['value'] ?? '').toString(),
            resultStatus: (r['result_status'] ?? '').toString(),
            resultDirection: _normalizeResultDirection(
              (r['result_direction'] ?? 'neutral').toString(),
            ),
            sessionId: r['session_id'] as int?,
          ),
        )
        .where((r) => analyzablePlotLabels.contains(r.plotId))
        .toList();
  });
});

/// Rating rows for a single session — used by AssessmentResultsScreen to show
/// per-plot detail without pooling data from other sessions.
final trialRatingRowsForSessionProvider = StreamProvider.autoDispose
    .family<List<RatingResultRow>, (int, int)>((ref, params) {
  final (trialId, sessionId) = params;
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final exportRepo = ref.read(exportRepositoryProvider);
    final rawRows = await exportRepo.buildTrialExportRows(trialId: trialId);
    final plots = await ref.watch(plotsForTrialProvider(trialId).future);
    final analyzablePlotLabels =
        plots.where(isAnalyzablePlot).map((p) => p.plotId).toSet();
    return rawRows
        .where((r) => r['session_id'] == sessionId)
        .map(
          (r) => RatingResultRow(
            plotId: (r['plot_id'] ?? '').toString(),
            rep: (r['rep'] as int?) ?? 0,
            treatmentCode: (r['treatment_code'] ?? '-').toString(),
            assessmentName: (r['assessment_name'] ?? '').toString(),
            unit: (r['unit'] ?? '').toString(),
            value: (r['value'] ?? '').toString(),
            resultStatus: (r['result_status'] ?? '').toString(),
            resultDirection: _normalizeResultDirection(
              (r['result_direction'] ?? 'neutral').toString(),
            ),
            sessionId: r['session_id'] as int?,
          ),
        )
        .where((r) => analyzablePlotLabels.contains(r.plotId))
        .toList();
  });
});

final updatePlotAssignmentUseCaseProvider =
    Provider<UpdatePlotAssignmentUseCase>((ref) {
  return UpdatePlotAssignmentUseCase(
    ref.watch(databaseProvider),
    ref.watch(assignmentRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final protocolImportUseCaseProvider = Provider<ProtocolImportUseCase>((ref) {
  return ProtocolImportUseCase(
    ref.watch(databaseProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(assignmentRepositoryProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

/// Latest non-deleted session row by id (e.g. after BBCH update).
final sessionByIdProvider = FutureProvider.autoDispose.family<Session?, int>(
    (ref, sessionId) {
  return ref.watch(sessionRepositoryProvider).getSessionById(sessionId);
});

/// DAS/DAT from seeding + applied applications; BBCH from session.
final sessionTimingContextProvider =
    FutureProvider.autoDispose.family<SessionTimingContext, int>(
        (ref, sessionId) async {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final session = await sessionRepo.getSessionById(sessionId);
  if (session == null) {
    return const SessionTimingContext();
  }
  final seeding = await ref
      .watch(seedingRepositoryProvider)
      .getSeedingEventForTrial(session.trialId);
  final applications = await ref
      .watch(applicationRepositoryProvider)
      .getApplicationsForTrial(session.trialId);
  return buildSessionTimingContext(
    sessionStartedAt: session.startedAt,
    cropStageBbch: session.cropStageBbch,
    seeding: seeding,
    applications: applications,
  );
});

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(databaseProvider));
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(ref.watch(databaseProvider));
});

final weatherSnapshotRepositoryProvider =
    Provider<WeatherSnapshotRepository>((ref) {
  return WeatherSnapshotRepository(ref.watch(databaseProvider));
});

/// Latest weather snapshot for a rating session (one row per session).
final weatherSnapshotForSessionProvider =
    StreamProvider.autoDispose
      .family<WeatherSnapshot?, int>((ref, sessionId) {
  return ref.watch(weatherSnapshotRepositoryProvider).watchWeatherSnapshotForParent(
        kWeatherParentTypeRatingSession,
        sessionId,
      );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(databaseProvider));
});

final diagnosticsStoreProvider = Provider<DiagnosticsStore>((ref) {
  return DiagnosticsStore(maxErrors: 50);
});

final integrityCheckRepositoryProvider =
    Provider<IntegrityCheckRepository>((ref) {
  return IntegrityCheckRepository(ref.watch(databaseProvider));
});

final scanRcbdLayoutsUseCaseProvider = Provider<ScanRcbdLayoutsUseCase>((ref) {
  return ScanRcbdLayoutsUseCase(
    db: ref.watch(databaseProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
  );
});

final todayActivityRepositoryProvider =
    Provider<TodayActivityRepository>((ref) {
  return TodayActivityRepository(ref.watch(databaseProvider));
});

/// Activity events for a given day (wall-clock date "yyyy-MM-dd").
/// Recomputes when operational tables used by [TodayActivityRepository] change.
final todayActivityProvider = StreamProvider.autoDispose
    .family<List<ActivityEvent>, String>((ref, dateLocal) {
  final db = ref.watch(databaseProvider);
  return ref.watch(currentUserIdProvider).when(
        data: (userId) => mergeTodayActivityTableWatches(db).asyncMap((_) async {
          final repo = ref.read(todayActivityRepositoryProvider);
          return repo.getActivityForDate(dateLocal, currentUserId: userId);
        }),
        loading: () => Stream.value(<ActivityEvent>[]),
        error: (e, st) => Stream<List<ActivityEvent>>.error(e, st),
      );
});

/// Days with at least one activity (empty days excluded), with event count. For work log history.
final workLogDatesProvider =
    StreamProvider.autoDispose<List<({String dateLocal, int eventCount})>>(
        (ref) {
  final db = ref.watch(databaseProvider);
  return ref.watch(currentUserIdProvider).when(
        data: (userId) => mergeTodayActivityTableWatches(db).asyncMap((_) async {
          final repo = ref.read(todayActivityRepositoryProvider);
          return repo.getDatesWithActivity(currentUserId: userId);
        }),
        loading: () => Stream.value([]),
        error: (e, st) => Stream<List<({String dateLocal, int eventCount})>>.error(
              e,
              st,
            ),
      );
});

/// Sessions for work log: filter by date (sessionDateLocal) and optionally current user (createdByUserId).
final workLogSessionsProvider = FutureProvider.autoDispose
    .family<List<Session>, String>((ref, dateLocal) async {
  final repo = ref.watch(sessionRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  return repo.getSessionsForDate(dateLocal, createdByUserId: userId);
});

/// All non-deleted sessions across all trials, most recent first.
final allActiveSessionsProvider =
    FutureProvider.autoDispose<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).getAllActiveSessions();
});

/// Number of plots rated in this session (current ratings only).
final ratingCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set = await ref.watch(ratedPlotPksProvider(sessionId).future);
  return set.length;
});

/// Number of plots flagged in this session.
final flagCountForSessionProvider =
    FutureProvider.autoDispose.family<int, int>((ref, sessionId) async {
  final set =
      await ref.watch(flaggedPlotIdsForSessionProvider(sessionId).future);
  return set.length;
});

/// Number of photos in this session.
final photoCountForSessionProvider =
    StreamProvider.autoDispose.family<int, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.photos)..where((p) => p.sessionId.equals(sessionId)))
      .watch()
      .map((list) => list.length);
});

final activeUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userRepositoryProvider).watchActiveUsers();
});

/// Current user id from SharedPreferences. Invalidate after set.
final currentUserIdProvider =
    FutureProvider.autoDispose<int?>((ref) => getCurrentUserId());

/// Full current user. Depends on currentUserIdProvider.
final currentUserProvider = FutureProvider.autoDispose<User?>((ref) async {
  final id = await ref.watch(currentUserIdProvider.future);
  if (id == null) return null;
  return ref.read(userRepositoryProvider).getUserById(id);
});

/// Lookup by local [Users] id (e.g. lastEditedByUserId). Not limited to current user.
final userByIdProvider =
    FutureProvider.autoDispose.family<User?, int>((ref, userId) async {
  return ref.read(userRepositoryProvider).getUserById(userId);
});

final createTrialUseCaseProvider = Provider<CreateTrialUseCase>((ref) {
  return CreateTrialUseCase(ref.watch(trialRepositoryProvider));
});

final createStandaloneTrialWizardUseCaseProvider =
    Provider<CreateStandaloneTrialWizardUseCase>((ref) {
  return CreateStandaloneTrialWizardUseCase(
    ref.watch(databaseProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(assignmentRepositoryProvider),
    ref.watch(assessmentDefinitionRepositoryProvider),
    ref.watch(trialAssessmentRepositoryProvider),
  );
});

final addCuratedLibraryAssessmentsToTrialUseCaseProvider =
    Provider<AddCuratedLibraryAssessmentsToTrialUseCase>((ref) {
  return AddCuratedLibraryAssessmentsToTrialUseCase(
    ref.watch(assessmentDefinitionRepositoryProvider),
    ref.watch(trialAssessmentRepositoryProvider),
  );
});

final generateStandalonePlotLayoutUseCaseProvider =
    Provider<GenerateStandalonePlotLayoutUseCase>((ref) {
  return GenerateStandalonePlotLayoutUseCase(
    ref.watch(databaseProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(assignmentRepositoryProvider),
  );
});

final updateTreatmentUseCaseProvider = Provider<UpdateTreatmentUseCase>((ref) {
  return UpdateTreatmentUseCase(
    ref.watch(databaseProvider),
    ref.watch(treatmentRepositoryProvider),
  );
});

final deleteTreatmentUseCaseProvider = Provider<DeleteTreatmentUseCase>((ref) {
  return DeleteTreatmentUseCase(
    ref.watch(databaseProvider),
    ref.watch(treatmentRepositoryProvider),
  );
});

final ratingIntegrityGuardProvider = Provider<RatingIntegrityGuard>((ref) {
  return RatingIntegrityGuard(
    ref.watch(plotRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
  );
});

final saveRatingUseCaseProvider = Provider<SaveRatingUseCase>((ref) {
  return SaveRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final amendPlotRatingUseCaseProvider = Provider<AmendPlotRatingUseCase>((ref) {
  return AmendPlotRatingUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(saveRatingUseCaseProvider),
    ref.watch(ratingRepositoryProvider),
    ref.watch(signalRepositoryProvider),
  );
});

final undoRatingUseCaseProvider = Provider<UndoRatingUseCase>((ref) {
  return UndoRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final applyCorrectionUseCaseProvider = Provider<ApplyCorrectionUseCase>((ref) {
  return ApplyCorrectionUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final voidRatingUseCaseProvider = Provider<VoidRatingUseCase>((ref) {
  return VoidRatingUseCase(
    ref.watch(ratingRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

final ratingLineageUseCaseProvider = Provider<RatingLineageUseCase>((ref) {
  return RatingLineageUseCase(ref.watch(ratingRepositoryProvider));
});

/// Latest correction for a rating (for effective value display).
final latestCorrectionForRatingProvider =
    FutureProvider.autoDispose.family<RatingCorrection?, int>((ref, ratingId) {
  return ref
      .read(ratingRepositoryProvider)
      .getLatestCorrectionForRating(ratingId);
});

final createSessionUseCaseProvider = Provider<CreateSessionUseCase>((ref) {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final trialRepo = ref.watch(trialRepositoryProvider);
  return CreateSessionUseCase(
    sessionRepo,
    promoteTrialToActiveIfReady: (trialId) async {
      final t = await trialRepo.getTrialById(trialId);
      if (t != null &&
          (t.status == kTrialStatusReady || t.status == kTrialStatusDraft)) {
        await trialRepo.updateTrialStatus(trialId, kTrialStatusActive);
      }
    },
  );
});

final startOrContinueRatingUseCaseProvider =
    Provider<StartOrContinueRatingUseCase>((ref) {
  return StartOrContinueRatingUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
  );
});

/// [ComputeSessionCompletenessUseCase] for [SessionCompletenessReport].
///
/// [SessionCompletenessReport] is the authoritative **scientific / session**
/// completeness source (per session assessment, guard rows excluded, close gating).
final computeSessionCompletenessUseCaseProvider =
    Provider<ComputeSessionCompletenessUseCase>((ref) {
  return ComputeSessionCompletenessUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
  );
});

final evaluateSessionClosePolicyUseCaseProvider =
    Provider<EvaluateSessionClosePolicyUseCase>((ref) {
  return EvaluateSessionClosePolicyUseCase(
    ref.watch(computeSessionCompletenessUseCaseProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(ratingRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(weatherSnapshotRepositoryProvider),
  );
});

final closeSessionUseCaseProvider = Provider<CloseSessionUseCase>((ref) {
  return CloseSessionUseCase(
    ref.watch(sessionRepositoryProvider),
    ref.watch(evaluateSessionClosePolicyUseCaseProvider),
  );
});

/// Async [SessionCompletenessReport] for one session id.
///
/// Prefer this (or the use case above) for completeness and close readiness.
/// [ratedPlotPksProvider] is **navigation / progress** only (any current rating
/// per plot) and must not be treated as scientific completeness.
final sessionCompletenessReportProvider = FutureProvider.autoDispose
    .family<SessionCompletenessReport, int>((ref, sessionId) async {
  return ref
      .read(computeSessionCompletenessUseCaseProvider)
      .execute(sessionId: sessionId);
});

final trialsStreamProvider = StreamProvider((ref) {
  return ref.watch(trialRepositoryProvider).watchAllTrials();
});

/// Custom trials only: stored [Trial.workspaceType] parses to `standalone`.
/// Null, blank, or unknown types are omitted (use [trialsStreamProvider] for all trials).
final customTrialsProvider = StreamProvider((ref) {
  return ref.watch(trialRepositoryProvider).watchAllTrials().map((all) {
    return all.where((t) => isStandalone(t.workspaceType)).toList();
  });
});

/// Protocol trials only: stored type parses to variety, efficacy, or glp.
/// Null, blank, or unknown types are omitted (use [trialsStreamProvider] for all trials).
final protocolTrialsProvider = StreamProvider((ref) {
  return ref.watch(trialRepositoryProvider).watchAllTrials().map((all) {
    return all.where((t) => isProtocol(t.workspaceType)).toList();
  });
});

/// Current trial by id (e.g. for trial detail). Updates when the trial row changes.
final trialProvider = StreamProvider.autoDispose.family<Trial?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trials)..where((t) => t.id.equals(id))).watchSingleOrNull();
});

/// Trial setup fields (protocol, location, plot dimensions, soil, etc.). Watch for setup screen.
final trialSetupProvider =
    StreamProvider.autoDispose.family<Trial?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trials)..where((t) => t.id.equals(trialId)))
      .watchSingleOrNull();
});

/// Trial name for Recovery session/plot rows: active trial, else soft-deleted, else fallback.
final recoveryTrialDisplayNameProvider =
    FutureProvider.autoDispose.family<String, int>((ref, trialId) async {
  final repo = ref.watch(trialRepositoryProvider);
  final active = await repo.getTrialById(trialId);
  if (active != null) return active.name;
  final deleted = await repo.getDeletedTrialById(trialId);
  if (deleted != null) return deleted.name;
  return 'Trial #$trialId';
});

final plotsForTrialProvider =
    StreamProvider.family<List<Plot>, int>((ref, trialId) {
  return ref.watch(plotRepositoryProvider).watchPlotsForTrial(trialId);
});

final assessmentsForTrialProvider =
    StreamProvider.family<List<Assessment>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.assessments)..where((a) => a.trialId.equals(trialId)))
      .watch();
});

final sessionsForTrialProvider =
    StreamProvider.family<List<Session>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.sessions)
        ..where((s) => s.trialId.equals(trialId) & s.isDeleted.equals(false))
        ..orderBy([(s) => drift.OrderingTerm.asc(s.startedAt)]))
      .watch();
});

/// True when this trial has any row in rating_records, photos, or plot_flags.
/// Field notes are intentionally excluded and do not lock assignments.
/// Used for assignment lock: empty sessions do NOT lock. Auto-updates when data changes.
final trialHasSessionDataProvider =
    StreamProvider.autoDispose.family<bool, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchTrialHasSessionData(trialId);
});

/// Soft-deleted trials (Recovery). Newest [deletedAt] first.
final deletedTrialsProvider =
    FutureProvider.autoDispose<List<Trial>>((ref) {
  return ref.watch(trialRepositoryProvider).getDeletedTrials();
});

/// Soft-deleted sessions across all trials (Recovery). Newest [deletedAt] first.
final deletedSessionsProvider =
    FutureProvider.autoDispose<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).getAllDeletedSessions();
});

/// Soft-deleted plots across all trials (Recovery). Newest [deletedAt] first.
final deletedPlotsProvider = FutureProvider.autoDispose<List<Plot>>((ref) {
  return ref.watch(plotRepositoryProvider).getAllDeletedPlots();
});

/// Soft-deleted sessions for one trial (Recovery trial-scoped).
final deletedSessionsForTrialRecoveryProvider =
    FutureProvider.autoDispose.family<List<Session>, int>((ref, trialId) {
  return ref
      .watch(sessionRepositoryProvider)
      .getDeletedSessionsForTrial(trialId);
});

/// Soft-deleted plots for one trial (Recovery trial-scoped).
final deletedPlotsForTrialRecoveryProvider =
    FutureProvider.autoDispose.family<List<Plot>, int>((ref, trialId) {
  return ref.watch(plotRepositoryProvider).getDeletedPlotsForTrial(trialId);
});

/// Seeding records for a trial (for Seeding tab).
final seedingRecordsForTrialProvider = StreamProvider.autoDispose
    .family<List<SeedingRecord>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.seedingRecords)
        ..where((t) => t.trialId.equals(trialId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
      .watch();
});

final openSessionProvider =
    StreamProvider.family<Session?, int>((ref, trialId) {
  return ref.watch(sessionRepositoryProvider).watchOpenSession(trialId);
});

/// Trial IDs with at least one open field session. Used for trial list Active
/// counts/filters so they match trial detail effective "Active" when DB status is still draft.
final openTrialIdsForFieldWorkProvider = StreamProvider<Set<int>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.sessions)
        ..where((s) => s.endedAt.isNull() & s.isDeleted.equals(false)))
      .watch()
      .map((sessions) => sessions
          .where(isSessionOpenForFieldWork)
          .map((s) => s.trialId)
          .toSet());
});

/// Resolved trial + session for "Continue Last Session" home card.
class LastSessionContext {
  const LastSessionContext({required this.trial, required this.session});
  final Trial trial;
  final Session session;
}

/// Last session (trialId, sessionId) persisted for "Continue Last Session" home card. Valid only if session still exists and is open.
final lastSessionContextProvider =
    FutureProvider.autoDispose<LastSessionContext?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = LastSessionStore(prefs).get();
  if (ids == null) return null;
  final trialRepo = ref.read(trialRepositoryProvider);
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final trial = await trialRepo.getTrialById(ids.$1);
  final session = await sessionRepo.getSessionById(ids.$2);
  if (trial == null ||
      session == null ||
      session.endedAt != null ||
      session.trialId != trial.id) {
    return null;
  }
  return LastSessionContext(trial: trial, session: session);
});

final sessionAssessmentsProvider =
    StreamProvider.family<List<Assessment>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  return (db.select(db.sessionAssessments)
        ..where((sa) => sa.sessionId.equals(sessionId))
        ..orderBy([
          (sa) => drift.OrderingTerm.asc(sa.sortOrder),
          (sa) => drift.OrderingTerm.asc(sa.id),
        ]))
      .watch()
      .asyncMap((_) => sessionRepo.getSessionAssessments(sessionId));
});

/// Plot PKs with at least one **current** rating in the session (any assessment).
/// Excludes guard rows ([Plot.isGuardRow]) — same semantics as rating walk order.
///
/// **Navigation / plot-queue progress** only—not [SessionCompletenessReport] /
/// per-assessment completeness. Use [sessionCompletenessReportProvider] for
/// scientific session completeness and close gating.
final ratedPlotPksProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .watch()
      .asyncMap((ratings) async {
    if (ratings.isEmpty) return <int>{};
    final pks = ratings.map((r) => r.plotPk).toSet();
    final plotRows = await (db.select(db.plots)..where((p) => p.id.isIn(pks)))
        .get();
    final guardPks =
        plotRows.where((p) => p.isGuardRow).map((p) => p.id).toSet();
    return pks.difference(guardPks);
  });
});

class CurrentRatingParams {
  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int sessionId;
  final int? subUnitId;

  const CurrentRatingParams({
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.sessionId,
    this.subUnitId,
  });

  @override
  bool operator ==(Object other) =>
      other is CurrentRatingParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk &&
      other.assessmentId == assessmentId &&
      other.sessionId == sessionId &&
      other.subUnitId == subUnitId;

  @override
  int get hashCode =>
      Object.hash(trialId, plotPk, assessmentId, sessionId, subUnitId);
}

final currentRatingProvider =
    StreamProvider.family<RatingRecord?, CurrentRatingParams>((ref, params) {
  return ref.watch(ratingRepositoryProvider).watchCurrentRating(
        trialId: params.trialId,
        plotPk: params.plotPk,
        assessmentId: params.assessmentId,
        sessionId: params.sessionId,
        subUnitId: params.subUnitId,
      );
});

final sessionRatingsProvider =
    StreamProvider.family<List<RatingRecord>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.sessionId.equals(sessionId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .watch();
});

/// Session IDs among the trial's sessions that have any rating correction (one batch per trial).
final sessionIdsWithCorrectionsForTrialProvider =
    FutureProvider.autoDispose.family<Set<int>, int>((ref, trialId) async {
  final sessions = ref.watch(sessionsForTrialProvider(trialId)).valueOrNull ??
      const <Session>[];
  final ids = sessions.map((s) => s.id).toList();
  if (ids.isEmpty) return {};
  return ref.read(ratingRepositoryProvider).getSessionIdsWithCorrections(ids);
});

/// Plot PKs with at least one correction in the given session (single query per session).
final plotPksWithCorrectionsForSessionProvider =
    StreamProvider.autoDispose.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingCorrections)
        ..where((c) =>
            c.sessionId.equals(sessionId) & c.plotPk.isNotNull()))
      .watch()
      .map((rows) => {for (final c in rows) if (c.plotPk != null) c.plotPk!});
});

// ===== Export (CSV) =====

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(ref.watch(databaseProvider));
});

final exportSessionCsvUsecaseProvider =
    Provider<ExportSessionCsvUsecase>((ref) {
  return ExportSessionCsvUsecase(ref.watch(exportRepositoryProvider));
});

final exportTrialRatingsShareUsecaseProvider =
    Provider<ExportTrialRatingsShareUsecase>((ref) {
  return ExportTrialRatingsShareUsecase(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
  );
});

final exportSessionArmXmlUsecaseProvider =
    Provider<ExportSessionArmXmlUsecase>((ref) {
  return ExportSessionArmXmlUsecase(ref.watch(exportRepositoryProvider));
});

final exportTrialClosedSessionsUsecaseProvider =
    Provider<ExportTrialClosedSessionsUsecase>((ref) {
  return ExportTrialClosedSessionsUsecase(
    ref.watch(exportSessionCsvUsecaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final exportTrialClosedSessionsArmXmlUsecaseProvider =
    Provider<ExportTrialClosedSessionsArmXmlUsecase>((ref) {
  return ExportTrialClosedSessionsArmXmlUsecase(
    ref.watch(exportSessionArmXmlUsecaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final exportDeletedSessionRecoveryZipUsecaseProvider =
    Provider<ExportDeletedSessionRecoveryZipUsecase>((ref) {
  return ExportDeletedSessionRecoveryZipUsecase(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    trialRepository: ref.watch(trialRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
  );
});

final exportDeletedTrialRecoveryZipUsecaseProvider =
    Provider<ExportDeletedTrialRecoveryZipUsecase>((ref) {
  return ExportDeletedTrialRecoveryZipUsecase(
    trialRepository: ref.watch(trialRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
  );
});

final reportDataAssemblyServiceProvider =
    Provider<ReportDataAssemblyService>((ref) {
  return ReportDataAssemblyService(
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    photoRepository: ref.watch(photoRepositoryProvider),
    exportRepository: ref.watch(exportRepositoryProvider),
    seedingRepository: ref.watch(seedingRepositoryProvider),
  );
});

final reportPdfBuilderServiceProvider =
    Provider<ReportPdfBuilderService>((ref) {
  return ReportPdfBuilderService();
});

final exportTrialPdfReportUseCaseProvider =
    Provider<ExportTrialPdfReportUseCase>((ref) {
  return ExportTrialPdfReportUseCase(
    assemblyService: ref.watch(reportDataAssemblyServiceProvider),
    pdfBuilder: ref.watch(reportPdfBuilderServiceProvider),
    armImportPersistenceRepository:
        ref.watch(armImportPersistenceRepositoryProvider),
    publishExportDiagnostics: (trialId, findings, attemptLabel) {
      ref
          .read(trialExportDiagnosticsMapProvider.notifier)
          .setTrialSnapshot(trialId, findings, attemptLabel);
    },
  );
});

final exportEvidenceReportUseCaseProvider =
    Provider<ExportEvidenceReportUseCase>((ref) {
  return ExportEvidenceReportUseCase(
    assemblyService: EvidenceReportAssemblyService(
      plotRepository: ref.watch(plotRepositoryProvider),
      treatmentRepository: ref.watch(treatmentRepositoryProvider),
      applicationRepository: ref.watch(applicationRepositoryProvider),
      sessionRepository: ref.watch(sessionRepositoryProvider),
      assignmentRepository: ref.watch(assignmentRepositoryProvider),
      ratingRepository: ref.watch(ratingRepositoryProvider),
      weatherSnapshotRepository: ref.watch(weatherSnapshotRepositoryProvider),
      seedingRepository: ref.watch(seedingRepositoryProvider),
      photoRepository: ref.watch(photoRepositoryProvider),
      db: ref.watch(databaseProvider),
    ),
    pdfBuilder: EvidenceReportPdfBuilder(),
  );
});

final exportTrialReportUseCaseProvider =
    Provider<ExportTrialReportUseCase>((ref) {
  return ExportTrialReportUseCase(
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    notesRepository: ref.watch(notesRepositoryProvider),
    trialAssessmentRepository: ref.watch(trialAssessmentRepositoryProvider),
    assessmentDefinitionRepository:
        ref.watch(assessmentDefinitionRepositoryProvider),
  );
});

final exportTrialUseCaseProvider = Provider<ExportTrialUseCase>((ref) {
  return ExportTrialUseCase(
    db: ref.watch(databaseProvider),
    trialRepository: ref.watch(trialRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
    applicationProductRepository:
        ref.watch(applicationProductRepositoryProvider),
    seedingRepository: ref.watch(seedingRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    photoRepository: ref.watch(photoRepositoryProvider),
    weatherSnapshotRepository: ref.watch(weatherSnapshotRepositoryProvider),
    notesRepository: ref.watch(notesRepositoryProvider),
    armImportPersistenceRepository:
        ref.watch(armImportPersistenceRepositoryProvider),
    publishExportDiagnostics: (trialId, findings, attemptLabel) {
      ref
          .read(trialExportDiagnosticsMapProvider.notifier)
          .setTrialSnapshot(trialId, findings, attemptLabel);
    },
  );
});

final exportArmRatingShellUseCaseProvider =
    Provider<ExportArmRatingShellUseCase>((ref) {
  return ExportArmRatingShellUseCase(
    db: ref.watch(databaseProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    trialAssessmentRepository: ref.watch(trialAssessmentRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    persistence: ref.watch(armImportPersistenceRepositoryProvider),
    armColumnMappingRepository: ref.watch(armColumnMappingRepositoryProvider),
    armApplicationsRepository: ref.watch(armApplicationsRepositoryProvider),
    armTreatmentMetadataRepository:
        ref.watch(armTreatmentMetadataRepositoryProvider),
    publishExportDiagnostics: (trialId, findings, attemptLabel) {
      ref
          .read(trialExportDiagnosticsMapProvider.notifier)
          .setTrialSnapshot(trialId, findings, attemptLabel);
    },
  );
});

final armShellLinkUseCaseProvider = Provider<ArmShellLinkUseCase>((ref) {
  return ArmShellLinkUseCase(
    ref.watch(databaseProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(trialAssessmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(armColumnMappingRepositoryProvider),
  );
});

final computeArmRoundTripDiagnosticsUseCaseProvider =
    Provider<ComputeArmRoundTripDiagnosticsUseCase>((ref) {
  return ComputeArmRoundTripDiagnosticsUseCase(
    db: ref.watch(databaseProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    trialAssessmentRepository: ref.watch(trialAssessmentRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    armColumnMappingRepository: ref.watch(armColumnMappingRepositoryProvider),
  );
});

final armExportPreflightUseCaseProvider =
    Provider<ArmExportPreflightUseCase>((ref) {
  return ArmExportPreflightUseCase(
    db: ref.watch(databaseProvider),
    trialRepository: ref.watch(trialRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    trialAssessmentRepository: ref.watch(trialAssessmentRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    photoRepository: ref.watch(photoRepositoryProvider),
    armImportPersistence: ref.watch(armImportPersistenceRepositoryProvider),
    exportRepository: ref.watch(exportRepositoryProvider),
    computeArmRoundTripDiagnostics:
        ref.watch(computeArmRoundTripDiagnosticsUseCaseProvider),
  );
});

/// Loads [ArmExportPreflight] for the ARM Rating Shell trust screen (no export).
final armExportPreflightFutureProvider = FutureProvider.autoDispose
    .family<ArmExportPreflight, int>((ref, trialId) async {
  final uc = ref.watch(armExportPreflightUseCaseProvider);
  return uc.execute(ref: ref, trialId: trialId);
});

/// Unified trial readiness report (blockers, warnings, passes). Used for readiness card and export gating.
final trialReadinessProvider = StreamProvider.autoDispose
    .family<TrialReadinessReport, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) =>
      TrialReadinessService().runChecks(trialId.toString(), ref));
});

/// Merged [DiagnosticFinding]s for trial-scoped diagnostics UI (readiness sheet).
///
/// Combines live readiness checks (non-pass) with the latest export-time
/// findings from [trialExportDiagnosticsMapProvider] (validation + ARM
/// confidence from the most recent export attempt). Snapshots are persisted in
/// Drift and hydrated on startup.
final trialDiagnosticsProvider = Provider.autoDispose
    .family<List<DiagnosticFinding>, int>((ref, trialId) {
  final readinessAsync = ref.watch(trialReadinessProvider(trialId));
  final readinessFindings = readinessAsync.maybeWhen(
    data: (report) => report.checks
        .where((c) => c.severity != TrialCheckSeverity.pass)
        .map((c) => c.toDiagnosticFinding(trialId))
        .toList(),
    orElse: () => <DiagnosticFinding>[],
  );
  final exportByTrial = ref.watch(trialExportDiagnosticsMapProvider);
  final exportFindings =
      exportByTrial[trialId]?.findings ?? const <DiagnosticFinding>[];
  return [...readinessFindings, ...exportFindings];
});

/// Latest export diagnostics snapshot for a trial (for UI context, e.g. timestamp).
final trialExportDiagnosticsSnapshotProvider = Provider.autoDispose
    .family<TrialExportDiagnosticsSnapshot?, int>((ref, trialId) {
  return ref.watch(trialExportDiagnosticsMapProvider)[trialId];
});

/// Latest protocol import event for a trial (for opening saved CSV reference).
final latestImportEventForTrialProvider =
    StreamProvider.family<ImportEvent?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.importEvents)
        ..where((e) => e.trialId.equals(trialId))
        ..orderBy([(e) => drift.OrderingTerm.desc(e.createdAt)])
        ..limit(1))
      .watchSingleOrNull();
});

// ===== Photos =====

final savePhotoUseCaseProvider = Provider<SavePhotoUseCase>((ref) {
  return SavePhotoUseCase(
    ref.watch(photoRepositoryProvider),
    ref.watch(ratingIntegrityGuardProvider),
  );
});

/// Flags for a given plot in a session (for one-tap flag toggle on rating screen).
final plotFlagsForPlotSessionProvider =
    StreamProvider.family<List<PlotFlag>, (int, int)>((ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.plotFlags)
        ..where(
            (f) => f.plotPk.equals(params.$1) & f.sessionId.equals(params.$2)))
      .watch();
});

/// Set of plot IDs that have at least one flag in this session (for session/queue UI).
final flaggedPlotIdsForSessionProvider =
    StreamProvider.family<Set<int>, int>((ref, sessionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.plotFlags)..where((f) => f.sessionId.equals(sessionId)))
      .watch()
      .map((list) => list.map((f) => f.plotPk).toSet());
});

class PhotosForPlotParams {
  final int trialId;
  final int plotPk;
  final int sessionId;

  const PhotosForPlotParams({
    required this.trialId,
    required this.plotPk,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is PhotosForPlotParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(trialId, plotPk, sessionId);
}

final photosForPlotProvider =
    StreamProvider.family<List<Photo>, PhotosForPlotParams>((ref, params) {
  return ref.watch(photoRepositoryProvider).watchPhotosForPlot(
        trialId: params.trialId,
        plotPk: params.plotPk,
        sessionId: params.sessionId,
      );
});

/// Photos for a plot in a session (live updates).
final photosForPlotInSessionProvider =
    StreamProvider.autoDispose.family<List<Photo>, PhotosForPlotParams>(
        (ref, params) {
  return ref.watch(photoRepositoryProvider).watchPhotosForPlot(
        trialId: params.trialId,
        plotPk: params.plotPk,
        sessionId: params.sessionId,
      );
});

/// All photos for a trial (for trial-level Photos tab). Group by session in UI.
final photosForTrialProvider =
    StreamProvider.family<List<Photo>, int>((ref, trialId) {
  return ref.watch(photoRepositoryProvider).watchPhotosForTrial(trialId);
});

final photosForPlotAllSessionsProvider = FutureProvider.autoDispose
    .family<List<Photo>, ({int trialId, int plotPk})>((ref, params) {
  return ref.watch(photoRepositoryProvider).getPhotosForPlotAllSessions(
        trialId: params.trialId,
        plotPk: params.plotPk,
      );
});

class PlotRatingParams {
  final int trialId;
  final int plotPk;

  const PlotRatingParams({required this.trialId, required this.plotPk});

  @override
  bool operator ==(Object other) =>
      other is PlotRatingParams &&
      other.trialId == trialId &&
      other.plotPk == plotPk;

  @override
  int get hashCode => Object.hash(trialId, plotPk);
}

// Returns full rating history for a plot — all records ordered newest first.
final plotRatingHistoryProvider =
    StreamProvider.family<List<RatingRecord>, PlotRatingParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(params.trialId) &
            r.plotPk.equals(params.plotPk) &
            r.isDeleted.equals(false))
        ..orderBy([(r) => drift.OrderingTerm.desc(r.createdAt)]))
      .watch();
});
// ===== Treatment =====

final treatmentRepositoryProvider = Provider<TreatmentRepository>((ref) {
  return TreatmentRepository(
      ref.watch(databaseProvider), ref.watch(assignmentRepositoryProvider));
});

final treatmentsForTrialProvider =
    StreamProvider.family<List<Treatment>, int>((ref, trialId) {
  return ref
      .watch(treatmentRepositoryProvider)
      .watchTreatmentsForTrial(trialId);
});

/// Components for a single treatment (for Treatments tab expandable list).
final treatmentComponentsForTreatmentProvider = StreamProvider.autoDispose
    .family<List<TreatmentComponent>, int>((ref, treatmentId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.treatmentComponents)
        ..where((c) =>
            c.treatmentId.equals(treatmentId) & c.isDeleted.equals(false))
        ..orderBy([(c) => drift.OrderingTerm.asc(c.sortOrder)]))
      .watch();
});

/// All non-deleted components for a trial, grouped by `treatmentId`. Used
/// by the ARM Protocol tab Treatments sub-section (Phase 2c) so the whole
/// trial's product / rate data can be fetched in one round-trip rather
/// than N per-treatment watches. Empty list for a treatmentId means the
/// treatment has no components (typical for CHK / untreated checks).
final treatmentComponentsByTreatmentForTrialProvider =
    FutureProvider.family<Map<int, List<TreatmentComponent>>, int>(
        (ref, trialId) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.treatmentComponents)
        ..where((c) => c.trialId.equals(trialId) & c.isDeleted.equals(false))
        ..orderBy([(c) => drift.OrderingTerm.asc(c.sortOrder)]))
      .get();
  final map = <int, List<TreatmentComponent>>{};
  for (final c in rows) {
    (map[c.treatmentId] ??= <TreatmentComponent>[]).add(c);
  }
  return map;
});

final assignmentsForTrialProvider =
    StreamProvider.family<List<Assignment>, int>((ref, trialId) {
  return ref.watch(assignmentRepositoryProvider).watchForTrial(trialId);
});

/// Total count of treatment components across all treatments for a trial (Trial Summary).
final treatmentComponentsCountForTrialProvider =
    StreamProvider.autoDispose.family<int, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) async {
    final repo = ref.read(treatmentRepositoryProvider);
    final treatments = await repo.getTreatmentsForTrial(trialId);
    var count = 0;
    for (final t in treatments) {
      count += (await repo.getComponentsForTreatment(t.id)).length;
    }
    return count;
  });
});

/// Distinct **data** plots (non–guard) with at least one current rating — matches
/// [RatingRepository.getRatedPlotCountForTrial].
final ratedPlotsCountForTrialProvider =
    StreamProvider.autoDispose.family<int, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap((_) =>
      ref.read(ratingRepositoryProvider).getRatedPlotCountForTrial(trialId));
});

final resolvePlotTreatmentProvider = Provider<ResolvePlotTreatment>((ref) {
  return ResolvePlotTreatment(
    plotRepository: ref.watch(plotRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
  );
});

final plotContextProvider =
    FutureProvider.autoDispose.family<PlotContext, int>((ref, plotPk) {
  return ref.watch(resolvePlotTreatmentProvider).execute(plotPk);
});

// ===== Applications =====

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(ref.watch(databaseProvider));
});

final applicationProductRepositoryProvider =
    Provider<ApplicationProductRepository>((ref) {
  return ApplicationProductRepository(ref.watch(databaseProvider));
});

final applicationPlotAssignmentRepositoryProvider =
    Provider<ApplicationPlotAssignmentRepository>((ref) {
  return ApplicationPlotAssignmentRepository(ref.watch(databaseProvider));
});

/// Products (tank mix) for a trial application event; empty stream until event exists.
final trialApplicationProductsForEventProvider =
    StreamProvider.autoDispose.family<List<TrialApplicationProduct>, String>(
        (ref, eventId) {
  return ref
      .watch(applicationProductRepositoryProvider)
      .watchProductsForEvent(eventId);
});

final seedingRepositoryProvider = Provider<SeedingRepository>((ref) {
  return SeedingRepository(ref.watch(databaseProvider));
});

/// Seeding event for a trial (one per trial). AutoDispose, family keyed by trialId.
final seedingEventForTrialProvider =
    StreamProvider.autoDispose.family<SeedingEvent?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.seedingEvents)..where((s) => s.trialId.equals(trialId)))
      .watchSingleOrNull();
});

/// ---------------------------------------------------------------------------
/// APPLICATION EVENTS — IMPORTANT ARCHITECTURE NOTE
///
/// There are currently TWO parallel application event systems:
///
/// 1. applicationsForTrialProvider (LEGACY)
///    - Based on ApplicationEvent (int primary key)
///    - Slot-based / plot-layout driven model
///    - Still used by plots_tab.dart (application layer on plot grid)
///
/// 2. trialApplicationsForTrialProvider (CANONICAL)
///    - Based on TrialApplicationEvent (String UUID primary key)
///    - Trial-level application events (new architecture)
///    - Used by Applications tab and all new flows
///
/// ⚠️ DO NOT mix these systems in the same feature.
/// ⚠️ All new development should use trialApplicationsForTrialProvider.
/// ⚠️ Legacy provider will be removed after plot-layout migration.
///
/// ---------------------------------------------------------------------------

/// Trial-level application events (trial_application_events), ordered by application_date ascending.
final trialApplicationsForTrialProvider = StreamProvider.autoDispose
    .family<List<TrialApplicationEvent>, int>((ref, trialId) {
  return ref
      .watch(applicationRepositoryProvider)
      .watchApplicationsForTrial(trialId);
});

/// Distinct product summary lines from trial applications linked to a treatment
/// (`trial_application_events.treatment_id`), for Treatments tab when protocol
/// components are empty. Recomputes when application events or tank-mix products
/// change anywhere (products table is not in [mergeTrialOperationalTableWatches]).
final applicationProductSummariesForTreatmentProvider =
    StreamProvider.autoDispose.family<List<String>, (int, int)>((ref, key) {
  final trialId = key.$1;
  final treatmentId = key.$2;
  final db = ref.watch(databaseProvider);
  final productRepo = ref.watch(applicationProductRepositoryProvider);

  return mergeTableWatchStreams([
    (db.select(db.trialApplicationEvents)
          ..where((e) => e.trialId.equals(trialId)))
        .watch(),
    (db.select(db.trialApplicationProducts)).watch(),
  ]).asyncMap((_) async {
    final events = await (db.select(db.trialApplicationEvents)
          ..where((e) =>
              e.trialId.equals(trialId) & e.treatmentId.equals(treatmentId)))
        .get();
    final lines = <String>[];
    final seen = <String>{};
    for (final e in events) {
      final prods = await productRepo.getProductsForEvent(e.id);
      final line = trialApplicationProductSummaryLine(e, prods);
      if (line.isNotEmpty && seen.add(line)) {
        lines.add(line);
      }
    }
    return lines;
  });
});

/// LEGACY: application_events + application_plot_records table stack.
/// Only consumer: plots_tab.dart application event selector + plot overlay.
/// Canonical system: trialApplicationsForTrialProvider (trial_application_events).
/// Migration path: re-model plot-level coverage to reference
/// trial_application_events, then remove this provider and legacy
/// ApplicationRepository methods.
final applicationsForTrialProvider =
    StreamProvider.family<List<ApplicationEvent>, int>((ref, trialId) {
  return ref.watch(applicationRepositoryProvider).watchEventsForTrial(trialId);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref.watch(databaseProvider));
});

final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    ref.watch(backupServiceProvider),
    BackupPassphraseStore(),
  );
});

final autoBackupStatusProvider =
    FutureProvider.autoDispose<AutoBackupStatus>((ref) {
  return ref.watch(autoBackupServiceProvider).getStatus();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final weatherBackfillServiceProvider =
    Provider<WeatherBackfillService>((ref) {
  return WeatherBackfillService(
    connectivityService: ref.watch(connectivityServiceProvider),
    weatherRepo: ref.watch(weatherSnapshotRepositoryProvider),
    diagnosticsStore: ref.watch(diagnosticsStoreProvider),
  );
});

final applicationWeatherBackfillServiceProvider =
    Provider<ApplicationWeatherBackfillService>((ref) {
  return ApplicationWeatherBackfillService(
    connectivityService: ref.watch(connectivityServiceProvider),
    applicationRepository: ref.watch(applicationRepositoryProvider),
  );
});

final seedingWeatherBackfillServiceProvider =
    Provider<SeedingWeatherBackfillService>((ref) {
  return SeedingWeatherBackfillService(
    connectivityService: ref.watch(connectivityServiceProvider),
    seedingRepository: ref.watch(seedingRepositoryProvider),
  );
});

// ---------------------------------------------------------------------------
// Trajectory
// ---------------------------------------------------------------------------

/// Builds trajectory series for all assessment codes in a trial that have ≥3 timings.
final trialTrajectoriesProvider = FutureProvider.autoDispose
    .family<List<AssessmentTrajectorySeries>, int>((ref, trialId) async {
  final assessmentPairs = await ref
      .watch(trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);
  final db = ref.watch(databaseProvider);

  // ARM rating-type code (e.g. CONTRO) now lives on
  // arm_assessment_metadata (v61). Standalone trials have no AAM rows
  // and contribute nothing to this grouping.
  final aamRows = await ref
      .read(armColumnMappingRepositoryProvider)
      .getAssessmentMetadatasForTrial(trialId);
  final aamByTaId = <int, ArmAssessmentMetadataData>{
    for (final r in aamRows) r.trialAssessmentId: r,
  };

  final byCode = <String, List<(dynamic ta, dynamic def)>>{};
  for (final pair in assessmentPairs) {
    final ta = pair.$1;
    final code = aamByTaId[ta.id]?.ratingType?.trim();
    if (code == null || code.isEmpty) continue;
    if (ta.daysAfterTreatment == null) continue;
    byCode.putIfAbsent(code, () => []).add(pair);
  }

  // For each code with ≥3 timings, build trajectory from rating data.
  final result = <AssessmentTrajectorySeries>[];

  for (final entry in byCode.entries) {
    final code = entry.key;
    final pairs = entry.value;
    if (pairs.length < 3) continue;

    // Collect rating data across all timings for this code.
    final rows = <TrajectoryDataRow>[];
    for (final pair in pairs) {
      final ta = pair.$1;
      final dat = ta.daysAfterTreatment as int?;
      if (dat == null) continue;

      final legacyId = ta.legacyAssessmentId as int?;
      if (legacyId == null) continue;

      // Get ratings for this assessment.
      final ratingRows = await db.customSelect(
        'SELECT r.numeric_value, p.plot_id, t.code AS trt_code, '
        'a.treatment_id, p.rep '
        'FROM rating_records r '
        'JOIN plots p ON r.plot_pk = p.id '
        'LEFT JOIN assignments a ON a.plot_id = p.id '
        'LEFT JOIN treatments t ON t.id = COALESCE(a.treatment_id, p.treatment_id) '
        'WHERE r.assessment_id = ? AND r.is_current = 1 AND r.is_deleted = 0 '
        'AND r.result_status = \'RECORDED\' AND r.numeric_value IS NOT NULL '
        'AND p.is_deleted = 0 AND (p.is_guard_row = 0 OR p.is_guard_row IS NULL) '
        'AND (p.exclude_from_analysis = 0 OR p.exclude_from_analysis IS NULL)',
        variables: [drift.Variable.withInt(legacyId)],
        readsFrom: {db.ratingRecords, db.plots, db.assignments, db.treatments},
      ).get();

      for (final r in ratingRows) {
        final value = r.read<double?>('numeric_value');
        final trtCode = r.read<String?>('trt_code');
        final trtId = r.read<int?>('treatment_id');
        if (value == null) continue;
        rows.add(TrajectoryDataRow(
          daysAfterTreatment: dat,
          treatmentNumber: trtId ?? 0,
          treatmentLabel: trtCode ?? 'T${trtId ?? 0}',
          value: value,
        ));
      }
    }

    final series = buildTrajectory(assessmentCode: code, rows: rows);
    if (series != null) result.add(series);
  }

  return result;
});

// ---------------------------------------------------------------------------
// Intelligence
// ---------------------------------------------------------------------------

final trialIntelligenceServiceProvider =
    Provider<TrialIntelligenceService>((ref) {
  return TrialIntelligenceService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
    treatmentRepository: ref.watch(treatmentRepositoryProvider),
    weatherSnapshotRepository: ref.watch(weatherSnapshotRepositoryProvider),
  );
});

final trialInsightsProvider = FutureProvider.autoDispose
    .family<List<TrialInsight>, int>((ref, trialId) async {
  final treatments =
      await ref.watch(treatmentsForTrialProvider(trialId).future);
  final assessmentPairs = await ref.watch(
      trialAssessmentsWithDefinitionsForTrialProvider(trialId).future);
  final assessmentNames = <int, String>{
    for (final pair in assessmentPairs)
      if (pair.$1.legacyAssessmentId != null)
        pair.$1.legacyAssessmentId!: _cleanAssessmentName(
          pair.$1.displayNameOverride?.trim().isNotEmpty == true
              ? pair.$1.displayNameOverride!
              : pair.$2.name,
          pair.$1.sortOrder,
        ),
  };
  return ref
      .watch(trialIntelligenceServiceProvider)
      .computeInsights(
          trialId: trialId,
          treatments: treatments,
          assessmentNames: assessmentNames);
});

// ---------------------------------------------------------------------------
// Trial Data screen providers
// ---------------------------------------------------------------------------

/// Crop description for a trial. Null when not yet recorded.
final cropDescriptionForTrialProvider =
    FutureProvider.autoDispose.family<CropDescription?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.cropDescriptions)
        ..where((c) => c.trialId.equals(trialId)))
      .getSingleOrNull();
});

/// All current, non-deleted rating records for a trial (across all sessions).
final allSessionRatingsForTrialProvider =
    FutureProvider.autoDispose.family<List<RatingRecord>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ratingRecords)
        ..where((r) =>
            r.trialId.equals(trialId) &
            r.isCurrent.equals(true) &
            r.isDeleted.equals(false)))
      .get();
});

/// All weather snapshots for a trial, ordered by recordedAt ascending.
final weatherSnapshotsForTrialProvider =
    FutureProvider.autoDispose.family<List<WeatherSnapshot>, int>((ref, trialId) {
  return ref
      .watch(weatherSnapshotRepositoryProvider)
      .getWeatherSnapshotsForTrial(trialId);
});

String _cleanAssessmentName(String raw, int sortOrder) {
  final cleaned = raw
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'—\s*TA\d+'), '')
      .trim();
  return cleaned.isNotEmpty ? cleaned : 'Assessment ${sortOrder + 1}';
}

// ---------------------------------------------------------------------------
// SE type profile providers
// ---------------------------------------------------------------------------

final seTypeProfileRepositoryProvider =
    Provider<SeTypeProfileRepository>((ref) {
  return SeTypeProfileRepository(ref.watch(databaseProvider));
});

/// All seeded SE type profiles, ordered by prefix ascending.
final seTypeProfilesProvider = FutureProvider<List<SeTypeProfile>>((ref) {
  return ref.watch(seTypeProfileRepositoryProvider).getAll();
});

/// SE type profile for a single [ratingTypePrefix], or null if not seeded.
final seTypeProfileByPrefixProvider =
    FutureProvider.autoDispose.family<SeTypeProfile?, String>(
  (ref, ratingTypePrefix) {
    return ref
        .watch(seTypeProfileRepositoryProvider)
        .getByPrefix(ratingTypePrefix);
  },
);
