import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/app_info.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../data/export_repository.dart';

/// Result of a session CSV export. Use [success] to decide UI.
class ExportResult {
  final bool success;
  final String? filePath;

  /// Path to session audit events CSV when available.
  final String? auditFilePath;
  final int rowCount;
  final String? errorMessage;
  final String? warningMessage;

  const ExportResult._({
    required this.success,
    this.filePath,
    this.auditFilePath,
    this.rowCount = 0,
    this.errorMessage,
    this.warningMessage,
  });

  factory ExportResult.ok({
    required String filePath,
    required int rowCount,
    String? warningMessage,
    String? auditFilePath,
  }) =>
      ExportResult._(
        success: true,
        filePath: filePath,
        rowCount: rowCount,
        warningMessage: warningMessage,
        auditFilePath: auditFilePath,
      );

  factory ExportResult.failure(String message) => ExportResult._(
        success: false,
        errorMessage: message,
      );
}

/// Export a closed session to CSV.
/// Writes to app documents directory (works on Android/iOS).
/// Includes export metadata (timestamp, app version) and validates session state.
class ExportSessionCsvUsecase {
  final ExportRepository repo;
  ExportSessionCsvUsecase(this.repo);

  /// Pass trial/session metadata from UI so we don't depend on DB session fields here.
  /// [isSessionClosed]: if false and [requireSessionClosed] is true, returns failure.
  /// [exportedByDisplayName]: current user for attribution in export metadata.
  Future<ExportResult> exportSessionToCsv({
    required int sessionId,
    required int trialId,
    required String trialName,
    required String sessionName,
    required String sessionDateLocal,
    String? sessionRaterName,
    String? exportedByDisplayName,
    bool isSessionClosed = true,
    bool requireSessionClosed = true,
  }) async {
    try {
      if (requireSessionClosed && !isSessionClosed) {
        return ExportResult.failure(
          'Session must be closed before export. Close the session first.',
        );
      }

      final rows = await repo.buildSessionExportRows(sessionId: sessionId);
      final exportTimestampUtc = DateTime.now().toUtc().toIso8601String();

      final enriched = rows
          .map((m) => <String, Object?>{
                'trial_id': trialId,
                'session_id': sessionId,
                'trial_name': trialName,
                'session_name': sessionName,
                'session_date_local': sessionDateLocal,
                'session_rater_name': sessionRaterName,
                'export_timestamp_utc': exportTimestampUtc,
                'app_version': kAppVersion,
                ...m,
                if (exportedByDisplayName != null)
                  'exported_by': exportedByDisplayName,
              })
          .toList();

      final baseHeaders = <String>[
        'trial_id',
        'session_id',
        'trial_name',
        'session_name',
        'session_date_local',
        'session_rater_name',
        'export_timestamp_utc',
        'app_version',
      ];
      final headers = enriched.isNotEmpty
          ? enriched.first.keys.toList()
          : [
              ...baseHeaders,
              if (exportedByDisplayName != null) 'exported_by',
            ];

      final data = <List<dynamic>>[
        headers,
        ...enriched.map((m) => headers.map((h) => m[h]).toList()),
      ];

      final csv = const ListToCsvConverter().convert(data);

      final path = await _writeCsv(
        sessionId: sessionId,
        trialName: trialName,
        sessionName: sessionName,
        csv: csv,
      );

      String? auditPath;
      final auditRows =
          await repo.buildSessionAuditExportRows(sessionId: sessionId);
      if (auditRows.isNotEmpty) {
        final auditHeaders = auditRows.first.keys.toList();
        final auditData = <List<dynamic>>[
          auditHeaders,
          ...auditRows.map((m) => auditHeaders.map((h) => m[h]).toList()),
        ];
        final auditCsv = const ListToCsvConverter().convert(auditData);
        auditPath = await _writeAuditCsv(
          sessionId: sessionId,
          trialName: trialName,
          sessionName: sessionName,
          csv: auditCsv,
        );
      }

      final warning = rows.isEmpty
          ? 'No ratings in this session. Export file contains headers only.'
          : null;

      // Audit trail
      try {
        final auditDb = repo.db;
        await auditDb.into(auditDb.auditEvents).insert(
              AuditEventsCompanion.insert(
                trialId: Value(trialId),
                sessionId: Value(sessionId),
                eventType: 'EXPORT_TRIGGERED',
                description:
                    'Session \$sessionId exported — \${rows.length} rows — by \${exportedByDisplayName ?? "unknown"}',
                performedBy: Value(exportedByDisplayName),
              ),
            );
      } catch (_) {
        // Audit failure must never block export
      }

      return ExportResult.ok(
        filePath: path,
        rowCount: rows.length,
        warningMessage: warning,
        auditFilePath: auditPath,
      );
    } catch (_) {
      return ExportResult.failure(
        'Export failed — please try again. If the problem persists, check trial data for missing or incomplete records.',
      );
    }
  }

  Future<String> _writeCsv({
    required int sessionId,
    required String trialName,
    required String sessionName,
    required String csv,
  }) async {
    final dir = await getApplicationDocumentsDirectory();

    final safeTrial = _safeFilePart(trialName);
    final safeSession = _safeFilePart(sessionName);
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());

    final file = File(
      '${dir.path}/AFC_export_${safeTrial}_${safeSession}_session_${sessionId}_$timestamp.csv',
    );

    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  Future<String> _writeAuditCsv({
    required int sessionId,
    required String trialName,
    required String sessionName,
    required String csv,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTrial = _safeFilePart(trialName);
    final safeSession = _safeFilePart(sessionName);
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
    final file = File(
      '${dir.path}/AFC_export_${safeTrial}_${safeSession}_session_${sessionId}_audit_$timestamp.csv',
    );
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  String _safeFilePart(String s) {
    return s
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
