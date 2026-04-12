import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_info.dart';
import '../../../core/database/app_database.dart';
import '../../plots/plot_repository.dart';
import '../../ratings/rating_repository.dart';
import '../../sessions/session_repository.dart';
import '../../trials/trial_repository.dart';

/// Result of deleted-trial Recovery ZIP export.
class DeletedTrialRecoveryZipResult {
  const DeletedTrialRecoveryZipResult._({
    required this.success,
    this.filePath,
    this.errorMessage,
  });

  final bool success;
  final String? filePath;
  final String? errorMessage;

  factory DeletedTrialRecoveryZipResult.ok(String filePath) =>
      DeletedTrialRecoveryZipResult._(success: true, filePath: filePath);

  factory DeletedTrialRecoveryZipResult.failure(String message) =>
      DeletedTrialRecoveryZipResult._(success: false, errorMessage: message);
}

/// Analysis-friendly ZIP for one soft-deleted trial (Recovery). Not for ARM / re-import.
class ExportDeletedTrialRecoveryZipUsecase {
  ExportDeletedTrialRecoveryZipUsecase({
    required TrialRepository trialRepository,
    required SessionRepository sessionRepository,
    required PlotRepository plotRepository,
    required RatingRepository ratingRepository,
  })  : _trials = trialRepository,
        _sessions = sessionRepository,
        _plots = plotRepository,
        _ratings = ratingRepository;

  final TrialRepository _trials;
  final SessionRepository _sessions;
  final PlotRepository _plots;
  final RatingRepository _ratings;

  static const List<String> _trialHeaders = [
    'id',
    'name',
    'crop',
    'location',
    'season',
    'status',
    'plot_dimensions',
    'plot_rows',
    'plot_spacing',
    'sponsor',
    'protocol_number',
    'investigator_name',
    'cooperator_name',
    'site_id',
    'field_name',
    'county',
    'state_province',
    'country',
    'latitude',
    'longitude',
    'elevation_m',
    'experimental_design',
    'plot_length_m',
    'plot_width_m',
    'alley_length_m',
    'previous_crop',
    'tillage',
    'irrigated',
    'soil_series',
    'soil_texture',
    'organic_matter_pct',
    'soil_ph',
    'harvest_date',
    'study_type',
    'created_at',
    'updated_at',
    'is_deleted',
    'deleted_at',
    'deleted_by',
  ];

  static const List<String> _sessionHeaders = [
    'id',
    'trial_id',
    'name',
    'started_at',
    'ended_at',
    'session_date_local',
    'rater_name',
    'created_by_user_id',
    'status',
    'is_deleted',
    'deleted_at',
    'deleted_by',
  ];

  static const List<String> _plotHeaders = [
    'id',
    'trial_id',
    'plot_id',
    'plot_sort_index',
    'rep',
    'treatment_id',
    'row',
    'column',
    'field_row',
    'field_column',
    'assignment_source',
    'assignment_updated_at',
    'plot_length_m',
    'plot_width_m',
    'plot_area_m2',
    'harvest_length_m',
    'harvest_width_m',
    'harvest_area_m2',
    'plot_direction',
    'soil_series',
    'plot_notes',
    'is_deleted',
    'deleted_at',
    'deleted_by',
  ];

  static const List<String> _ratingHeaders = [
    'id',
    'trial_id',
    'plot_pk',
    'assessment_id',
    'trial_assessment_id',
    'session_id',
    'sub_unit_id',
    'result_status',
    'numeric_value',
    'text_value',
    'is_current',
    'previous_id',
    'created_at',
    'rater_name',
    'created_app_version',
    'created_device_info',
    'captured_latitude',
    'captured_longitude',
    'rating_time',
    'rating_method',
    'confidence',
    'amended',
    'original_value',
    'amendment_reason',
    'amended_by',
    'amended_at',
    'is_deleted',
    'deleted_at',
    'deleted_by',
  ];

  Future<DeletedTrialRecoveryZipResult> execute({
    required int trialId,
    String? exportedByDisplayName,
  }) async {
    try {
      final trial = await _trials.getDeletedTrialById(trialId);
      if (trial == null) {
        return DeletedTrialRecoveryZipResult.failure(
          'Trial not found or not soft-deleted. Recovery export requires a deleted trial.',
        );
      }

      final sessionRows =
          await _sessions.getDeletedSessionsForTrial(trialId);
      final plotRows = await _plots.getDeletedPlotsForTrial(trialId);
      final ratingRows =
          await _ratings.getRatingRecordsForTrialRecoveryExport(trialId);

      final exportedAtUtc = DateTime.now().toUtc().toIso8601String();

      final trialsCsv = const ListToCsvConverter().convert([
        _trialHeaders,
        _trialRow(trial),
      ]);

      final sessionData = <List<dynamic>>[_sessionHeaders];
      for (final s in sessionRows) {
        sessionData.add(_sessionRow(s));
      }
      final sessionsCsv = const ListToCsvConverter().convert(sessionData);

      final plotData = <List<dynamic>>[_plotHeaders];
      for (final p in plotRows) {
        plotData.add(_plotRow(p));
      }
      final plotsCsv = const ListToCsvConverter().convert(plotData);

      final ratingData = <List<dynamic>>[_ratingHeaders];
      for (final r in ratingRows) {
        ratingData.add(_ratingRow(r));
      }
      final ratingsCsv = const ListToCsvConverter().convert(ratingData);

      final manifestHeaders = [
        'export_type',
        'trial_id',
        'trial_name',
        'deleted_session_count',
        'deleted_plot_count',
        'rating_record_count',
        'exported_at_utc',
        'exported_by',
        'app_name',
        'app_version',
      ];
      final manifestCsv = const ListToCsvConverter().convert([
        manifestHeaders,
        [
          'deleted_trial_recovery',
          trialId,
          trial.name,
          sessionRows.length,
          plotRows.length,
          ratingRows.length,
          exportedAtUtc,
          exportedByDisplayName ?? '',
          AppInfo.appName,
          AppInfo.appVersion,
        ],
      ]);

      final readme = '''
${AppInfo.appName} — Recovery export (deleted trial)
App version: ${AppInfo.appVersion}

This archive contains soft-deleted trial data (trial, sessions, plots,
and all rating_records for this trial_id) for analysis and review only.

It is NOT intended for standard operational re-import or ARM handoff.
Rating rows may include soft-deleted and non-current historical chain
members. Identifiers (plot_pk, assessment_id, treatment_id, etc.) may need
joining to assessments, treatments, and related tables in a separate
analysis environment for richer labels.

Files:
- trials.csv          — deleted trial row
- sessions.csv        — soft-deleted sessions for this trial
- plots.csv           — soft-deleted plots for this trial
- rating_records.csv  — all ratings for this trial_id
- manifest.csv        — export metadata
''';

      final archive = Archive()
        ..addFile(_utf8File('trials.csv', trialsCsv))
        ..addFile(_utf8File('sessions.csv', sessionsCsv))
        ..addFile(_utf8File('plots.csv', plotsCsv))
        ..addFile(_utf8File('rating_records.csv', ratingsCsv))
        ..addFile(_utf8File('manifest.csv', manifestCsv))
        ..addFile(_utf8File('README.txt', readme));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return DeletedTrialRecoveryZipResult.failure('ZIP encoding failed.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final zipPath =
          '${dir.path}/${_recoveryZipNamePrefix()}_recovery_deleted_trial_${trialId}_${DateTime.now().millisecondsSinceEpoch}.zip';
      await File(zipPath).writeAsBytes(zipBytes, flush: true);

      return DeletedTrialRecoveryZipResult.ok(zipPath);
    } catch (e, st) {
      return DeletedTrialRecoveryZipResult.failure(
        'Recovery export failed: $e\n${st.toString().split('\n').take(5).join('\n')}',
      );
    }
  }

  static String _recoveryZipNamePrefix() {
    return AppInfo.appName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static ArchiveFile _utf8File(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static List<dynamic> _trialRow(Trial t) => [
        t.id,
        t.name,
        t.crop ?? '',
        t.location ?? '',
        t.season ?? '',
        t.status,
        t.plotDimensions ?? '',
        t.plotRows ?? '',
        t.plotSpacing ?? '',
        t.sponsor ?? '',
        t.protocolNumber ?? '',
        t.investigatorName ?? '',
        t.cooperatorName ?? '',
        t.siteId ?? '',
        t.fieldName ?? '',
        t.county ?? '',
        t.stateProvince ?? '',
        t.country ?? '',
        t.latitude ?? '',
        t.longitude ?? '',
        t.elevationM ?? '',
        t.experimentalDesign ?? '',
        t.plotLengthM ?? '',
        t.plotWidthM ?? '',
        t.alleyLengthM ?? '',
        t.previousCrop ?? '',
        t.tillage ?? '',
        t.irrigated == null ? '' : (t.irrigated! ? 1 : 0),
        t.soilSeries ?? '',
        t.soilTexture ?? '',
        t.organicMatterPct ?? '',
        t.soilPh ?? '',
        _iso(t.harvestDate),
        t.studyType ?? '',
        _iso(t.createdAt),
        _iso(t.updatedAt),
        t.isDeleted ? 1 : 0,
        _iso(t.deletedAt),
        t.deletedBy ?? '',
      ];

  static List<dynamic> _sessionRow(Session s) => [
        s.id,
        s.trialId,
        s.name,
        _iso(s.startedAt),
        _iso(s.endedAt),
        s.sessionDateLocal,
        s.raterName ?? '',
        s.createdByUserId ?? '',
        s.status,
        s.isDeleted ? 1 : 0,
        _iso(s.deletedAt),
        s.deletedBy ?? '',
      ];

  static List<dynamic> _plotRow(Plot p) => [
        p.id,
        p.trialId,
        p.plotId,
        p.plotSortIndex ?? '',
        p.rep ?? '',
        p.treatmentId ?? '',
        p.row ?? '',
        p.column ?? '',
        p.fieldRow ?? '',
        p.fieldColumn ?? '',
        p.assignmentSource ?? '',
        _iso(p.assignmentUpdatedAt),
        p.plotLengthM ?? '',
        p.plotWidthM ?? '',
        p.plotAreaM2 ?? '',
        p.harvestLengthM ?? '',
        p.harvestWidthM ?? '',
        p.harvestAreaM2 ?? '',
        p.plotDirection ?? '',
        p.soilSeries ?? '',
        p.plotNotes ?? '',
        p.isDeleted ? 1 : 0,
        _iso(p.deletedAt),
        p.deletedBy ?? '',
      ];

  static List<dynamic> _ratingRow(RatingRecord r) => [
        r.id,
        r.trialId,
        r.plotPk,
        r.assessmentId,
        r.trialAssessmentId ?? '',
        r.sessionId,
        r.subUnitId ?? '',
        r.resultStatus,
        r.numericValue ?? '',
        r.textValue ?? '',
        r.isCurrent ? 1 : 0,
        r.previousId ?? '',
        _iso(r.createdAt),
        r.raterName ?? '',
        r.createdAppVersion ?? '',
        r.createdDeviceInfo ?? '',
        r.capturedLatitude ?? '',
        r.capturedLongitude ?? '',
        r.ratingTime ?? '',
        r.ratingMethod ?? '',
        r.confidence ?? '',
        r.amended ? 1 : 0,
        r.originalValue ?? '',
        r.amendmentReason ?? '',
        r.amendedBy ?? '',
        _iso(r.amendedAt),
        r.isDeleted ? 1 : 0,
        _iso(r.deletedAt),
        r.deletedBy ?? '',
      ];
}
