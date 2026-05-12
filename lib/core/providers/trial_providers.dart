import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../session_state.dart';
import '../trial_operational_watch_merge.dart';
import '../ui/trial_application_product_summary.dart';
import '../workspace/workspace_filter.dart';
import '../../data/repositories/application_plot_assignment_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/application_product_repository.dart';
import '../../data/repositories/assessment_definition_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/trial_assessment_repository.dart';
import '../../domain/models/plot_context.dart';
import '../../domain/usecases/resolve_plot_treatment.dart';
import '../../features/assessments/add_curated_library_assessments_to_trial_usecase.dart';
import '../../features/diagnostics/scan_rcbd_layouts_usecase.dart';
import '../../features/plots/plot_repository.dart';
import '../../features/plots/usecases/generate_rep_guard_plots_usecase.dart';
import '../../features/plots/usecases/update_plot_details_usecase.dart';
import '../../features/protocol_import/protocol_import_usecase.dart';
import '../../features/trials/standalone/create_standalone_trial_wizard_usecase.dart';
import '../../features/trials/standalone/generate_standalone_plot_layout_usecase.dart';
import '../../features/trials/trial_repository.dart';
import '../../features/trials/usecases/create_trial_usecase.dart';
import '../../features/trials/usecases/delete_treatment_usecase.dart';
import '../../features/trials/usecases/update_treatment_usecase.dart';
import '../../data/repositories/treatment_repository.dart';
import '../connectivity/application_weather_backfill_service.dart';
import '../connectivity/seeding_weather_backfill_service.dart';
import 'cognition_providers.dart';
import 'infrastructure_providers.dart';

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

final protocolImportUseCaseProvider = Provider<ProtocolImportUseCase>((ref) {
  return ProtocolImportUseCase(
    ref.watch(databaseProvider),
    ref.watch(trialRepositoryProvider),
    ref.watch(treatmentRepositoryProvider),
    ref.watch(plotRepositoryProvider),
    ref.watch(assignmentRepositoryProvider),
  );
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
    intentSeeder: ref.watch(trialIntentSeederProvider),
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
  return (db.select(db.trials)..where((t) => t.id.equals(id)))
      .watchSingleOrNull();
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

/// Soft-deleted trials (Recovery). Newest [deletedAt] first.
final deletedTrialsProvider = FutureProvider.autoDispose<List<Trial>>((ref) {
  return ref.watch(trialRepositoryProvider).getDeletedTrials();
});

/// Soft-deleted plots across all trials (Recovery). Newest [deletedAt] first.
final deletedPlotsProvider = FutureProvider.autoDispose<List<Plot>>((ref) {
  return ref.watch(plotRepositoryProvider).getAllDeletedPlots();
});

/// Soft-deleted plots for one trial (Recovery trial-scoped).
final deletedPlotsForTrialRecoveryProvider =
    FutureProvider.autoDispose.family<List<Plot>, int>((ref, trialId) {
  return ref.watch(plotRepositoryProvider).getDeletedPlotsForTrial(trialId);
});

/// Seeding records for a trial (for Seeding tab).
final seedingRecordsForTrialProvider =
    StreamProvider.autoDispose.family<List<SeedingRecord>, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.seedingRecords)
        ..where((t) => t.trialId.equals(trialId))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
      .watch();
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
final trialApplicationProductsForEventProvider = StreamProvider.autoDispose
    .family<List<TrialApplicationProduct>, String>((ref, eventId) {
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

final scanRcbdLayoutsUseCaseProvider = Provider<ScanRcbdLayoutsUseCase>((ref) {
  return ScanRcbdLayoutsUseCase(
    db: ref.watch(databaseProvider),
    plotRepository: ref.watch(plotRepositoryProvider),
    assignmentRepository: ref.watch(assignmentRepositoryProvider),
  );
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

/// Crop description for a trial. Null when not yet recorded.
final cropDescriptionForTrialProvider =
    FutureProvider.autoDispose.family<CropDescription?, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.cropDescriptions)
        ..where((c) => c.trialId.equals(trialId)))
      .getSingleOrNull();
});

/// All weather snapshots for a trial, ordered by recordedAt ascending.
final weatherSnapshotsForTrialProvider = FutureProvider.autoDispose
    .family<List<WeatherSnapshot>, int>((ref, trialId) {
  return ref
      .watch(weatherSnapshotRepositoryProvider)
      .getWeatherSnapshotsForTrial(trialId);
});

