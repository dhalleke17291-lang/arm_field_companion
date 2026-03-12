import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../sessions/session_repository.dart';
import 'export_session_arm_xml_usecase.dart';
import 'export_trial_closed_sessions_usecase.dart';

/// Exports all closed sessions for a trial to ARM XML files and returns a single ZIP path.
/// Reuses [BatchExportResult] so UI can share the same success/error flow as CSV batch.
class ExportTrialClosedSessionsArmXmlUsecase {
  final ExportSessionArmXmlUsecase _exportSession;
  final SessionRepository _sessionRepo;

  ExportTrialClosedSessionsArmXmlUsecase(this._exportSession, this._sessionRepo);

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

      final xmlPaths = <String>[];
      for (final session in closed) {
        final result = await _exportSession.exportSessionToArmXml(
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
        if (result.filePath != null) xmlPaths.add(result.filePath!);
      }

      if (xmlPaths.isEmpty) {
        return BatchExportResult.failure('No files to zip.');
      }

      final archive = Archive();
      for (final path in xmlPaths) {
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
          '${dir.path}/AFC_trial_${safeName}_arm_xml_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes);

      return BatchExportResult.ok(
          filePath: zipPath, sessionCount: closed.length);
    } catch (e, st) {
      return BatchExportResult.failure(
          'Batch ARM XML export failed: ${e.toString()}\n${st.toString().split('\n').take(3).join('\n')}');
    }
  }
}
