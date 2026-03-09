import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../sessions/session_repository.dart';
import 'export_session_csv_usecase.dart';

/// Result of batch export of all closed sessions for a trial.
class BatchExportResult {
  final bool success;
  final String? filePath;
  final int sessionCount;
  final String? errorMessage;

  const BatchExportResult._({
    required this.success,
    this.filePath,
    this.sessionCount = 0,
    this.errorMessage,
  });

  factory BatchExportResult.ok({
    required String filePath,
    required int sessionCount,
  }) =>
      BatchExportResult._(success: true, filePath: filePath, sessionCount: sessionCount);

  factory BatchExportResult.failure(String message) =>
      BatchExportResult._(success: false, errorMessage: message);
}

/// Exports all closed sessions for a trial to CSV files and returns a single ZIP path.
class ExportTrialClosedSessionsUsecase {
  final ExportSessionCsvUsecase _exportSession;
  final SessionRepository _sessionRepo;

  ExportTrialClosedSessionsUsecase(this._exportSession, this._sessionRepo);

  Future<BatchExportResult> execute({
    required int trialId,
    required String trialName,
    String? exportedByDisplayName,
  }) async {
    try {
      final sessions = await _sessionRepo.getSessionsForTrial(trialId);
      final closed =
          sessions.where((s) => s.endedAt != null).toList();
      if (closed.isEmpty) {
        return BatchExportResult.failure(
            'No closed sessions to export. Close sessions first.');
      }

      final csvPaths = <String>[];
      for (final session in closed) {
        final result = await _exportSession.exportSessionToCsv(
          sessionId: session.id,
          trialId: trialId,
          trialName: trialName,
          sessionName: session.name,
          sessionDateLocal: session.sessionDateLocal,
          sessionRaterName: session.raterName,
          exportedByDisplayName: exportedByDisplayName,
          isSessionClosed: true,
        );
        if (!result.success) {
          return BatchExportResult.failure(
              result.errorMessage ?? 'Export failed for session "${session.name}"');
        }
        if (result.filePath != null) csvPaths.add(result.filePath!);
        if (result.auditFilePath != null) csvPaths.add(result.auditFilePath!);
      }

      if (csvPaths.isEmpty) {
        return BatchExportResult.failure('No files to zip.');
      }

      final archive = Archive();
      for (final path in csvPaths) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(p.basename(path), bytes.length, bytes));
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return BatchExportResult.failure('Failed to create ZIP.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName = trialName
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
      final zipPath =
          '${dir.path}/AFC_trial_${safeName}_closed_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes);

      return BatchExportResult.ok(
          filePath: zipPath, sessionCount: closed.length);
    } catch (e, st) {
      return BatchExportResult.failure(
          'Batch export failed: ${e.toString()}\n${st.toString().split('\n').take(3).join('\n')}');
    }
  }
}
