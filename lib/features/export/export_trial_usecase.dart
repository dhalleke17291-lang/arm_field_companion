import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../plots/plot_repository.dart';
import '../trials/trial_repository.dart';
import '../sessions/session_repository.dart';
import '../ratings/rating_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import 'csv_export_service.dart';
import 'trial_export_bundle.dart';

/// Exports a trial to six CSV files using existing repositories only.
class ExportTrialUseCase {
  ExportTrialUseCase({
    required TrialRepository trialRepository,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required SeedingRepository seedingRepository,
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
    required AssignmentRepository assignmentRepository,
  })  : _trialRepository = trialRepository,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _applicationRepository = applicationRepository,
        _seedingRepository = seedingRepository,
        _sessionRepository = sessionRepository,
        _ratingRepository = ratingRepository,
        _assignmentRepository = assignmentRepository;

  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final ApplicationRepository _applicationRepository;
  final SeedingRepository _seedingRepository;
  final SessionRepository _sessionRepository;
  final RatingRepository _ratingRepository;
  final AssignmentRepository _assignmentRepository;

  static const List<String> _observationsHeaders = [
    'trial_name',
    'session_name',
    'session_date',
    'plot_label',
    'rep',
    'plot_position',
    'treatment_code',
    'treatment_name',
    'assessment_name',
    'assessment_type',
    'value',
    'unit',
    'rater_name',
    'days_after_seeding',
    'days_after_first_application',
  ];

  static const List<String> _treatmentsHeaders = [
    'treatment_code',
    'treatment_name',
    'component_name',
    'active_ingredient',
    'rate',
    'rate_unit',
    'formulation',
  ];

  static const List<String> _plotAssignmentsHeaders = [
    'plot_label',
    'rep',
    'column',
    'treatment_code',
    'treatment_name',
  ];

  static const List<String> _applicationsHeaders = [
    'date',
    'product_name',
    'rate',
    'rate_unit',
    'water_volume_lha',
    'growth_stage',
    'operator_name',
    'equipment',
    'wind_speed',
    'wind_direction',
    'temperature_c',
    'humidity_pct',
    'notes',
    'days_after_seeding',
  ];

  static const List<String> _seedingHeaders = [
    'seeding_date',
    'operator_name',
    'seed_lot_number',
    'seeding_rate',
    'seeding_rate_unit',
    'seeding_depth_cm',
    'row_spacing_cm',
    'equipment_used',
    'notes',
  ];

  static const List<String> _sessionsHeaders = [
    'session_name',
    'session_date',
    'status',
    'plot_count_rated',
    'rater_name',
    'notes',
  ];

  Future<TrialExportBundle> execute(String trialId) async {
    final trialPk = int.parse(trialId);
    final trial = await _trialRepository.getTrialById(trialPk);
    if (trial == null) throw ExportTrialException('Trial not found: $trialId');

    final plots = await _plotRepository.getPlotsForTrial(trialPk);
    final plotMap = {for (final p in plots) p.id: p};
    final treatments = await _treatmentRepository.getTreatmentsForTrial(trialPk);
    final treatmentMap = {for (final t in treatments) t.id: t};
    final applications = await _applicationRepository.getApplicationsForTrial(trialPk);
    final seeding = await _seedingRepository.getSeedingEventForTrial(trialPk);
    final sessions = await _sessionRepository.getSessionsForTrial(trialPk);
    final assignments = await _assignmentRepository.getForTrial(trialPk);
    final assignmentByPlot = {for (final a in assignments) a.plotId: a};

    final DateTime? seedingDate = seeding?.seedingDate;
    final DateTime? firstAppDate = applications.isEmpty
        ? null
        : applications
            .map((e) => e.applicationDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);

    final observationsCsv = await _buildObservationsCsv(
      trial: trial,
      sessions: sessions,
      plotMap: plotMap,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
      seedingDate: seedingDate,
      firstAppDate: firstAppDate,
    );

    final treatmentsCsv = await _buildTreatmentsCsv(treatments);

    final plotAssignmentsCsv = _buildPlotAssignmentsCsv(
      plots: plots,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
    );

    final applicationsCsv = _buildApplicationsCsv(
      applications: applications,
      seedingDate: seedingDate,
    );

    final seedingCsv = _buildSeedingCsv(seeding);

    final sessionsCsv = await _buildSessionsCsv(sessions);

    return TrialExportBundle(
      observationsCsv: observationsCsv,
      treatmentsCsv: treatmentsCsv,
      plotAssignmentsCsv: plotAssignmentsCsv,
      applicationsCsv: applicationsCsv,
      seedingCsv: seedingCsv,
      sessionsCsv: sessionsCsv,
    );
  }

  String _str(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<String> _buildObservationsCsv({
    required Trial trial,
    required List<Session> sessions,
    required Map<int, Plot> plotMap,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Assignment> assignmentByPlot,
    required DateTime? seedingDate,
    required DateTime? firstAppDate,
  }) async {
    final rows = <List<String>>[];
    for (final session in sessions) {
      final sessionAssessments = await _sessionRepository.getSessionAssessments(session.id);
      final assessmentMap = {for (final a in sessionAssessments) a.id: a};
      final ratings = await _ratingRepository.getCurrentRatingsForSession(session.id);
      for (final r in ratings) {
        final plot = plotMap[r.plotPk];
        final assignment = plot != null ? assignmentByPlot[plot.id] : null;
        final treatmentId = assignment?.treatmentId ?? plot?.treatmentId;
        final treatment = treatmentId != null ? treatmentMap[treatmentId] : null;
        final assessment = assessmentMap[r.assessmentId];

        final sessionDate = session.sessionDateLocal;
        final plotLabel = plot?.plotId ?? '';
        final rep = _str(assignment?.replication ?? plot?.rep);
        final plotPosition = _str(plot?.column ?? plot?.plotSortIndex ?? assignment?.position);
        final treatmentCode = treatment?.code ?? '';
        final treatmentName = treatment?.name ?? '';
        final assessmentName = assessment?.name ?? '';
        final assessmentType = assessment?.dataType ?? '';
        final value = r.numericValue != null
            ? _str(r.numericValue)
            : (r.textValue ?? '');
        final unit = assessment?.unit ?? '';
        final raterName = r.raterName ?? '';

        int? daysAfterSeeding;
        if (seedingDate != null) {
          daysAfterSeeding = r.createdAt.difference(seedingDate).inDays;
        }
        int? daysAfterFirstApp;
        if (firstAppDate != null) {
          daysAfterFirstApp = r.createdAt.difference(firstAppDate).inDays;
        }

        rows.add([
          trial.name,
          session.name,
          sessionDate,
          plotLabel,
          rep,
          plotPosition,
          treatmentCode,
          treatmentName,
          assessmentName,
          assessmentType,
          value,
          unit,
          raterName,
          daysAfterSeeding != null ? _str(daysAfterSeeding) : '',
          daysAfterFirstApp != null ? _str(daysAfterFirstApp) : '',
        ]);
      }
    }
    return CsvExportService.buildCsv(_observationsHeaders, rows);
  }

  Future<String> _buildTreatmentsCsv(List<Treatment> treatments) async {
    final rows = <List<String>>[];
    for (final t in treatments) {
      final components = await _treatmentRepository.getComponentsForTreatment(t.id);
      if (components.isEmpty) {
        rows.add([t.code, t.name, '', '', '', '', '']);
      } else {
        for (final c in components) {
          rows.add([
            t.code,
            t.name,
            c.productName,
            '', // active_ingredient not in schema
            c.rate ?? '',
            c.rateUnit ?? '',
            '', // formulation not in schema
          ]);
        }
      }
    }
    return CsvExportService.buildCsv(_treatmentsHeaders, rows);
  }

  String _buildPlotAssignmentsCsv({
    required List<Plot> plots,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Assignment> assignmentByPlot,
  }) {
    final rows = <List<String>>[];
    for (final plot in plots) {
      final assignment = assignmentByPlot[plot.id];
      final treatmentId = assignment?.treatmentId ?? plot.treatmentId;
      final treatment = treatmentId != null ? treatmentMap[treatmentId] : null;
      rows.add([
        plot.plotId,
        _str(assignment?.replication ?? plot.rep),
        _str(assignment?.column ?? plot.column),
        treatment?.code ?? '',
        treatment?.name ?? '',
      ]);
    }
    return CsvExportService.buildCsv(_plotAssignmentsHeaders, rows);
  }

  String _buildApplicationsCsv({
    required List<TrialApplicationEvent> applications,
    DateTime? seedingDate,
  }) {
    final rows = <List<String>>[];
    for (final a in applications) {
      int? daysAfterSeeding;
      if (seedingDate != null) {
        daysAfterSeeding = a.applicationDate.difference(seedingDate).inDays;
      }
      rows.add([
        _date(a.applicationDate),
        a.productName ?? '',
        _str(a.rate),
        a.rateUnit ?? '',
        _str(a.waterVolume),
        a.growthStageCode ?? '',
        a.operatorName ?? '',
        a.equipmentUsed ?? '',
        _str(a.windSpeed),
        a.windDirection ?? '',
        _str(a.temperature),
        _str(a.humidity),
        a.notes ?? '',
        daysAfterSeeding != null ? _str(daysAfterSeeding) : '',
      ]);
    }
    return CsvExportService.buildCsv(_applicationsHeaders, rows);
  }

  String _buildSeedingCsv(SeedingEvent? seeding) {
    if (seeding == null) {
      return CsvExportService.buildCsv(_seedingHeaders, []);
    }
    final row = [
      _date(seeding.seedingDate),
      seeding.operatorName ?? '',
      seeding.seedLotNumber ?? '',
      _str(seeding.seedingRate),
      seeding.seedingRateUnit ?? '',
      _str(seeding.seedingDepth),
      _str(seeding.rowSpacing),
      seeding.equipmentUsed ?? '',
      seeding.notes ?? '',
    ];
    return CsvExportService.buildCsv(_seedingHeaders, [row]);
  }

  Future<String> _buildSessionsCsv(List<Session> sessions) async {
    final rows = <List<String>>[];
    for (final s in sessions) {
      final ratings = await _ratingRepository.getCurrentRatingsForSession(s.id);
      final plotCountRated = ratings.map((r) => r.plotPk).toSet().length;
      rows.add([
        s.name,
        s.sessionDateLocal,
        s.status,
        _str(plotCountRated),
        s.raterName ?? '',
        '', // notes not on Session in schema
      ]);
    }
    return CsvExportService.buildCsv(_sessionsHeaders, rows);
  }
}

class ExportTrialException implements Exception {
  ExportTrialException(this.message);
  final String message;
  @override
  String toString() => 'ExportTrialException: $message';
}
