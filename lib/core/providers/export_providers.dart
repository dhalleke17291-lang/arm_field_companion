import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../diagnostics/diagnostic_finding.dart';
import '../diagnostics/trial_export_diagnostics.dart';
import '../plot_analysis_eligibility.dart';
import '../trial_operational_watch_merge.dart';
import '../../domain/signals/signal_providers.dart';
import '../../features/derived/domain/trial_statistics.dart';
import '../../features/export/standalone_report_data.dart';
import '../../features/diagnostics/trial_readiness.dart';
import '../../features/diagnostics/trial_readiness_service.dart';
import '../../features/export/data/export_repository.dart';
import '../../features/export/domain/arm_shell_link_usecase.dart';
import '../../features/export/domain/compute_arm_round_trip_diagnostics_usecase.dart';
import '../../features/export/domain/export_arm_rating_shell_usecase.dart';
import '../../features/export/domain/export_deleted_session_recovery_zip_usecase.dart';
import '../../features/export/domain/export_deleted_trial_recovery_zip_usecase.dart';
import '../../features/export/domain/export_session_arm_xml_usecase.dart';
import '../../features/export/domain/export_session_csv_usecase.dart';
import '../../features/export/domain/export_trial_closed_sessions_arm_xml_usecase.dart';
import '../../features/export/domain/export_trial_closed_sessions_usecase.dart';
import '../../features/export/evidence_report_assembly_service.dart';
import '../../features/export/evidence_report_pdf_builder.dart';
import '../../features/export/export_evidence_report_usecase.dart';
import '../../features/export/export_trial_defensibility_usecase.dart';
import '../../features/export/export_trial_pdf_report_usecase.dart';
import '../../features/export/export_trial_ratings_share_usecase.dart';
import '../../features/export/export_trial_report_usecase.dart';
import '../../features/export/export_trial_usecase.dart';
import '../../features/export/field_execution_report_assembly_service.dart';
import '../../features/export/report_data_assembly_service.dart';
import '../../features/export/report_pdf_builder_service.dart';
import '../../features/export/usecases/arm_export_preflight_usecase.dart';
import 'arm_providers.dart';
import 'cognition_providers.dart';
import 'infrastructure_providers.dart';
import 'session_providers.dart';
import 'trial_providers.dart';

// ===== Export (CSV) =====

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepository(
    ref.watch(databaseProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
  );
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
      signalRepository: ref.watch(signalRepositoryProvider),
      db: ref.watch(databaseProvider),
    ),
    pdfBuilder: EvidenceReportPdfBuilder(),
  );
});

final fieldExecutionReportAssemblyServiceProvider =
    Provider<FieldExecutionReportAssemblyService>((ref) {
  return FieldExecutionReportAssemblyService(
    plotRepository: ref.watch(plotRepositoryProvider),
    ratingRepository: ref.watch(ratingRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    signalRepository: ref.watch(signalRepositoryProvider),
    seedingRepository: ref.watch(seedingRepositoryProvider),
    completenessUseCase: ref.watch(computeSessionCompletenessUseCaseProvider),
    purposeRepository: ref.watch(trialPurposeRepositoryProvider),
    ctqFactorRepository: ref.watch(ctqFactorDefinitionRepositoryProvider),
    db: ref.watch(databaseProvider),
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

final exportTrialDefensibilityUseCaseProvider =
    Provider<ExportTrialDefensibilityUseCase>((ref) {
  return ExportTrialDefensibilityUseCase(ref);
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

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

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
    final sessionMetaMap =
        await ref.read(armSessionMetadataMapForTrialProvider(trialId).future);

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
    final filteredRatingRows = ratingRows
        .where((r) => analyzablePlotLabels.contains(r.plotId))
        .toList();
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
            measurementCategory: def.dataType,
          ),
        ];
        continue;
      }

      result[ta.id] = [
        for (final sid in sessionIds)
          computeAssessmentStatistics(
            filteredRatingRows
                .where((r) => r.assessmentName == name && r.sessionId == sid)
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
            measurementCategory: def.dataType,
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

// ---------------------------------------------------------------------------
// Readiness & diagnostics
// ---------------------------------------------------------------------------

/// Unified trial readiness report (blockers, warnings, passes). Used for readiness card and export gating.
final trialReadinessProvider = StreamProvider.autoDispose
    .family<TrialReadinessReport, int>((ref, trialId) {
  final db = ref.watch(databaseProvider);
  return mergeTrialOperationalTableWatches(db, trialId).asyncMap(
      (_) => TrialReadinessService().runChecks(trialId.toString(), ref));
});

/// Merged [DiagnosticFinding]s for trial-scoped diagnostics UI (readiness sheet).
///
/// Combines live readiness checks (non-pass) with the latest export-time
/// findings from [trialExportDiagnosticsMapProvider] (validation + ARM
/// confidence from the most recent export attempt). Snapshots are persisted in
/// Drift and hydrated on startup.
final trialDiagnosticsProvider =
    Provider.autoDispose.family<List<DiagnosticFinding>, int>((ref, trialId) {
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
