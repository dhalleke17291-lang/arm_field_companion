import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../ratings/rating_repository.dart';
import '../../sessions/session_repository.dart';
import '../../trials/trial_repository.dart';

/// Result of deleted-session Recovery ZIP export.
class DeletedSessionRecoveryZipResult {
  const DeletedSessionRecoveryZipResult._({
    required this.success,
    this.filePath,
    this.errorMessage,
  });

  final bool success;
  final String? filePath;
  final String? errorMessage;

  factory DeletedSessionRecoveryZipResult.ok(String filePath) =>
      DeletedSessionRecoveryZipResult._(success: true, filePath: filePath);

  factory DeletedSessionRecoveryZipResult.failure(String message) =>
      DeletedSessionRecoveryZipResult._(success: false, errorMessage: message);
}

/// Builds an analysis-friendly ZIP for one soft-deleted session (Recovery).
/// Not for standard operational import or ARM.
class ExportDeletedSessionRecoveryZipUsecase {
  ExportDeletedSessionRecoveryZipUsecase({
    required SessionRepository sessionRepository,
    required TrialRepository trialRepository,
    required RatingRepository ratingRepository,
  })  : _sessions = sessionRepository,
        _trials = trialRepository,
        _ratings = ratingRepository;

  final SessionRepository _sessions;
  final TrialRepository _trials;
  final RatingRepository _ratings;

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

  Future<DeletedSessionRecoveryZipResult> execute({
    required int sessionId,
    String? exportedByDisplayName,
  }) async {
    try {
      final session = await _sessions.getDeletedSessionById(sessionId);
      if (session == null) {
        return DeletedSessionRecoveryZipResult.failure(
          'Session not found or not soft-deleted. Recovery export requires a deleted session.',
        );
      }

      final trial = await _trials.getTrialById(session.trialId) ??
          await _trials.getDeletedTrialById(session.trialId);
      if (trial == null) {
        return DeletedSessionRecoveryZipResult.failure(
          'Parent trial not found for trial_id ${session.trialId}.',
        );
      }

      final ratingRows =
          await _ratings.getRatingRecordsForSessionRecoveryExport(sessionId);
      final exportedAtUtc = DateTime.now().toUtc().toIso8601String();

      final sessionsCsv = const ListToCsvConverter().convert([
        _sessionHeaders,
        _sessionRow(session),
      ]);

      final trialsCsv = const ListToCsvConverter().convert([
        _trialHeaders,
        _trialRow(trial),
      ]);

      final ratingData = <List<dynamic>>[_ratingHeaders];
      for (final r in ratingRows) {
        ratingData.add(_ratingRow(r));
      }
      final ratingsCsv = const ListToCsvConverter().convert(ratingData);

      final manifestHeaders = [
        'export_type',
        'session_id',
        'trial_id',
        'session_name',
        'trial_name',
        'rating_record_count',
        'exported_at_utc',
        'exported_by',
      ];
      final manifestCsv = const ListToCsvConverter().convert([
        manifestHeaders,
        [
          'deleted_session_recovery',
          sessionId,
          session.trialId,
          session.name,
          trial.name,
          ratingRows.length,
          exportedAtUtc,
          exportedByDisplayName ?? '',
        ],
      ]);

      const readme = '''
ARM Field Companion — Recovery export (deleted session)

This archive was generated by the Recovery export path. It contains
soft-deleted session data and related rating_records rows for analysis
and review only.

This bundle is NOT intended for standard operational re-import or ARM
handoff. Identifiers such as plot_pk and assessment_id may need to be
joined to plots and assessments tables in a separate analysis environment
to recover human-readable labels.

Files:
- sessions.csv   — the deleted session row
- trials.csv     — parent trial row (active or soft-deleted)
- rating_records.csv — all rating rows for this session (including deleted chain members)
- manifest.csv   — export metadata
''';

      final archive = Archive()
        ..addFile(_utf8File('sessions.csv', sessionsCsv))
        ..addFile(_utf8File('trials.csv', trialsCsv))
        ..addFile(_utf8File('rating_records.csv', ratingsCsv))
        ..addFile(_utf8File('manifest.csv', manifestCsv))
        ..addFile(_utf8File('README.txt', readme));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return DeletedSessionRecoveryZipResult.failure('ZIP encoding failed.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final zipPath =
          '${dir.path}/AFC_recovery_deleted_session_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.zip';
      await File(zipPath).writeAsBytes(zipBytes, flush: true);

      return DeletedSessionRecoveryZipResult.ok(zipPath);
    } catch (e, st) {
      return DeletedSessionRecoveryZipResult.failure(
        'Recovery export failed: $e\n${st.toString().split('\n').take(5).join('\n')}',
      );
    }
  }

  static ArchiveFile _utf8File(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

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
