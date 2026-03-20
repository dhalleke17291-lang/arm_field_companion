import '../../core/database/app_database.dart';
import '../plots/plot_repository.dart';
import '../sessions/session_repository.dart';
import '../photos/photo_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import 'data/export_repository.dart';
import 'standalone_report_data.dart';

/// Assembles report-ready data for a trial from existing repositories.
/// No PDF generation; no derived statistics.
/// Used by future standalone report/PDF layer.
class ReportDataAssemblyService {
  ReportDataAssemblyService({
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required SessionRepository sessionRepository,
    required AssignmentRepository assignmentRepository,
    required PhotoRepository photoRepository,
    required ExportRepository exportRepository,
  })  : _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _applicationRepository = applicationRepository,
        _sessionRepository = sessionRepository,
        _assignmentRepository = assignmentRepository,
        _photoRepository = photoRepository,
        _exportRepository = exportRepository;

  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final ApplicationRepository _applicationRepository;
  final SessionRepository _sessionRepository;
  final AssignmentRepository _assignmentRepository;
  final PhotoRepository _photoRepository;
  final ExportRepository _exportRepository;

  /// Assembles report data for the given trial.
  /// Trial must exist; returns assembled DTO or throws.
  Future<StandaloneReportData> assembleForTrial(Trial trial) async {
    final trialPk = trial.id;

    final plots = await _plotRepository.getPlotsForTrial(trialPk);
    final treatments =
        await _treatmentRepository.getTreatmentsForTrial(trialPk);
    final sessions = await _sessionRepository.getSessionsForTrial(trialPk);
    final applications =
        await _applicationRepository.getApplicationsForTrial(trialPk);
    final assignments = await _assignmentRepository.getForTrial(trialPk);
    final photos = await _photoRepository.getPhotosForTrial(trialPk);

    final treatmentMap = {for (final t in treatments) t.id: t};
    final assignmentByPlot = {for (final a in assignments) a.plotId: a};

    final trialSummary = TrialReportSummary(
      id: trial.id,
      name: trial.name,
      crop: trial.crop,
      location: trial.location,
      season: trial.season,
      status: trial.status,
      workspaceType: trial.workspaceType,
    );

    final treatmentSummaries = <TreatmentReportSummary>[];
    for (final t in treatments) {
      final components =
          await _treatmentRepository.getComponentsForTreatment(t.id);
      treatmentSummaries.add(TreatmentReportSummary(
        id: t.id,
        code: t.code,
        name: t.name,
        treatmentType: t.treatmentType,
        componentCount: components.length,
      ));
    }

    final plotSummaries = <PlotReportSummary>[];
    for (final plot in plots) {
      final assignment = assignmentByPlot[plot.id];
      final treatmentId = assignment?.treatmentId ?? plot.treatmentId;
      final treatment = treatmentId != null ? treatmentMap[treatmentId] : null;
      plotSummaries.add(PlotReportSummary(
        plotPk: plot.id,
        plotId: plot.plotId,
        plotSortIndex: plot.plotSortIndex,
        rep: assignment?.replication ?? plot.rep,
        treatmentId: treatmentId,
        treatmentCode: treatment?.code,
      ));
    }

    final sessionSummaries = sessions
        .map((s) => SessionReportSummary(
              id: s.id,
              name: s.name,
              sessionDateLocal: s.sessionDateLocal,
              status: s.status,
            ))
        .toList();

    final applicationEvents = applications
        .map((a) => ApplicationReportSummary(
              id: a.id,
              applicationDate: a.applicationDate,
              productName: a.productName,
            ))
        .toList();

    final applicationsSummary = ApplicationsReportSummary(
      count: applications.length,
      events: applicationEvents,
    );

    final photoSummary = PhotoReportSummary(count: photos.length);

    final rawRatings = await _exportRepository
        .buildTrialExportRows(trialId: trialPk);

    final ratingRows = rawRatings.map((r) {
      return RatingResultRow(
        plotId: r['plot_id'] as String? ?? '-',
        rep: (r['rep'] as int?) ?? 0,
        treatmentCode: r['treatment_code'] as String? ?? '-',
        assessmentName: r['assessment_name'] as String? ?? '-',
        unit: r['unit'] as String? ?? '',
        value: r['value'] as String? ?? '-',
        resultStatus: r['result_status'] as String? ?? 'RECORDED',
      );
    }).toList();

    return StandaloneReportData(
      trial: trialSummary,
      treatments: treatmentSummaries,
      plots: plotSummaries,
      sessions: sessionSummaries,
      applications: applicationsSummary,
      photoCount: photoSummary,
      ratings: ratingRows,
    );
  }
}
