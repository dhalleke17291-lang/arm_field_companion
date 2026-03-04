import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../data/export_repository.dart';

class ExportResult {
  final String filePath;
  final int rowCount;
  ExportResult({required this.filePath, required this.rowCount});
}

/// Export a closed session to CSV.
/// Writes to app documents directory (works on Android/iOS).
class ExportSessionCsvUsecase {
  final ExportRepository repo;
  ExportSessionCsvUsecase(this.repo);

  /// Pass trial/session metadata from UI so we don't depend on DB session fields here.
  Future<ExportResult> exportSessionToCsv({
    required int sessionId,
    required String trialName,
    required String sessionName,
    required String sessionDateLocal,
    String? sessionRaterName,
  }) async {
    final rows = await repo.buildSessionExportRows(sessionId: sessionId);

    final enriched = rows.map((m) => <String, Object?>{
          'trial_name': trialName,
          'session_name': sessionName,
          'session_date_local': sessionDateLocal,
          'session_rater_name': sessionRaterName,
          ...m,
        }).toList();

    final headers = enriched.isNotEmpty
        ? enriched.first.keys.toList()
        : <String>[
            'trial_name',
            'session_name',
            'session_date_local',
            'session_rater_name',
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

    return ExportResult(filePath: path, rowCount: rows.length);
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

    final file = File(
      '${dir.path}/AFC_export_$safeTrial_$safeSession_session_$sessionId.csv',
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
