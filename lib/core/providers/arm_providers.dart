import 'package:drift/drift.dart' as drift;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../data/arm/arm_applications_repository.dart';
import '../../data/arm/arm_column_mapping_repository.dart';
import '../../data/arm/arm_treatment_metadata_repository.dart';
import '../../data/arm/arm_trial_metadata_repository.dart';
import '../../features/arm_import/data/arm_assessment_definition_resolver.dart';
import '../../features/arm_import/data/arm_import_persistence_repository.dart';
import '../../features/arm_import/data/arm_import_report_builder.dart';
import '../../features/arm_import/data/arm_import_snapshot_service.dart';
import '../../features/arm_import/data/arm_plot_insert_service.dart';
import '../../features/arm_import/data/compatibility_profile_builder.dart';
import '../../features/arm_import/usecases/import_arm_rating_shell_usecase.dart';
import '../../features/arm_protocol/arm_protocol_tab.dart';
import '../../features/derived/domain/trajectory_analysis.dart';
import 'cognition_providers.dart';
import 'infrastructure_providers.dart';
import 'trial_providers.dart';

final armImportPersistenceRepositoryProvider =
    Provider<ArmImportPersistenceRepository>((ref) {
  return ArmImportPersistenceRepository(ref.watch(databaseProvider));
});

final armImportSnapshotServiceProvider =
    Provider<ArmImportSnapshotService>((ref) => ArmImportSnapshotService());

final compatibilityProfileBuilderProvider =
    Provider<CompatibilityProfileBuilder>(
        (ref) => CompatibilityProfileBuilder());

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
  return ref.watch(armTrialMetadataRepositoryProvider).watchForTrial(trialId);
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
/// Lives in providers (the DI composition root) so that
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
  (ref, trialId) async =>
      ref.watch(armTreatmentMetadataRepositoryProvider).getMapForTrial(trialId),
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
    intentSeeder: ref.watch(trialIntentSeederProvider),
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
