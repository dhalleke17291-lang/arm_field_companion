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
    'trial_id',
    'trial_name',
    'session_name',
    'session_date',
    'plot_id',
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
    'export_timestamp',
  ];

  static const List<String> _treatmentsHeaders = [
    'treatment_code',
    'treatment_name',
    'component_name',
    'active_ingredient',
    'rate',
    'rate_unit',
    'formulation',
    'export_timestamp',
  ];

  static const List<String> _plotAssignmentsHeaders = [
    'trial_id',
    'plot_id',
    'plot_label',
    'rep',
    'column',
    'treatment_code',
    'treatment_name',
    'export_timestamp',
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
    'export_timestamp',
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
    'export_timestamp',
  ];

  static const List<String> _sessionsHeaders = [
    'session_name',
    'session_date',
    'status',
    'plot_count_rated',
    'rater_name',
    'notes',
    'export_timestamp',
  ];

  Future<TrialExportBundle> execute(String trialId) async {
    final exportTimestamp = DateTime.now().toUtc().toIso8601String();
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
      exportTimestamp: exportTimestamp,
    );

    final treatmentsCsv = await _buildTreatmentsCsv(
      treatments,
      exportTimestamp,
    );

    final plotAssignmentsCsv = _buildPlotAssignmentsCsv(
      plots: plots,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
      trialPk: trialPk,
      exportTimestamp: exportTimestamp,
    );

    final applicationsCsv = _buildApplicationsCsv(
      applications: applications,
      seedingDate: seedingDate,
      exportTimestamp: exportTimestamp,
    );

    final seedingCsv = _buildSeedingCsv(seeding, exportTimestamp);

    final sessionsCsv = await _buildSessionsCsv(
      sessions,
      exportTimestamp,
    );

    return TrialExportBundle(
      observationsCsv: observationsCsv,
      treatmentsCsv: treatmentsCsv,
      plotAssignmentsCsv: plotAssignmentsCsv,
      applicationsCsv: applicationsCsv,
      seedingCsv: seedingCsv,
      sessionsCsv: sessionsCsv,
    );
  }

  /// Exports as empty string for null, empty, or placeholder literals; otherwise string value.
  String _cell(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower == 'null' || lower == 'n/a' || lower == 'none') return '';
    return s;
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
    required String exportTimestamp,
  }) async {
    final trialPk = trial.id;
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

        final sessionDate = _cell(session.sessionDateLocal);
        final plotId = plot != null ? _cell(plot.id) : '';
        final plotLabel = _cell(plot?.plotId);
        final rep = _cell(assignment?.replication ?? plot?.rep);
        final plotPosition = _cell(plot?.column ?? plot?.plotSortIndex ?? assignment?.position);
        final treatmentCode = _cell(treatment?.code);
        final treatmentName = _cell(treatment?.name);
        final assessmentName = _cell(assessment?.name);
        final assessmentType = _cell(assessment?.dataType);
        final value = r.numericValue != null
            ? _cell(r.numericValue)
            : _cell(r.textValue);
        final unit = _cell(assessment?.unit);
        final raterName = _cell(r.raterName);

        int? daysAfterSeeding;
        if (seedingDate != null) {
          daysAfterSeeding = r.createdAt.difference(seedingDate).inDays;
        }
        int? daysAfterFirstApp;
        if (firstAppDate != null) {
          daysAfterFirstApp = r.createdAt.difference(firstAppDate).inDays;
        }

        rows.add([
          _cell(trialPk),
          _cell(trial.name),
          _cell(session.name),
          sessionDate,
          plotId,
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
          daysAfterSeeding != null ? _cell(daysAfterSeeding) : '',
          daysAfterFirstApp != null ? _cell(daysAfterFirstApp) : '',
          exportTimestamp,
        ]);
      }
    }
    return CsvExportService.buildCsv(_observationsHeaders, rows);
  }

  Future<String> _buildTreatmentsCsv(
    List<Treatment> treatments,
    String exportTimestamp,
  ) async {
    final rows = <List<String>>[];
    for (final t in treatments) {
      final components = await _treatmentRepository.getComponentsForTreatment(t.id);
      if (components.isEmpty) {
        rows.add([
          _cell(t.code),
          _cell(t.name),
          '',
          '',
          '',
          '',
          '',
          exportTimestamp,
        ]);
      } else {
        for (final c in components) {
          rows.add([
            _cell(t.code),
            _cell(t.name),
            _cell(c.productName),
            '', // active_ingredient not in schema
            _cell(c.rate),
            _cell(c.rateUnit),
            '', // formulation not in schema
            exportTimestamp,
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
    required int trialPk,
    required String exportTimestamp,
  }) {
    final rows = <List<String>>[];
    for (final plot in plots) {
      final assignment = assignmentByPlot[plot.id];
      final treatmentId = assignment?.treatmentId ?? plot.treatmentId;
      final treatment = treatmentId != null ? treatmentMap[treatmentId] : null;
      rows.add([
        _cell(trialPk),
        _cell(plot.id),
        _cell(plot.plotId),
        _cell(assignment?.replication ?? plot.rep),
        _cell(assignment?.column ?? plot.column),
        _cell(treatment?.code),
        _cell(treatment?.name),
        exportTimestamp,
      ]);
    }
    return CsvExportService.buildCsv(_plotAssignmentsHeaders, rows);
  }

  String _buildApplicationsCsv({
    required List<TrialApplicationEvent> applications,
    DateTime? seedingDate,
    required String exportTimestamp,
  }) {
    final rows = <List<String>>[];
    for (final a in applications) {
      int? daysAfterSeeding;
      if (seedingDate != null) {
        daysAfterSeeding = a.applicationDate.difference(seedingDate).inDays;
      }
      rows.add([
        _date(a.applicationDate),
        _cell(a.productName),
        _cell(a.rate),
        _cell(a.rateUnit),
        _cell(a.waterVolume),
        _cell(a.growthStageCode),
        _cell(a.operatorName),
        _cell(a.equipmentUsed),
        _cell(a.windSpeed),
        _cell(a.windDirection),
        _cell(a.temperature),
        _cell(a.humidity),
        _cell(a.notes),
        daysAfterSeeding != null ? _cell(daysAfterSeeding) : '',
        exportTimestamp,
      ]);
    }
    return CsvExportService.buildCsv(_applicationsHeaders, rows);
  }

  String _buildSeedingCsv(SeedingEvent? seeding, String exportTimestamp) {
    if (seeding == null) {
      return CsvExportService.buildCsv(_seedingHeaders, []);
    }
    final row = [
      _date(seeding.seedingDate),
      _cell(seeding.operatorName),
      _cell(seeding.seedLotNumber),
      _cell(seeding.seedingRate),
      _cell(seeding.seedingRateUnit),
      _cell(seeding.seedingDepth),
      _cell(seeding.rowSpacing),
      _cell(seeding.equipmentUsed),
      _cell(seeding.notes),
      exportTimestamp,
    ];
    return CsvExportService.buildCsv(_seedingHeaders, [row]);
  }

  Future<String> _buildSessionsCsv(
    List<Session> sessions,
    String exportTimestamp,
  ) async {
    final rows = <List<String>>[];
    for (final s in sessions) {
      final ratings = await _ratingRepository.getCurrentRatingsForSession(s.id);
      final plotCountRated = ratings.map((r) => r.plotPk).toSet().length;
      rows.add([
        _cell(s.name),
        _cell(s.sessionDateLocal),
        _cell(s.status),
        _cell(plotCountRated),
        _cell(s.raterName),
        '', // notes not on Session in schema
        exportTimestamp,
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
