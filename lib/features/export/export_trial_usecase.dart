import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/plot_analysis_eligibility.dart';
import '../../core/diagnostics/diagnostic_finding.dart';
import '../diagnostics/trial_readiness.dart';
import '../../core/diagnostics/trial_export_diagnostics.dart'
    show kTrialExportAttemptLabel;
import '../arm_import/data/arm_import_persistence_repository.dart';
import '../plots/plot_repository.dart';
import 'export_confidence_policy.dart';
import 'arm_field_mapping.dart';
import 'export_format.dart';
import 'export_validation_service.dart' as export_validation;
import '../trials/trial_repository.dart';
import '../sessions/session_repository.dart';
import '../ratings/rating_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/application_product_repository.dart';
import '../../data/repositories/seeding_repository.dart';
import '../../data/repositories/assignment_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../photos/photo_export_name_builder.dart';
import '../photos/photo_repository.dart';
import '../weather/weather_export_builder.dart';
import '../../data/repositories/weather_snapshot_repository.dart';
import 'csv_export_service.dart';
import 'trial_export_bundle.dart';

/// Optional sink for trial-level export diagnostics (validation + confidence).
typedef PublishTrialExportDiagnostics = void Function(
  int trialId,
  List<DiagnosticFinding> findings,
  String attemptLabel,
);

class ExportBlockedByValidationException implements Exception {
  const ExportBlockedByValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExportBlockedByReadinessException implements Exception {
  const ExportBlockedByReadinessException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exports a trial to six CSV files using existing repositories only.
class ExportTrialUseCase {
  ExportTrialUseCase({
    required TrialRepository trialRepository,
    required PlotRepository plotRepository,
    required TreatmentRepository treatmentRepository,
    required ApplicationRepository applicationRepository,
    required ApplicationProductRepository applicationProductRepository,
    required SeedingRepository seedingRepository,
    required SessionRepository sessionRepository,
    required RatingRepository ratingRepository,
    required AssignmentRepository assignmentRepository,
    required PhotoRepository photoRepository,
    required WeatherSnapshotRepository weatherSnapshotRepository,
    required NotesRepository notesRepository,
    required ArmImportPersistenceRepository armImportPersistenceRepository,
    PublishTrialExportDiagnostics? publishExportDiagnostics,
  })  : _trialRepository = trialRepository,
        _plotRepository = plotRepository,
        _treatmentRepository = treatmentRepository,
        _applicationRepository = applicationRepository,
        _applicationProductRepository = applicationProductRepository,
        _seedingRepository = seedingRepository,
        _sessionRepository = sessionRepository,
        _ratingRepository = ratingRepository,
        _assignmentRepository = assignmentRepository,
        _photoRepository = photoRepository,
        _weatherSnapshotRepository = weatherSnapshotRepository,
        _notesRepository = notesRepository,
        _armImportPersistenceRepository = armImportPersistenceRepository,
        _publishExportDiagnostics = publishExportDiagnostics;

  final PublishTrialExportDiagnostics? _publishExportDiagnostics;

  // Kept for API consistency; trial is passed into execute().
  // ignore: unused_field
  final TrialRepository _trialRepository;
  final PlotRepository _plotRepository;
  final TreatmentRepository _treatmentRepository;
  final ApplicationRepository _applicationRepository;
  final ApplicationProductRepository _applicationProductRepository;
  final SeedingRepository _seedingRepository;
  final SessionRepository _sessionRepository;
  final RatingRepository _ratingRepository;
  final AssignmentRepository _assignmentRepository;
  final PhotoRepository _photoRepository;
  final WeatherSnapshotRepository _weatherSnapshotRepository;
  final NotesRepository _notesRepository;
  final ArmImportPersistenceRepository _armImportPersistenceRepository;

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
    'rating_time',
    'rating_method',
    'confidence',
    'amended',
    'original_value',
    'amendment_reason',
    'amended_by',
    'amended_at',
    'days_after_seeding',
    'days_after_first_application',
    'photo_files',
    'plot_excluded',
    'export_timestamp',
    'session_crop_stage_bbch',
  ];

  static const List<String> _observationsArmTransferHeaders = [
    'trial_id',
    'trial_name',
    'session_id',
    'session_name',
    'session_date',
    'plot_pk',
    'plot_id',
    'rep',
    'treatment_id',
    'treatment_code',
    'treatment_name',
    'assessment_id',
    'assessment_name',
    'unit',
    'result_status',
    'value_numeric',
    'value_text',
    'value_display',
    'rater_name',
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
    'plot_length_m',
    'plot_width_m',
    'plot_area_m2',
    'harvest_length_m',
    'harvest_width_m',
    'harvest_area_m2',
    'plot_direction',
    'soil_series',
    'plot_notes',
    'is_guard',
    'is_excluded',
    'exclusion_reason',
    'damage_type',
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
    'application_status',
    'applied_at',
    'application_method',
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
    'seeding_status',
    'completed_at',
    'planting_method',
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
    'crop_stage_bbch',
    'days_after_seeding',
    'days_after_first_application',
  ];

  static const List<String> _fieldNotesHeaders = [
    'note_id',
    'trial_name',
    'plot_id',
    'session_name',
    'content',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
    'export_timestamp',
  ];

  Future<TrialExportBundle> execute({
    required Trial trial,
    required ExportFormat format,
    TrialReadinessReport? trialReadinessPrecheck,
  }) async {
    final trialPk = trial.id;
    final exportDiagnosticsBuffer = <DiagnosticFinding>[];

    void publishExportDiagnostics() {
      _publishExportDiagnostics?.call(
        trialPk,
        List<DiagnosticFinding>.unmodifiable(
          List<DiagnosticFinding>.from(exportDiagnosticsBuffer),
        ),
        kTrialExportAttemptLabel,
      );
    }

    if (format == ExportFormat.armRatingShell) {
      throw ArgumentError(
        'Excel Rating Sheet must use ExportArmRatingShellUseCase, not ExportTrialUseCase.',
      );
    }
    final profile = await _armImportPersistenceRepository
        .getLatestCompatibilityProfileForTrial(trial.id);
    final gate = gateFromConfidence(profile?.exportConfidence);
    if (gate == ExportGate.block) {
      final msg = composeBlockedExportMessage(profile?.exportBlockReason);
      final finding = gate.toDiagnosticFinding(trialId: trialPk, message: msg);
      if (finding != null) exportDiagnosticsBuffer.add(finding);
      publishExportDiagnostics();
      throw ExportBlockedByConfidenceException(msg);
    }
    String? confidenceWarningMessage;
    if (gate == ExportGate.warn) {
      confidenceWarningMessage = kWarnExportMessage;
      final finding = gate.toDiagnosticFinding(
        trialId: trialPk,
        message: confidenceWarningMessage,
      );
      if (finding != null) exportDiagnosticsBuffer.add(finding);
    }

    if (trialReadinessPrecheck != null &&
        !trialReadinessPrecheck.canExport) {
      publishExportDiagnostics();
      throw const ExportBlockedByReadinessException(
          'Export is blocked — resolve the issues shown in the readiness panel before exporting.');
    }

    final exportTimestamp = DateTime.now().toUtc().toIso8601String();
    final armAligned =
        format == ExportFormat.armHandoff || format == ExportFormat.zipBundle;
    final utf8BomForExcel = format == ExportFormat.flatCsv;

    final plots = await _plotRepository.getPlotsForTrial(trialPk);
    final plotMap = {for (final p in plots) p.id: p};
    final treatments =
        await _treatmentRepository.getTreatmentsForTrial(trialPk);
    final treatmentMap = {for (final t in treatments) t.id: t};
    final applications =
        await _applicationRepository.getApplicationsForTrial(trialPk);
    final seeding = await _seedingRepository.getSeedingEventForTrial(trialPk);
    final sessions = await _sessionRepository.getSessionsForTrial(trialPk);
    final assignments = await _assignmentRepository.getForTrial(trialPk);
    final assignmentByPlot = {for (final a in assignments) a.plotId: a};

    final records = <RatingRecord>[];
    for (final session in sessions) {
      records.addAll(
          await _ratingRepository.getCurrentRatingsForSession(session.id));
    }
    final photos = await _photoRepository.getPhotosForTrial(trialPk);
    final assessmentDefs = <int, export_validation.AssessmentDefinition>{};
    for (final session in sessions) {
      final sessionAssessments =
          await _sessionRepository.getSessionAssessments(session.id);
      for (final a in sessionAssessments) {
        assessmentDefs[a.id] =
            export_validation.AssessmentDefinition(id: a.id, name: a.name);
      }
    }
    final validation = export_validation.ExportValidationService().validate(
      plots: plots,
      assignments: assignments,
      assessments: assessmentDefs.values.toList(),
      records: records,
      sessions: sessions,
      photos: photos,
    );
    for (final issue in validation.issues) {
      exportDiagnosticsBuffer.add(issue.toDiagnosticFinding(trialPk));
    }
    if (validation.issues
        .any((i) => i.severity == export_validation.IssueSeverity.error)) {
      publishExportDiagnostics();
      throw ExportBlockedByValidationException(
        validation.issues
            .where((i) => i.severity == export_validation.IssueSeverity.error)
            .map((i) => i.message)
            .join('\n'),
      );
    }
    final preflightNotes = validation.issues
        .where((i) =>
            i.severity == export_validation.IssueSeverity.warning ||
            i.severity == export_validation.IssueSeverity.info)
        .map((i) => i.message)
        .toList();

    // DAS uses completed seeding only — matches plot_queue and
    // rating_screen which both gate on status == 'completed'.
    // Pending seeding is recorded but not yet executed in the field.
    final DateTime? seedingDate =
        (seeding != null && seeding.status == 'completed')
            ? seeding.seedingDate
            : null;
    // DAS uses first APPLIED application only — pending applications
    // are planned but not executed and must not affect DAS calculations.
    final appliedApplications =
        applications.where((e) => e.status == 'applied').toList();
    final DateTime? firstAppDate = appliedApplications.isEmpty
        ? null
        : appliedApplications
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
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final observationsArmTransferCsv = await _buildObservationsArmTransferCsv(
      trial: trial,
      sessions: sessions,
      plotMap: plotMap,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
      utf8BomForExcel: utf8BomForExcel,
    );

    final treatmentsCsv = await _buildTreatmentsCsv(
      treatments,
      exportTimestamp,
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final plotAssignmentsCsv = _buildPlotAssignmentsCsv(
      plots: plots,
      treatmentMap: treatmentMap,
      assignmentByPlot: assignmentByPlot,
      trialPk: trialPk,
      exportTimestamp: exportTimestamp,
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final productsByEventId = <String, List<TrialApplicationProduct>>{};
    for (final a in applications) {
      productsByEventId[a.id] =
          await _applicationProductRepository.getProductsForEvent(a.id);
    }
    final applicationsCsv = await _buildApplicationsCsv(
      applications: applications,
      productsByEventId: productsByEventId,
      seedingDate: seedingDate,
      exportTimestamp: exportTimestamp,
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final seedingCsv = _buildSeedingCsv(
      seeding,
      exportTimestamp,
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final sessionsCsv = await _buildSessionsCsv(
      sessions,
      exportTimestamp,
      seedingDate: seedingDate,
      firstAppDate: firstAppDate,
      armAligned: armAligned,
      utf8BomForExcel: utf8BomForExcel,
    );

    final fieldNotes = await _notesRepository.getNotesForTrial(trialPk);
    final notesCsv = _buildFieldNotesCsv(
      trial: trial,
      notes: fieldNotes,
      plots: plots,
      sessions: sessions,
      exportTimestamp: exportTimestamp,
      utf8BomForExcel: utf8BomForExcel,
    );

    const appVersion = '1.0.0';
    final dataDictionaryCsv = _buildDataDictionary(
      exportTimestamp,
      appVersion,
      utf8BomForExcel: utf8BomForExcel,
    );

    final bundle = TrialExportBundle(
      observationsCsv: observationsCsv,
      observationsArmTransferCsv: observationsArmTransferCsv,
      treatmentsCsv: treatmentsCsv,
      plotAssignmentsCsv: plotAssignmentsCsv,
      applicationsCsv: applicationsCsv,
      seedingCsv: seedingCsv,
      sessionsCsv: sessionsCsv,
      notesCsv: notesCsv,
      dataDictionaryCsv: dataDictionaryCsv,
      warningMessage: confidenceWarningMessage,
      preflightNotes: preflightNotes.isEmpty ? null : preflightNotes,
    );

    if (armAligned) {
      final weatherSnapshots =
          await _weatherSnapshotRepository.getWeatherSnapshotsForTrial(trialPk);
      final sessionByIdForWeather = {for (final s in sessions) s.id: s};
      final activeWeatherSnapshots = weatherSnapshots.where((w) {
        if (w.parentType == kWeatherParentTypeRatingSession) {
          return sessionByIdForWeather[w.parentId] != null;
        }
        return true;
      }).toList();
      final zipFile = await _buildArmHandoffPackage(
        bundle,
        trial,
        validation,
        photos,
        plotMap: plotMap,
        assignmentByPlot: assignmentByPlot,
        treatmentMap: treatmentMap,
        sessionById: {for (final s in sessions) s.id: s},
        weatherSnapshots: activeWeatherSnapshots,
      );
      await Share.shareXFiles([XFile(zipFile.path, mimeType: 'application/zip')],
          text: '${trial.name} – Import Assistant package');
    }

    publishExportDiagnostics();
    return bundle;
  }

  /// Returns a static CSV documenting all exported columns. No queries.
  String _buildDataDictionary(
    String exportTimestamp,
    String appVersion, {
    bool utf8BomForExcel = false,
  }) {
    const headers = ['file', 'column', 'description', 'unit'];
    final rows = <List<String>>[
      // observations.csv
      [
        'observations.csv',
        '_file_note',
        'Primary long-format observations (one row per rating). Use for analysis; in handoff ZIP, headers map to external codes via arm_mapping.csv.',
        ''
      ],
      ['observations.csv', 'trial_id', 'Trial database identifier', ''],
      ['observations.csv', 'trial_name', 'Name of the trial', ''],
      ['observations.csv', 'session_name', 'Name of the rating session', ''],
      [
        'observations.csv',
        'session_date',
        'Date ratings were recorded',
        'YYYY-MM-DD'
      ],
      ['observations.csv', 'plot_id', 'Plot database identifier', ''],
      ['observations.csv', 'plot_label', 'Display label of plot e.g. 101', ''],
      ['observations.csv', 'rep', 'Replication number', ''],
      [
        'observations.csv',
        'plot_position',
        'Column position within replication',
        ''
      ],
      [
        'observations.csv',
        'treatment_code',
        'Code assigned to treatment e.g. T1',
        ''
      ],
      [
        'observations.csv',
        'treatment_name',
        'Human-readable treatment description',
        ''
      ],
      [
        'observations.csv',
        'assessment_name',
        'Name of assessment variable',
        ''
      ],
      [
        'observations.csv',
        'assessment_type',
        'Category of assessment e.g. visual rating',
        ''
      ],
      ['observations.csv', 'value', 'Recorded rating value', 'assessment unit'],
      ['observations.csv', 'unit', 'Unit associated with the value', ''],
      [
        'observations.csv',
        'rater_name',
        'Name of person who recorded the rating',
        ''
      ],
      [
        'observations.csv',
        'rating_time',
        'Local time of rating',
        'HH:mm'
      ],
      [
        'observations.csv',
        'rating_method',
        'Method used for rating',
        ''
      ],
      [
        'observations.csv',
        'confidence',
        'Rater confidence',
        'certain | uncertain | estimated'
      ],
      [
        'observations.csv',
        'amended',
        'Whether the rating was amended after first entry',
        ''
      ],
      [
        'observations.csv',
        'original_value',
        'First entered value before amendment',
        ''
      ],
      [
        'observations.csv',
        'amendment_reason',
        'Reason for amendment',
        ''
      ],
      [
        'observations.csv',
        'amended_by',
        'Person who amended the rating',
        ''
      ],
      [
        'observations.csv',
        'amended_at',
        'When the rating was amended',
        'ISO 8601'
      ],
      [
        'observations.csv',
        'days_after_seeding',
        'Days elapsed since seeding event',
        'days'
      ],
      [
        'observations.csv',
        'days_after_first_application',
        'Days elapsed since first application event',
        'days'
      ],
      [
        'observations.csv',
        'photo_files',
        'Comma-separated filenames of photos attached to this plot/session',
        ''
      ],
      [
        'observations.csv',
        'plot_excluded',
        'True if plot is excluded from analysis (guard row or researcher exclusion)',
        ''
      ],
      [
        'observations.csv',
        'export_timestamp',
        'UTC timestamp when export was generated',
        'ISO 8601'
      ],
      [
        'observations.csv',
        'session_crop_stage_bbch',
        'BBCH growth stage recorded on the rating session',
        '0–99'
      ],
      [
        'observations_arm_transfer.csv',
        '_file_note',
        'Manual-transfer-friendly table: internal plot PK, protocol plot label, session ID, result status, and separate numeric/text value columns.',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'trial_id',
        'Trial database identifier',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'trial_name',
        'Trial name',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'session_id',
        'Session database identifier',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'session_name',
        'Rating session name',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'session_date',
        'Session date (local)',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'plot_pk',
        'Internal plot primary key',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'plot_id',
        'Protocol / visible plot label',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'rep',
        'Replication number',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'treatment_id',
        'Treatment database identifier',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'treatment_code',
        'Treatment code',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'treatment_name',
        'Treatment name',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'assessment_id',
        'Assessment database identifier',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'assessment_name',
        'Assessment name',
        ''
      ],
      ['observations_arm_transfer.csv', 'unit', 'Assessment unit', ''],
      [
        'observations_arm_transfer.csv',
        'result_status',
        'Rating result status e.g. RECORDED',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'value_numeric',
        'Numeric value if present',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'value_text',
        'Text value if present',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'value_display',
        'Display value for manual transfer',
        ''
      ],
      [
        'observations_arm_transfer.csv',
        'rater_name',
        'Rater name',
        ''
      ],
      // treatments.csv
      ['treatments.csv', 'treatment_code', 'Code assigned to treatment', ''],
      ['treatments.csv', 'treatment_name', 'Human-readable treatment name', ''],
      [
        'treatments.csv',
        'component_name',
        'Name of treatment component or product',
        ''
      ],
      [
        'treatments.csv',
        'active_ingredient',
        'Active ingredient if specified',
        ''
      ],
      ['treatments.csv', 'rate', 'Application rate of component', ''],
      ['treatments.csv', 'rate_unit', 'Unit for component rate', ''],
      ['treatments.csv', 'formulation', 'Formulation type if specified', ''],
      [
        'treatments.csv',
        'export_timestamp',
        'UTC timestamp when export was generated',
        'ISO 8601'
      ],
      // plot_assignments.csv
      ['plot_assignments.csv', 'trial_id', 'Trial database identifier', ''],
      ['plot_assignments.csv', 'plot_id', 'Plot database identifier', ''],
      ['plot_assignments.csv', 'plot_label', 'Display label of plot', ''],
      ['plot_assignments.csv', 'rep', 'Replication number', ''],
      [
        'plot_assignments.csv',
        'column',
        'Column position within replication',
        ''
      ],
      ['plot_assignments.csv', 'treatment_code', 'Assigned treatment code', ''],
      ['plot_assignments.csv', 'treatment_name', 'Assigned treatment name', ''],
      ['plot_assignments.csv', 'plot_length_m', 'Plot length', 'm'],
      ['plot_assignments.csv', 'plot_width_m', 'Plot width', 'm'],
      ['plot_assignments.csv', 'plot_area_m2', 'Plot area', 'm²'],
      ['plot_assignments.csv', 'harvest_length_m', 'Harvest length', 'm'],
      ['plot_assignments.csv', 'harvest_width_m', 'Harvest width', 'm'],
      ['plot_assignments.csv', 'harvest_area_m2', 'Harvest area', 'm²'],
      ['plot_assignments.csv', 'plot_direction', 'Plot direction/orientation', ''],
      ['plot_assignments.csv', 'soil_series', 'Soil series', ''],
      ['plot_assignments.csv', 'plot_notes', 'Plot notes', ''],
      [
        'plot_assignments.csv',
        'is_guard',
        'True if plot is a guard/border row (not a data plot)',
        '',
      ],
      [
        'plot_assignments.csv',
        'is_excluded',
        'True if plot is excluded from analysis (includes guard rows)',
        '',
      ],
      [
        'plot_assignments.csv',
        'exclusion_reason',
        'Researcher-provided reason when excluded from analysis',
        '',
      ],
      [
        'plot_assignments.csv',
        'damage_type',
        'Damage category when excluded (mechanical, weather, animal, disease, contamination, other)',
        '',
      ],
      ['plot_assignments.csv', 'export_timestamp', 'UTC timestamp', 'ISO 8601'],
      // applications.csv
      ['applications.csv', 'date', 'Date of application event', 'YYYY-MM-DD'],
      [
        'applications.csv',
        'product_name',
        'Product or active ingredient applied',
        ''
      ],
      ['applications.csv', 'rate', 'Application rate', ''],
      ['applications.csv', 'rate_unit', 'Unit for application rate', ''],
      ['applications.csv', 'water_volume_lha', 'Carrier water volume', 'L/ha'],
      [
        'applications.csv',
        'growth_stage',
        'Crop growth stage at application e.g. BBCH code',
        ''
      ],
      [
        'applications.csv',
        'operator_name',
        'Person who performed application',
        ''
      ],
      ['applications.csv', 'equipment', 'Equipment used', ''],
      [
        'applications.csv',
        'wind_speed',
        'Wind speed at time of application',
        ''
      ],
      [
        'applications.csv',
        'wind_direction',
        'Wind direction at time of application',
        ''
      ],
      [
        'applications.csv',
        'temperature_c',
        'Air temperature at application',
        '°C'
      ],
      [
        'applications.csv',
        'humidity_pct',
        'Relative humidity at application',
        '%'
      ],
      ['applications.csv', 'notes', 'Operator notes', ''],
      [
        'applications.csv',
        'days_after_seeding',
        'Days elapsed since seeding',
        'days'
      ],
      [
        'applications.csv',
        'application_method',
        'Application method e.g. ground sprayer',
        ''
      ],
      ['applications.csv', 'export_timestamp', 'UTC timestamp', 'ISO 8601'],
      // seeding.csv
      [
        'seeding.csv',
        'seeding_date',
        'Date of seeding operation',
        'YYYY-MM-DD'
      ],
      ['seeding.csv', 'operator_name', 'Person who performed seeding', ''],
      ['seeding.csv', 'seed_lot_number', 'Seed lot or batch identifier', ''],
      ['seeding.csv', 'seeding_rate', 'Seeding rate used', ''],
      ['seeding.csv', 'seeding_rate_unit', 'Unit for seeding rate', ''],
      ['seeding.csv', 'seeding_depth_cm', 'Seed placement depth', 'cm'],
      ['seeding.csv', 'row_spacing_cm', 'Row spacing used', 'cm'],
      ['seeding.csv', 'equipment_used', 'Equipment used for seeding', ''],
      ['seeding.csv', 'notes', 'Operator notes', ''],
      [
        'seeding.csv',
        'planting_method',
        'Planting method used for seeding',
        ''
      ],
      ['seeding.csv', 'export_timestamp', 'UTC timestamp', 'ISO 8601'],
      // sessions.csv
      ['sessions.csv', 'session_name', 'Name or label of rating session', ''],
      [
        'sessions.csv',
        'session_date',
        'Date session was conducted',
        'YYYY-MM-DD'
      ],
      ['sessions.csv', 'status', 'Session status e.g. active closed', ''],
      [
        'sessions.csv',
        'plot_count_rated',
        'Number of plots with at least one rating',
        ''
      ],
      ['sessions.csv', 'rater_name', 'Person who conducted session', ''],
      ['sessions.csv', 'notes', 'Session notes', ''],
      ['sessions.csv', 'export_timestamp', 'UTC timestamp', 'ISO 8601'],
      [
        'sessions.csv',
        'crop_stage_bbch',
        'BBCH growth stage recorded for the session',
        '0–99'
      ],
      [
        'sessions.csv',
        'days_after_seeding',
        'Days from completed seeding to session start',
        'days'
      ],
      [
        'sessions.csv',
        'days_after_first_application',
        'Days from first applied application to session start',
        'days'
      ],
      // notes.csv (field observations; soft-deleted notes omitted from export)
      ['notes.csv', 'note_id', 'Database identifier of the note', ''],
      ['notes.csv', 'trial_name', 'Trial name at export', ''],
      ['notes.csv', 'plot_id', 'Linked plot display id if any', ''],
      ['notes.csv', 'session_name', 'Linked rating session name if any', ''],
      ['notes.csv', 'content', 'Note text', ''],
      ['notes.csv', 'created_at', 'When the note was created', 'ISO 8601 UTC'],
      ['notes.csv', 'created_by', 'Display name of author', ''],
      ['notes.csv', 'updated_at', 'Last edit time if edited', 'ISO 8601 UTC'],
      ['notes.csv', 'updated_by', 'Display name of last editor', ''],
      [
        'notes.csv',
        'export_timestamp',
        'UTC timestamp when export was generated',
        'ISO 8601'
      ],
      [
        'weather.csv',
        'crop_stage_bbch',
        'BBCH from the parent rating session',
        '0–99'
      ],
      // metadata
      ['metadata', 'export_timestamp', exportTimestamp, 'ISO 8601'],
      ['metadata', 'app_version', appVersion, ''],
    ];
    return CsvExportService.buildCsv(
      headers,
      rows,
      utf8BomForExcel: utf8BomForExcel,
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
    bool armAligned = false,
    bool utf8BomForExcel = false,
  }) async {
    final trialPk = trial.id;
    final rows = <List<String>>[];
    for (final session in sessions) {
      final sessionAssessments =
          await _sessionRepository.getSessionAssessments(session.id);
      final assessmentMap = {for (final a in sessionAssessments) a.id: a};
      final ratings =
          await _ratingRepository.getCurrentRatingsForSession(session.id);
      for (final r in ratings) {
        final plot = plotMap[r.plotPk];
        final assignment = plot != null ? assignmentByPlot[plot.id] : null;
        final treatmentId = assignment?.treatmentId ?? plot?.treatmentId;
        final treatment =
            treatmentId != null ? treatmentMap[treatmentId] : null;
        final assessment = assessmentMap[r.assessmentId];

        final sessionDate = _cell(session.sessionDateLocal);
        final plotId = plot != null ? _cell(plot.id) : '';
        final plotLabel = _cell(plot?.plotId);
        final rep = _cell(assignment?.replication ?? plot?.rep);
        final plotPosition =
            _cell(plot?.column ?? plot?.plotSortIndex ?? assignment?.position);
        final treatmentCode = _cell(treatment?.code);
        final treatmentName = _cell(treatment?.name);
        final assessmentName = _cell(assessment?.name);
        final assessmentType = _cell(assessment?.dataType);
        final value =
            r.numericValue != null ? _cell(r.numericValue) : _cell(r.textValue);
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

        final photosForPlotSession = await _photoRepository.getPhotosForPlotInSession(
          trialId: trialPk,
          plotPk: r.plotPk,
          sessionId: session.id,
        );
        final photoFiles = photosForPlotSession
            .map((p) => p.filePath.split('/').last)
            .where((s) => s.isNotEmpty)
            .join(',');

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
          _cell(r.ratingTime),
          _cell(r.ratingMethod),
          _cell(r.confidence),
          _cell(r.amended),
          _cell(r.originalValue),
          _cell(r.amendmentReason),
          _cell(r.amendedBy),
          r.amendedAt != null ? _cell(r.amendedAt!.toIso8601String()) : '',
          daysAfterSeeding != null ? _cell(daysAfterSeeding) : '',
          daysAfterFirstApp != null ? _cell(daysAfterFirstApp) : '',
          _cell(photoFiles.isEmpty ? null : photoFiles),
          plot != null && !isAnalyzablePlot(plot) ? 'true' : 'false',
          exportTimestamp,
          _cell(session.cropStageBbch),
        ]);
      }
    }
    return CsvExportService.buildCsv(
      _observationsHeaders,
      rows,
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.observationHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  /// Manual ARM handoff companion; same rating loop as [_buildObservationsCsv].
  Future<String> _buildObservationsArmTransferCsv({
    required Trial trial,
    required List<Session> sessions,
    required Map<int, Plot> plotMap,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Assignment> assignmentByPlot,
    bool utf8BomForExcel = false,
  }) async {
    final trialPk = trial.id;
    final rows = <List<String>>[];
    for (final session in sessions) {
      final sessionAssessments =
          await _sessionRepository.getSessionAssessments(session.id);
      final assessmentMap = {for (final a in sessionAssessments) a.id: a};
      final ratings =
          await _ratingRepository.getCurrentRatingsForSession(session.id);
      for (final r in ratings) {
        final plot = plotMap[r.plotPk];
        final assignment = plot != null ? assignmentByPlot[plot.id] : null;
        final treatmentId = assignment?.treatmentId ?? plot?.treatmentId;
        final treatment =
            treatmentId != null ? treatmentMap[treatmentId] : null;
        final assessment = assessmentMap[r.assessmentId];

        final valueNumeric =
            r.numericValue != null ? _cell(r.numericValue) : '';
        final rawText = r.textValue?.trim() ?? '';
        final valueText =
            r.numericValue == null && rawText.isNotEmpty ? rawText : '';
        final valueDisplay =
            r.numericValue != null ? _cell(r.numericValue) : rawText;

        rows.add([
          _cell(trialPk),
          _cell(trial.name),
          _cell(session.id),
          _cell(session.name),
          _cell(session.sessionDateLocal),
          _cell(r.plotPk),
          plot != null ? _cell(plot.plotId) : '',
          _cell(assignment?.replication ?? plot?.rep),
          treatmentId != null ? _cell(treatmentId) : '',
          _cell(treatment?.code),
          _cell(treatment?.name),
          _cell(r.assessmentId),
          _cell(assessment?.name),
          _cell(assessment?.unit),
          _cell(r.resultStatus),
          valueNumeric,
          valueText,
          valueDisplay,
          _cell(r.raterName),
        ]);
      }
    }
    return CsvExportService.buildCsv(
      _observationsArmTransferHeaders,
      rows,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  Future<String> _buildTreatmentsCsv(
    List<Treatment> treatments,
    String exportTimestamp, {
    bool armAligned = false,
    bool utf8BomForExcel = false,
  }) async {
    final rows = <List<String>>[];
    for (final t in treatments) {
      final components =
          await _treatmentRepository.getComponentsForTreatment(t.id);
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
    return CsvExportService.buildCsv(
      _treatmentsHeaders,
      rows,
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.treatmentHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  String _buildPlotAssignmentsCsv({
    required List<Plot> plots,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Assignment> assignmentByPlot,
    required int trialPk,
    required String exportTimestamp,
    bool armAligned = false,
    bool utf8BomForExcel = false,
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
        _cell(plot.plotLengthM),
        _cell(plot.plotWidthM),
        _cell(plot.plotAreaM2),
        _cell(plot.harvestLengthM),
        _cell(plot.harvestWidthM),
        _cell(plot.harvestAreaM2),
        _cell(plot.plotDirection),
        _cell(plot.soilSeries),
        _cell(plot.plotNotes),
        plot.isGuardRow ? 'true' : 'false',
        plot.excludeFromAnalysis ? 'true' : 'false',
        _cell(plot.exclusionReason),
        _cell(plot.damageType),
        exportTimestamp,
      ]);
    }
    return CsvExportService.buildCsv(
      _plotAssignmentsHeaders,
      rows,
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.plotHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  Future<String> _buildApplicationsCsv({
    required List<TrialApplicationEvent> applications,
    required Map<String, List<TrialApplicationProduct>> productsByEventId,
    DateTime? seedingDate,
    required String exportTimestamp,
    bool armAligned = false,
    bool utf8BomForExcel = false,
  }) async {
    final rows = <List<String>>[];
    for (final a in applications) {
      int? daysAfterSeeding;
      if (seedingDate != null) {
        daysAfterSeeding = a.applicationDate.difference(seedingDate).inDays;
      }
      final tail = <String>[
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
        a.status,
        a.appliedAt != null ? _date(a.appliedAt!) : '',
        _cell(a.applicationMethod),
        exportTimestamp,
      ];
      final prods = productsByEventId[a.id] ?? [];
      if (prods.isEmpty) {
        rows.add([
          _date(a.applicationDate),
          _cell(a.productName),
          _cell(a.rate),
          _cell(a.rateUnit),
          ...tail,
        ]);
      } else {
        for (final p in prods) {
          rows.add([
            _date(a.applicationDate),
            _cell(p.productName),
            _cell(p.rate),
            _cell(p.rateUnit),
            ...tail,
          ]);
        }
      }
    }
    return CsvExportService.buildCsv(
      _applicationsHeaders,
      rows,
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.applicationHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  String _buildSeedingCsv(
    SeedingEvent? seeding,
    String exportTimestamp, {
    bool armAligned = false,
    bool utf8BomForExcel = false,
  }) {
    if (seeding == null) {
      return CsvExportService.buildCsv(
        _seedingHeaders,
        [],
        armAligned: armAligned,
        headerMapping: armAligned ? ArmFieldMapping.seedingHeaders : null,
        utf8BomForExcel: utf8BomForExcel,
      );
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
      seeding.status,
      seeding.completedAt != null ? _date(seeding.completedAt!) : '',
      _cell(seeding.plantingMethod),
      exportTimestamp,
    ];
    return CsvExportService.buildCsv(
      _seedingHeaders,
      [row],
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.seedingHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  Future<String> _buildSessionsCsv(
    List<Session> sessions,
    String exportTimestamp, {
    required DateTime? seedingDate,
    required DateTime? firstAppDate,
    bool armAligned = false,
    bool utf8BomForExcel = false,
  }) async {
    final rows = <List<String>>[];
    for (final s in sessions) {
      final ratings = await _ratingRepository.getCurrentRatingsForSession(s.id);
      final plotCountRated = ratings.map((r) => r.plotPk).toSet().length;
      final int? das = seedingDate != null
          ? s.startedAt.difference(seedingDate).inDays
          : null;
      final int? daf = firstAppDate != null
          ? s.startedAt.difference(firstAppDate).inDays
          : null;
      rows.add([
        _cell(s.name),
        _cell(s.sessionDateLocal),
        _cell(s.status),
        _cell(plotCountRated),
        _cell(s.raterName),
        '', // notes not on Session in schema
        exportTimestamp,
        _cell(s.cropStageBbch),
        das != null ? _cell(das) : '',
        daf != null ? _cell(daf) : '',
      ]);
    }
    return CsvExportService.buildCsv(
      _sessionsHeaders,
      rows,
      armAligned: armAligned,
      headerMapping: armAligned ? ArmFieldMapping.sessionHeaders : null,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  String _buildFieldNotesCsv({
    required Trial trial,
    required List<Note> notes,
    required List<Plot> plots,
    required List<Session> sessions,
    required String exportTimestamp,
    bool utf8BomForExcel = false,
  }) {
    final plotByPk = {for (final p in plots) p.id: p};
    final sessionById = {for (final s in sessions) s.id: s};
    final rows = <List<String>>[];
    for (final n in notes.where((x) => !x.isDeleted)) {
      final plotLabel = n.plotPk != null
          ? (plotByPk[n.plotPk!]?.plotId ?? n.plotPk.toString())
          : '';
      final sessionName =
          n.sessionId != null ? (sessionById[n.sessionId!]?.name ?? '') : '';
      rows.add([
        _cell(n.id),
        _cell(trial.name),
        _cell(plotLabel),
        _cell(sessionName),
        _cell(n.content),
        _cell(n.createdAt.toUtc().toIso8601String()),
        _cell(n.raterName),
        n.updatedAt != null
            ? _cell(n.updatedAt!.toUtc().toIso8601String())
            : '',
        _cell(n.updatedBy),
        exportTimestamp,
      ]);
    }
    return CsvExportService.buildCsv(
      _fieldNotesHeaders,
      rows,
      utf8BomForExcel: utf8BomForExcel,
    );
  }

  /// Assigns standard export basenames; sequence suffixes resolve stem collisions.
  List<_ScheduledPhotoExport> _schedulePhotoExportNames({
    required List<Photo> photos,
    required Trial trial,
    required Map<int, Plot> plotMap,
    required Map<int, Assignment> assignmentByPlot,
    required Map<int, Treatment> treatmentMap,
  }) {
    final work = <_PhotoExportWork>[];
    for (final photo in photos) {
      final plot = plotMap[photo.plotPk];
      final assignment = plot != null ? assignmentByPlot[plot.id] : null;
      final treatmentId = assignment?.treatmentId ?? plot?.treatmentId;
      final treatment =
          treatmentId != null ? treatmentMap[treatmentId] : null;
      final stem = buildPhotoExportNameStem(
        trial: trial,
        plot: plot,
        assignment: assignment,
        treatment: treatment,
        photoCreatedAt: photo.createdAt,
      );
      work.add(_PhotoExportWork(
        photo: photo,
        plot: plot,
        assignment: assignment,
        treatment: treatment,
        stem: stem,
      ));
    }
    work.sort((a, b) {
      final c = a.stem.compareTo(b.stem);
      if (c != 0) return c;
      final t = a.photo.createdAt.compareTo(b.photo.createdAt);
      if (t != 0) return t;
      return a.photo.id.compareTo(b.photo.id);
    });
    final stemCounts = <String, int>{};
    for (final w in work) {
      stemCounts[w.stem] = (stemCounts[w.stem] ?? 0) + 1;
    }
    var currentStem = '';
    var indexInStem = 0;
    final out = <_ScheduledPhotoExport>[];
    for (final w in work) {
      if (w.stem != currentStem) {
        currentStem = w.stem;
        indexInStem = 0;
      }
      indexInStem++;
      final total = stemCounts[w.stem]!;
      final seq = total == 1 ? 0 : indexInStem;
      final exportBaseName = buildPhotoExportFileName(
        photo: w.photo,
        trial: trial,
        plot: w.plot,
        assignment: w.assignment,
        treatment: w.treatment,
        sequenceNumber: seq,
      );
      out.add(_ScheduledPhotoExport(
        photo: w.photo,
        plot: w.plot,
        assignment: w.assignment,
        treatment: w.treatment,
        exportBaseName: exportBaseName,
      ));
    }
    return out;
  }

  Future<File> _buildArmHandoffPackage(
    TrialExportBundle bundle,
    Trial trial,
    export_validation.ExportValidationReport validation,
    List<Photo> photos, {
    required Map<int, Plot> plotMap,
    required Map<int, Assignment> assignmentByPlot,
    required Map<int, Treatment> treatmentMap,
    required Map<int, Session> sessionById,
    required List<WeatherSnapshot> weatherSnapshots,
  }) async {
    final archive = Archive();
    final tempDir = await getTemporaryDirectory();
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());

    final csvFiles = <String, String>{
      'observations.csv': bundle.observationsCsv,
      'observations_arm_transfer.csv': bundle.observationsArmTransferCsv,
      'treatments.csv': bundle.treatmentsCsv,
      'plot_assignments.csv': bundle.plotAssignmentsCsv,
      'applications.csv': bundle.applicationsCsv,
      'seeding.csv': bundle.seedingCsv,
      'sessions.csv': bundle.sessionsCsv,
      'notes.csv': bundle.notesCsv,
      'data_dictionary.csv': bundle.dataDictionaryCsv,
    };
    for (final entry in csvFiles.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }

    final mappingCsv = CsvExportService.buildArmMappingCsv();
    final mappingBytes = utf8.encode(mappingCsv);
    archive.addFile(
        ArchiveFile('arm_mapping.csv', mappingBytes.length, mappingBytes));

    final weatherSummary = trialZipShouldIncludeWeatherCsv(weatherSnapshots)
        ? 'Included: weather.csv (${weatherSnapshots.length} snapshot(s)).'
        : null;
    final guideCsv = CsvExportService.buildImportGuideCsv(
      trial.name,
      date,
      validation,
      weatherSummary: weatherSummary,
    );
    final guideBytes = utf8.encode(guideCsv);
    archive.addFile(
        ArchiveFile('import_guide.csv', guideBytes.length, guideBytes));

    final validationCsv =
        export_validation.ExportValidationService().toCsv(validation);
    final validationBytes = utf8.encode(validationCsv);
    archive.addFile(ArchiveFile(
        'validation_report.csv', validationBytes.length, validationBytes));

    final scheduled = _schedulePhotoExportNames(
      photos: photos,
      trial: trial,
      plotMap: plotMap,
      assignmentByPlot: assignmentByPlot,
      treatmentMap: treatmentMap,
    );

    final successfullyExported = <Photo, String>{};
    final missingPhotos = <String>[];
    for (var i = 0; i < scheduled.length; i += 10) {
      final batch = scheduled.sublist(i, math.min(i + 10, scheduled.length));
      for (final item in batch) {
        try {
          final file = File(item.photo.filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(
                'photos/${item.exportBaseName}', bytes.length, bytes));
            successfullyExported[item.photo] = item.exportBaseName;
          } else {
            missingPhotos.add(p.basename(item.photo.filePath));
          }
        } catch (_) {
          missingPhotos.add(p.basename(item.photo.filePath));
        }
      }
    }

    if (successfullyExported.isNotEmpty) {
      final manifestRows = <List<String>>[];
      for (final item in scheduled) {
        final exportName = successfullyExported[item.photo];
        if (exportName == null) continue;
        final plotLabel = item.plot == null
            ? ''
            : (item.plot!.armPlotNumber != null
                ? item.plot!.armPlotNumber.toString()
                : item.plot!.plotId);
        manifestRows.add([
          exportName,
          p.basename(item.photo.filePath),
          trial.name,
          plotLabel,
          item.treatment?.code ?? '',
          DateFormat('MMM-d-yyyy', 'en_US')
              .format(item.photo.createdAt.toLocal()),
          item.photo.caption ?? '',
        ]);
      }
      final manifestCsv = CsvExportService.buildCsv(
        [
          'export_filename',
          'original_filename',
          'trial',
          'plot',
          'treatment',
          'date',
          'caption',
        ],
        manifestRows,
      );
      final mBytes = utf8.encode(manifestCsv);
      archive.addFile(ArchiveFile(
          'photos/photos_manifest.csv', mBytes.length, mBytes));
    }

    if (missingPhotos.isNotEmpty) {
      final mBytes = utf8.encode(
          CsvExportService.buildCsv(['original_filename'],
              missingPhotos.map((n) => [n]).toList()));
      archive.addFile(ArchiveFile(
          'photos/photos_missing.csv', mBytes.length, mBytes));
    }

    if (trialZipShouldIncludeWeatherCsv(weatherSnapshots)) {
      final weatherCsv = buildWeatherExportCsv(
        snapshots: weatherSnapshots,
        sessionsById: sessionById,
      );
      final wBytes = utf8.encode(weatherCsv);
      archive.addFile(ArchiveFile('weather.csv', wBytes.length, wBytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw ExportTrialException('ZIP encode failed');
    final safeName =
        trial.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final zipFile =
        File('${tempDir.path}/AGQ_${safeName}_$timestamp.zip');
    await zipFile.writeAsBytes(zipBytes);
    return zipFile;
  }
}

class _PhotoExportWork {
  _PhotoExportWork({
    required this.photo,
    required this.plot,
    required this.assignment,
    required this.treatment,
    required this.stem,
  });

  final Photo photo;
  final Plot? plot;
  final Assignment? assignment;
  final Treatment? treatment;
  final String stem;
}

class _ScheduledPhotoExport {
  _ScheduledPhotoExport({
    required this.photo,
    required this.plot,
    required this.assignment,
    required this.treatment,
    required this.exportBaseName,
  });

  final Photo photo;
  final Plot? plot;
  final Assignment? assignment;
  final Treatment? treatment;
  final String exportBaseName;
}

class ExportTrialException implements Exception {
  ExportTrialException(this.message);
  final String message;
  @override
  String toString() => 'ExportTrialException: $message';
}
